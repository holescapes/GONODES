class_name AudioEnvelopeCHOPNative
extends GNChopBase
## Native-accelerated envelope follower — delegates to GNNativeAudioEnvelopeChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "audioenvelope_native"
	if ClassDB.class_exists("GNNativeAudioEnvelopeChop"):
		_processor = ClassDB.instantiate("GNNativeAudioEnvelopeChop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Audio input to follow")
	add_output("out", GNFamily.Type.CHOP, "Envelope output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Peak", "RMS"]), 0,
		"Mode", "Detection mode — peak tracks instantaneous peaks, RMS tracks average power"))
	add_parameter(GNParameter.create_float("attack_ms", 5.0, 0.1, 500.0, 0.1,
		"Attack (ms)", "Attack time constant in milliseconds"))
	add_parameter(GNParameter.create_float("release_ms", 100.0, 1.0, 5000.0, 1.0,
		"Release (ms)", "Release time constant in milliseconds"))
	add_parameter(GNParameter.create_float("gain", 1.0, 0.0, 10.0, 0.01,
		"Gain", "Output gain multiplier"))


func _cook(inputs: Array[GNData]) -> GNData:
	var input_chop := _get_input_chop(inputs, 0)
	if not input_chop:
		return null
	if not _processor:
		return null

	var attack_ms: float = get_param_value("attack_ms")
	var release_ms: float = get_param_value("release_ms")
	var gain_val: float = get_param_value("gain")
	var sr: float = input_chop.sample_rate

	var attack_sec: float = attack_ms / 1000.0
	var release_sec: float = release_ms / 1000.0

	var left: PackedFloat32Array = input_chop.channels.get("left", PackedFloat32Array())
	var right: PackedFloat32Array = input_chop.channels.get("right", left)
	var frames: int = left.size()
	var interleaved := PackedFloat32Array()
	interleaved.resize(frames * 2)
	for i in range(frames):
		interleaved[i * 2] = left[i]
		interleaved[i * 2 + 1] = right[i] if i < right.size() else left[i]

	var result: PackedFloat32Array = _processor.process(interleaved, attack_sec, release_sec, sr)

	var out := _prepare_output(sr)
	var out_l := PackedFloat32Array()
	var out_r := PackedFloat32Array()
	out_l.resize(frames)
	out_r.resize(frames)
	for i in range(frames):
		out_l[i] = result[i * 2] * gain_val
		out_r[i] = result[i * 2 + 1] * gain_val
	out.channels["left"] = out_l
	out.channels["right"] = out_r
	out.length = frames
	return out
