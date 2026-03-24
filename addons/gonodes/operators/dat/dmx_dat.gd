class_name DMXDAT
extends GNDatBase
## DMX lighting protocol DAT via Art-Net (UDP).
##
## Bidirectional Art-Net node: sends and/or receives DMX-512 data over
## Ethernet using Godot's built-in PacketPeerUDP.
##
## **Send mode** (default): reads input CHOP channel values and broadcasts
## an Art-Net OpDmx packet to the configured IP/port.
##
## **Receive mode**: binds to the Art-Net port and listens for incoming
## OpDmx packets, updating the output table each cook.
##
## Both directions can be active simultaneously.  No external libraries
## required — Art-Net is a pure UDP protocol fully supported by Godot.
##
## TouchDesigner equivalent: DMX Out CHOP + DMX In DAT.

const DMX_CHANNELS := 512
const ARTNET_HEADER := "Art-Net"
const ARTNET_OPCODE_DMX := 0x5000

# ── Receive state ──────────────────────────────────────────────────────────────
var _rx_udp: PacketPeerUDP = null
var _rx_values := PackedInt32Array()
var _rx_universe: int = -1
var _rx_sequence: int = 0


func _init() -> void:
	node_type = "dmx"
	time_dependent = true


func _init_ports() -> void:
	add_input("values", GNFamily.Type.CHOP, false, "Channel values to send (ch1-ch512)")
	add_output("out", GNFamily.Type.DAT, "DMX channel table")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode", ["Send", "Receive", "Both"], 0,
		"Mode", "Send: broadcast DMX. Receive: listen for Art-Net. Both: simultaneous."))
	add_parameter(GNParameter.create_int("universe", 0, 0, 32767,
		"Universe", "DMX universe number"))
	add_parameter(GNParameter.create_string("ip", "255.255.255.255",
		"IP Address", "Destination IP for Art-Net broadcast (send mode)"))
	add_parameter(GNParameter.create_int("port", 6454, 1, 65535,
		"Port", "Art-Net UDP port (default 6454)"))
	add_parameter(GNParameter.create_bool("active", false,
		"Active", "Enable Art-Net communication"))
	add_parameter(GNParameter.create_int("channels", 512, 1, 512,
		"Channels", "Number of active DMX channels"))


func _cook(inputs: Array[GNData]) -> GNData:
	var channel_count: int = clampi(get_param_value("channels"), 1, DMX_CHANNELS)
	var active: bool = get_param_value("active")
	var mode: int = get_param_value("mode")  # 0=Send, 1=Receive, 2=Both

	# ── Receive path ───────────────────────────────────────────────────────────
	if active and mode >= 1:  # Receive or Both
		_ensure_rx_bound()
		_poll_artnet()
	else:
		_close_rx()

	# ── Build send values from input CHOP ──────────────────────────────────────
	var dmx_values := PackedInt32Array()
	dmx_values.resize(channel_count)

	if mode == 0 or mode == 2:  # Send or Both
		var in_chop := inputs[0] as GNChannelData if inputs.size() > 0 and inputs[0] is GNChannelData else null
		if in_chop != null:
			var ch_names := in_chop.get_channel_names()
			for i in range(mini(ch_names.size(), channel_count)):
				var val: float = in_chop.get_value(ch_names[i])
				dmx_values[i] = clampi(int(val), 0, 255)
		if active:
			_send_artnet(dmx_values)

	# ── Build output table ─────────────────────────────────────────────────────
	var out := _prepare_table()

	if mode >= 1 and _rx_values.size() > 0:
		# Receive mode: output received values
		out.set_headers(PackedStringArray(["channel", "value", "source"]))
		var count := mini(_rx_values.size(), channel_count)
		for i in range(count):
			out.append_row(PackedStringArray([str(i + 1), str(_rx_values[i]), "rx"]))
	else:
		# Send mode: output sent values
		out.set_headers(PackedStringArray(["channel", "value"]))
		for i in range(channel_count):
			out.append_row(PackedStringArray([str(i + 1), str(dmx_values[i])]))

	return out


