class_name AudioParaEQCHOPNative
extends GNChopBase
## Native-accelerated parametric EQ — delegates to GNNativeAudioParaEqChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "audioparaeq_native"
	if ClassDB.class_exists("GNNativeAudioParaEqChop"):
		_processor = ClassDB.instantiate("GNNativeAudioParaEqChop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Audio input")
	add_output("out", GNFamily.Type.CHOP, "Equalized audio output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("bands", 4, 1, 8,
		"Bands", "Number of active EQ bands"))
	var default_freqs := [80.0, 250.0, 1000.0, 4000.0, 8000.0, 12000.0, 16000.0, 20000.0]
	for b in range(8):
		var n: int = b + 1
		var prefix: String = "b%d_" % n
		add_parameter(GNParameter.create_float(prefix + "freq",
			default_freqs[b], 20.0, 20000.0, 1.0,
			"Band %d Freq" % n, "Center frequency for band %d" % n))
		add_parameter(GNParameter.create_float(prefix + "gain",
			0.0, -24.0, 24.0, 0.1,
			"Band %d Gain" % n, "Gain in dB for band %d" % n))
		add_parameter(GNParameter.create_float(prefix + "q",
			1.0, 0.1, 30.0, 0.01,
			"Band %d Q" % n, "Quality factor for band %d" % n))


func _cook(inputs: Array[GNData]) -> GNData:
	var input_chop := _get_input_chop(inputs, 0)
	if not input_chop:
		return null
	if not _processor:
		return null

	var num_bands: int = get_param_value("bands")
	var sr: float = input_chop.sample_rate

	var freqs := PackedFloat32Array()
	var gains := PackedFloat32Array()
	var qs := PackedFloat32Array()
	for b in range(num_bands):
		var prefix: String = "b%d_" % (b + 1)
		freqs.append(get_param_value(prefix + "freq"))
		gains.append(get_param_value(prefix + "gain"))
		qs.append(get_param_value(prefix + "q"))

	# Pack stereo interleaved
	var left: PackedFloat32Array = input_chop.channels.get("left", PackedFloat32Array())
	var right: PackedFloat32Array = input_chop.channels.get("right", left)
	var frames: int = left.size()
	var interleaved := PackedFloat32Array()
	interleaved.resize(frames * 2)
	for i in range(frames):
		interleaved[i * 2] = left[i]
		interleaved[i * 2 + 1] = right[i] if i < right.size() else left[i]

	var result: PackedFloat32Array = _processor.process(interleaved, freqs, gains, qs, num_bands, sr)

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
