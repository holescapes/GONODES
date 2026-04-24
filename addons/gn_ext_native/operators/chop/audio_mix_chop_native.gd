class_name AudioMixCHOPNative
extends GNChopBase
## Native-accelerated audio mixer — delegates to GNNativeAudioMixChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "audiomix_native"
	if ClassDB.class_exists("GNNativeAudioMixChop"):
		_processor = ClassDB.instantiate("GNNativeAudioMixChop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, true, "Audio input source")
	_enable_dynamic_inputs(GNFamily.Type.CHOP, "in", "Audio input source")
	add_output("out", GNFamily.Type.CHOP, "Mixed stereo output")


func _init_parameters() -> void:
	for i in range(8):
		var n: int = i + 1
		var prefix: String = "in%d_" % n
		add_parameter(GNParameter.create_float(prefix + "gain",
			0.0, -60.0, 12.0, 0.1,
			"Input %d Gain" % n, "Gain in dB for input %d" % n))
		add_parameter(GNParameter.create_float(prefix + "pan",
			0.0, -1.0, 1.0, 0.01,
			"Input %d Pan" % n, "Stereo pan for input %d (-1=L, 0=center, +1=R)" % n))
		add_parameter(GNParameter.create_bool(prefix + "mute", false,
			"Input %d Mute" % n, "Mute input %d" % n))
		add_parameter(GNParameter.create_bool(prefix + "solo", false,
			"Input %d Solo" % n, "Solo input %d" % n))
	add_parameter(GNParameter.create_float("master_gain",
		0.0, -60.0, 12.0, 0.1,
		"Master Gain", "Master output gain in dB"))


func _cook(inputs: Array[GNData]) -> GNData:
	if not _processor:
		return null

	var stereo_arrays: Array[PackedFloat32Array] = []
	var volumes := PackedFloat32Array()
	var pans := PackedFloat32Array()
	var has_solo := false
	for i in range(8):
		var prefix: String = "in%d_" % (i + 1)
		if get_param_value(prefix + "solo"):
			has_solo = true
			break

	var sr: float = 44100.0
	for i in range(inputs.size()):
		var chop := _get_input_chop(inputs, i)
		if not chop:
			continue
		sr = chop.sample_rate
		var prefix: String = "in%d_" % (i + 1) if i < 8 else "in8_"
		var mute: bool = get_param_value(prefix + "mute") if i < 8 else false
		var solo: bool = get_param_value(prefix + "solo") if i < 8 else false
		if mute or (has_solo and not solo):
			continue
		var gain_db: float = get_param_value(prefix + "gain") if i < 8 else 0.0
		var pan: float = get_param_value(prefix + "pan") if i < 8 else 0.0
		var left: PackedFloat32Array = chop.channels.get("left", PackedFloat32Array())
		var right: PackedFloat32Array = chop.channels.get("right", left)
		var frames: int = left.size()
		var interleaved := PackedFloat32Array()
		interleaved.resize(frames * 2)
		for f in range(frames):
			interleaved[f * 2] = left[f]
			interleaved[f * 2 + 1] = right[f] if f < right.size() else left[f]
		stereo_arrays.append(interleaved)
		volumes.append(db_to_linear(gain_db))
		pans.append(pan)

	if stereo_arrays.is_empty():
		return null

	var master_db: float = get_param_value("master_gain")
	var master_vol: float = db_to_linear(master_db)
	var typed_inputs: Array = []
	for arr in stereo_arrays:
		typed_inputs.append(arr)
	var result: PackedFloat32Array = _processor.process(typed_inputs, volumes, pans, master_vol)

	var frames: int = result.size() / 2
	var out := _prepare_output(sr)
	var out_l := PackedFloat32Array()
	var out_r := PackedFloat32Array()
	out_l.resize(frames)
	out_r.resize(frames)
	for f in range(frames):
		out_l[f] = result[f * 2]
		out_r[f] = result[f * 2 + 1]
	out.channels["left"] = out_l
	out.channels["right"] = out_r
	out.length = frames
	return out