# ═══════════════════════════════════════════════════════════════════════════════
# Art-Net Send
# ═══════════════════════════════════════════════════════════════════════════════

## Sends Art-Net DMX512 (OpDmx) packet via UDP.
func _send_artnet(values: PackedInt32Array) -> void:
	var universe: int = get_param_value("universe")
	var ip: String = get_param_value("ip")
	var port: int = get_param_value("port")

	var packet := PackedByteArray()
	# Header: "Art-Net\0"
	packet.append_array(ARTNET_HEADER.to_ascii_buffer())
	packet.append(0)
	# OpCode: OpDmx (0x5000) little-endian
	packet.append(ARTNET_OPCODE_DMX & 0xFF)
	packet.append((ARTNET_OPCODE_DMX >> 8) & 0xFF)
	# Protocol version 14
	packet.append(0)
	packet.append(14)
	# Sequence (0 = disabled)
	packet.append(0)
	# Physical port
	packet.append(0)
	# Universe (little-endian)
	packet.append(universe & 0xFF)
	packet.append((universe >> 8) & 0xFF)
	# Data length (big-endian, must be even)
	var data_len := values.size()
	if data_len % 2 != 0:
		data_len += 1
	packet.append((data_len >> 8) & 0xFF)
	packet.append(data_len & 0xFF)
	# DMX data
	for v in values:
		packet.append(clampi(v, 0, 255))
	# Pad to even length
	if values.size() % 2 != 0:
		packet.append(0)

	var udp := PacketPeerUDP.new()
	udp.set_dest_address(ip, port)
	udp.put_packet(packet)
	udp.close()


# ═══════════════════════════════════════════════════════════════════════════════
# Art-Net Receive
# ═══════════════════════════════════════════════════════════════════════════════

## Binds the receive UDP socket if not already bound.
func _ensure_rx_bound() -> void:
	if _rx_udp != null:
		return
	var port: int = get_param_value("port")
	_rx_udp = PacketPeerUDP.new()
	var err := _rx_udp.bind(port)
	if err != OK:
		push_warning("DMXDAT: Could not bind to port %d (error %d). Another app may be using it." % [port, err])
		_rx_udp = null


## Polls for incoming Art-Net packets and parses OpDmx data.
func _poll_artnet() -> void:
	if _rx_udp == null:
		return
	var universe_filter: int = get_param_value("universe")
	# Process all available packets this frame
	while _rx_udp.get_available_packet_count() > 0:
		var packet := _rx_udp.get_packet()
		_parse_artnet_packet(packet, universe_filter)


## Parses a single Art-Net packet. Updates _rx_values if it's a valid
## OpDmx packet matching our universe filter.
func _parse_artnet_packet(packet: PackedByteArray, universe_filter: int) -> void:
	# Minimum Art-Net OpDmx packet: 18 bytes header + at least 2 data bytes
	if packet.size() < 20:
		return

	# Validate "Art-Net\0" header
	if packet.slice(0, 7).get_string_from_ascii() != ARTNET_HEADER:
		return
	if packet[7] != 0:
		return

	# OpCode (little-endian): OpDmx = 0x5000
	var opcode: int = packet[8] | (packet[9] << 8)
	if opcode != ARTNET_OPCODE_DMX:
		return

	# Sequence byte (offset 12)
	_rx_sequence = packet[12]

	# Universe (little-endian, offset 14-15)
	_rx_universe = packet[14] | (packet[15] << 8)
	if _rx_universe != universe_filter:
		return

	# Data length (big-endian, offset 16-17)
	var data_len: int = (packet[16] << 8) | packet[17]
	data_len = mini(data_len, packet.size() - 18)
	data_len = mini(data_len, DMX_CHANNELS)

	# Extract DMX channel values
	_rx_values.resize(data_len)
	for i in range(data_len):
		_rx_values[i] = packet[18 + i]


## Closes the receive socket.
func _close_rx() -> void:
	if _rx_udp != null:
		_rx_udp.close()
		_rx_udp = null
		_rx_values.resize(0)
		_rx_universe = -1


## Clean up on node destruction.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_close_rx()
