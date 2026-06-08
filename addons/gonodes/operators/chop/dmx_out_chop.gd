class_name DmxOutCHOP
extends GNChopBase
## Sends CHOP channel values as DMX-512 via Art-Net (UDP).
##
## Reads input channels and broadcasts an Art-Net OpDmx packet each frame.
## Passes the input through to the output unchanged, allowing downstream
## CHOP processing to continue.
##
## Channels are mapped to DMX slots in order: first channel → DMX 1,
## second → DMX 2, etc. Values are clamped to 0–255.
##
## TouchDesigner equivalent: DMX Out CHOP.

const DMX_CHANNELS := 512
const ARTNET_HEADER := "Art-Net"
const ARTNET_OPCODE_DMX := 0x5000


func _init() -> void:
	node_type = "dmx_out"
	time_dependent = true
	thread_safe = false  # PacketPeerUDP I/O


func _init_ports() -> void:
	add_input("values", GNFamily.Type.CHOP, false,
		"Channel values to send as DMX (ch1→DMX 1, ch2→DMX 2, ...)", "Values")
	add_output("out", GNFamily.Type.CHOP, "Pass-through of input channels", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("universe", 0, 0, 32767,
		"Universe", "DMX universe number"))
	add_parameter(GNParameter.create_string("ip", "255.255.255.255",
		"IP Address", "Destination IP for Art-Net broadcast"))
	add_parameter(GNParameter.create_int("port", 6454, 1, 65535,
		"Port", "Art-Net UDP port (default 6454)"))
	add_parameter(GNParameter.create_bool("active", false,
		"Active", "Enable Art-Net sending"))
	add_parameter(GNParameter.create_int("channels", 512, 1, 512,
		"Channels", "Number of active DMX channels to send"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_chop := _get_input_chop(inputs, 0)
	if in_chop == null:
		return _prepare_output()  # Empty CHOP

	var active: bool = get_param_value("active")
	if active:
		var channel_count: int = clampi(get_param_value("channels"), 1, DMX_CHANNELS)
		var dmx_values := PackedByteArray()
		dmx_values.resize(channel_count)

		var ch_names := in_chop.get_channel_names()
		for i in range(mini(ch_names.size(), channel_count)):
			dmx_values[i] = clampi(int(in_chop.get_value(ch_names[i])), 0, 255)

		_send_artnet(dmx_values)

	# Pass through input
	return in_chop


# ═══════════════════════════════════════════════════════════════════════════════
# Art-Net Send
# ═══════════════════════════════════════════════════════════════════════════════

func _send_artnet(values: PackedByteArray) -> void:
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
	# Protocol version 14 (big-endian)
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
	# DMX channel data
	packet.append_array(values)
	# Pad to even length
	if values.size() % 2 != 0:
		packet.append(0)

	var udp := PacketPeerUDP.new()
	udp.set_dest_address(ip, port)
	udp.put_packet(packet)
