class_name AudioStreamOutCHOP
extends GNChopBase
## Send audio over network via UDP.
##
## Sends input CHOP audio as UDP packets to a target host and port.
## Designed to pair with AudioStreamInCHOP for machine-to-machine
## audio streaming within installations.
##
## Protocol: [4B magic "GNAU"] [4B sample_rate float] [2B num_channels]
##           [2B num_samples] [N*channels*4B float32 PCM]

var _peer: PacketPeerUDP = null
var _target_host: String = ""
var _target_port: int = -1

const MAGIC := "GNAU"


func _init() -> void:
	node_type = "audiostreamout"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Audio input to stream", "In")
	add_output("out", GNFamily.Type.CHOP, "Pass-through of input", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("host", "127.0.0.1",
		"Host", "Target IP address"))
	add_parameter(GNParameter.create_int("port", 9100, 1024, 65535,
		"Port", "Target UDP port"))
	add_parameter(GNParameter.create_bool("active", true,
		"Active", "Enable sending"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var active: bool = get_param_value("active")
	if not active:
		return in_data

	var host: String = get_param_value("host")
	var port: int = get_param_value("port")

	# Reconnect if target changed
	if host != _target_host or port != _target_port:
		_close()
		_peer = PacketPeerUDP.new()
		_peer.set_dest_address(host, port)
		_target_host = host
		_target_port = port

	if _peer == null:
		return in_data

	# Build packet
	var names: PackedStringArray = in_data.get_channel_names()
	if names.size() == 0:
		return in_data

	var num_ch: int = mini(names.size(), 2)  # Stereo max
	var ch_l: PackedFloat32Array = in_data.get_channel(names[0])
	var ch_r: PackedFloat32Array = in_data.get_channel(names[1]) if num_ch >= 2 else PackedFloat32Array()
	var num_samples: int = ch_l.size()

	if num_samples == 0:
		return in_data

	# Cap packet size (UDP safe limit ~1400 bytes → ~340 stereo samples)
	var max_samples: int = 340 if num_ch >= 2 else 680
	if num_samples > max_samples:
		num_samples = max_samples

	var sr: float = in_data.sample_rate if in_data.sample_rate > 0.0 else AudioServer.get_mix_rate()

	var pkt := PackedByteArray()
	pkt.resize(12 + num_samples * num_ch * 4)

	# Header
	var magic_bytes: PackedByteArray = MAGIC.to_ascii_buffer()
	for i: int in range(4):
		pkt[i] = magic_bytes[i]
	pkt.encode_float(4, sr)
	pkt.encode_u16(8, num_ch)
	pkt.encode_u16(10, num_samples)

	# Interleaved samples
	var offset: int = 12
	for s: int in range(num_samples):
		pkt.encode_float(offset, ch_l[s])
		offset += 4
		if num_ch >= 2:
			pkt.encode_float(offset, ch_r[s] if s < ch_r.size() else 0.0)
			offset += 4

	_peer.put_packet(pkt)
	return in_data


func _close() -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	_target_host = ""
	_target_port = -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_close()
