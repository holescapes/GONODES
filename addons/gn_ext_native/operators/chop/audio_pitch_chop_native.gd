class_name AudioPitchCHOPNative
extends GNChopBase
## Native-accelerated granular pitch shifter — delegates to GNNativeAudioPitchChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "audiopitch"
	if ClassDB.class_exists("GNNativeAudioPitchChop"):
		_processor = ClassDB.instantiate("GNNativeAudioPitchChop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Audio input")
	add_output("out", GNFamily.Type.CHOP, "Pitch-shifted audio output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("semitones", 0.0, -24.0, 24.0, 0.1,
		"Semitones", "Pitch shift in semitones"))
	add_parameter(GNParameter.create_float("grain_size", 0.05, 0.01, 0.2, 0.001,
		"Grain Size", "Grain window size in seconds"))
	add_parameter(GNParameter.create_float("wet", 1.0, 0.0, 1.0, 0.01,
		"Wet", "Wet (shifted) signal level"))
	add_parameter(GNParameter.create_float("dry", 0.0, 0.0, 1.0, 0.01,
		"Dry", "Dry (original) signal level"))


func _cook(inputs: Array[GNData]) -> GNData:
	var input_chop := _get_input_chop(inputs, 0)
	if not input_chop:
		return null
	if not _processor:
		return null

	var semitones: float = get_param_value("semitones")
	var grain_size_sec: float = get_param_value("grain_size")
	var wet: float = get_param_value("wet")
	var dry: float = get_param_value("dry")
	var sr: float = input_chop.sample_rate

	var pitch_shift: float = pow(2.0, semitones / 12.0)
	var grain_samples: int = int(grain_size_sec * sr)

	var left: PackedFloat32Array = input_chop.channels.get("left", PackedFloat32Array())
	var right: PackedFloat32Array = input_chop.channels.get("right", left)
	var frames: int = left.size()
	var interleaved := PackedFloat32Array()
	interleaved.resize(frames * 2)
	for i in range(frames):
		interleaved[i * 2] = left[i]
		interleaved[i * 2 + 1] = right[i] if i < right.size() else left[i]

	var result: PackedFloat32Array = _processor.process(interleaved, pitch_shift, grain_samples, sr)

	var out := _prepare_output(sr)
	var out_l := PackedFloat32Array()
	var out_r := PackedFloat32Array()
	out_l.resize(frames)
	out_r.resize(frames)
	for i in range(frames):
		out_l[i] = result[i * 2] * wet + left[i] * dry
		out_r[i] = result[i * 2 + 1] * wet + (right[i] if i < right.size() else left[i]) * dry
	out.channels["left"] = out_l
	out.channels["right"] = out_r
	out.length = frames
	return out
