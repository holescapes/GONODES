class_name AudioStreamInCHOP
extends GNChopBase
## Receive audio over network via UDP.
##
## Listens on a configurable port for incoming audio packets. Packets
## contain raw interleaved PCM float samples with a small header for
## sample rate and channel count. Designed to pair with AudioStreamOutCHOP.
##
## Protocol: [4B magic "GNAU"] [4B sample_rate float] [2B num_channels]
##           [2B num_samples] [N*channels*4B float32 PCM]

var _peer: PacketPeerUDP = null
var _listen_port: int = -1
var _last_left := PackedFloat32Array()
var _last_right := PackedFloat32Array()
var _last_sr: float = 44100.0

const MAGIC := "GNAU"


func _init() -> void:
	node_type = "audiostreamin"
	time_dependent = true
	thread_safe = false


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Received audio stream")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("port", 9100, 1024, 65535,
		"Port", "UDP port to listen on"))
	add_parameter(GNParameter.create_bool("active", true,
		"Active", "Enable receiving"))


func _cook(inputs: Array[GNData]) -> GNData:
	var port: int = get_param_value("port")
	var active: bool = get_param_value("active")

	if not active:
		_close()
		return null

	# Bind if port changed
	if port != _listen_port:
		_close()
		_peer = PacketPeerUDP.new()
		var err: Error = _peer.bind(port)
		if err != OK:
			GNLogger.warn("AudioStreamInCHOP", "'%s' — could not bind to port %d" % [id, port])
			_peer = null
			return null
		_listen_port = port

	if _peer == null:
		return null

	# Read all available packets, keep latest
	while _peer.get_available_packet_count() > 0:
		var pkt: PackedByteArray = _peer.get_packet()
		_parse_packet(pkt)

	if _last_left.size() == 0:
		return null

	var out := _prepare_output(_last_sr)
	out.set_channel("left", _last_left)
	if _last_right.size() > 0:
		out.set_channel("right", _last_right)
	return out


func _parse_packet(pkt: PackedByteArray) -> void:
	# Header: 4B magic + 4B sr + 2B channels + 2B samples = 12 bytes
	if pkt.size() < 12:
		return
	var magic: String = pkt.slice(0, 4).get_string_from_ascii()
	if magic != MAGIC:
		return

	_last_sr = pkt.decode_float(4)
	var num_ch: int = pkt.decode_u16(8)
	var num_samples: int = pkt.decode_u16(10)

	var expected: int = 12 + num_samples * num_ch * 4
	if pkt.size() < expected:
		return

	_last_left.resize(num_samples)
	if num_ch >= 2:
		_last_right.resize(num_samples)

	var offset: int = 12
	for s: int in range(num_samples):
		_last_left[s] = pkt.decode_float(offset)
		offset += 4
		if num_ch >= 2:
			_last_right[s] = pkt.decode_float(offset)
			offset += 4


func _close() -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	_listen_port = -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_close()
