class_name AudioReverbCHOPNative
extends GNChopBase
## Native-accelerated Schroeder reverb — delegates to GNNativeAudioReverbChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "audioreverb_native"
	if ClassDB.class_exists("GNNativeAudioReverbChop"):
		_processor = ClassDB.instantiate("GNNativeAudioReverbChop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Audio input")
	add_output("out", GNFamily.Type.CHOP, "Reverb output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("room_size", 0.7, 0.0, 1.0, 0.01,
		"Room Size", "Reverb decay time (larger = longer tail)"))
	add_parameter(GNParameter.create_float("damping", 0.5, 0.0, 1.0, 0.01,
		"Damping", "High-frequency damping (higher = darker reverb)"))
	add_parameter(GNParameter.create_float("wet", 0.3, 0.0, 1.0, 0.01,
		"Wet", "Wet (reverb) level"))
	add_parameter(GNParameter.create_float("dry", 1.0, 0.0, 1.0, 0.01,
		"Dry", "Dry (original) level"))
	add_parameter(GNParameter.create_float("width", 1.0, 0.0, 1.0, 0.01,
		"Width", "Stereo width of reverb"))


func _cook(inputs: Array[GNData]) -> GNData:
	var input_chop := _get_input_chop(inputs, 0)
	if not input_chop:
		return null
	if not _processor:
		return null

	var room_size: float = get_param_value("room_size")
	var damping: float = get_param_value("damping")
	var wet: float = get_param_value("wet")
	var dry: float = get_param_value("dry")
	var sr: float = input_chop.sample_rate

	var left: PackedFloat32Array = input_chop.channels.get("left", PackedFloat32Array())
	var right: PackedFloat32Array = input_chop.channels.get("right", left)
	var frames: int = left.size()
	var interleaved := PackedFloat32Array()
	interleaved.resize(frames * 2)
	for i in range(frames):
		interleaved[i * 2] = left[i]
		interleaved[i * 2 + 1] = right[i] if i < right.size() else left[i]

	var result: PackedFloat32Array = _processor.process(interleaved, room_size, damping, wet, dry, sr)

	var out := _prepare_output(sr)
	var out_l := PackedFloat32Array()
	var out_r := PackedFloat32Array()
	out_l.resize(frames)
	out_r.resize(frames)
	for i in range(frames):
		out_l[i] = result[i * 2]
		out_r[i] = result[i * 2 + 1]
	out.channels["left"] = out_l
	out.channels["right"] = out_r
	out.length = frames
	return out
