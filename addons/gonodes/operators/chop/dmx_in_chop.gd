class_name DmxInCHOP
extends GNChopBase
## Receives DMX-512 values via Art-Net (UDP) as CHOP channels.
##
## Binds to the Art-Net port and listens for incoming OpDmx packets.
## Outputs received DMX channel values as float channels (dmx1–dmx512).
##
## Values range 0.0–255.0 and can be fed directly into MathCHOP,
## LookupCHOP, or any other CHOP for processing.
##
## TouchDesigner equivalent: DMX In CHOP.

const DMX_CHANNELS := 512
const ARTNET_HEADER := "Art-Net"
const ARTNET_OPCODE_DMX := 0x5000

# ── Receive state ──────────────────────────────────────────────────────────────
var _rx_udp: PacketPeerUDP = null
var _rx_values := PackedFloat32Array()
var _rx_universe: int = -1
var _rx_sequence: int = 0
var _bound_port: int = -1


func _init() -> void:
	node_type = "dmx_in"
	time_dependent = true
	thread_safe = false  # PacketPeerUDP I/O


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Received DMX values as channels (dmx1–dmx512)")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("universe", 0, 0, 32767,
		"Universe", "DMX universe to listen for"))
	add_parameter(GNParameter.create_int("port", 6454, 1, 65535,
		"Port", "Art-Net UDP port to bind (default 6454)"))
	add_parameter(GNParameter.create_bool("active", false,
		"Active", "Enable Art-Net listening"))
	add_parameter(GNParameter.create_int("channels", 512, 1, 512,
		"Channels", "Number of DMX channels to output"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var active: bool = get_param_value("active")
	var channel_count: int = clampi(get_param_value("channels"), 1, DMX_CHANNELS)

	if active:
		_ensure_rx_bound()
		_poll_artnet()
	else:
		_close_rx()

	# Build CHOP output
	var out := _prepare_output()

	# Ensure _rx_values is at least channel_count long
	if _rx_values.size() < channel_count:
		_rx_values.resize(channel_count)

	for i in range(channel_count):
		out.set_single_value("dmx%d" % (i + 1), _rx_values[i])

	return out


# ═══════════════════════════════════════════════════════════════════════════════
# Art-Net Receive
# ═══════════════════════════════════════════════════════════════════════════════

## Binds the receive UDP socket if not already bound or port changed.
func _ensure_rx_bound() -> void:
	var port: int = get_param_value("port")
	if _rx_udp != null and _bound_port == port:
		return
	_close_rx()
	_rx_udp = PacketPeerUDP.new()
	var err := _rx_udp.bind(port)
	if err != OK:
		GNLogger.warn("DmxInCHOP", "Could not bind to port %d (error %d). Another app may be using it." % [port, err])
		_rx_udp = null
		return
	_bound_port = port


## Polls for incoming Art-Net packets and parses OpDmx data.
func _poll_artnet() -> void:
	if _rx_udp == null:
		return
	var universe_filter: int = get_param_value("universe")
	while _rx_udp.get_available_packet_count() > 0:
		var packet := _rx_udp.get_packet()
		_parse_artnet_packet(packet, universe_filter)


## Parses a single Art-Net packet.  Updates _rx_values if it's a valid
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
	# Extract DMX channel values as floats
	if _rx_values.size() < data_len:
		_rx_values.resize(data_len)
	for i in range(data_len):
		_rx_values[i] = float(packet[18 + i])


## Closes the receive socket and resets state.
func _close_rx() -> void:
	if _rx_udp != null:
		_rx_udp.close()
		_rx_udp = null
	_rx_values.resize(0)
	_rx_universe = -1
	_bound_port = -1


## Clean up on node destruction.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_close_rx()
