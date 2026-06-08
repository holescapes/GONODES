class_name LagCHOPNative
extends GNChopBase
## Native-accelerated attack/release lag — delegates to GNNativeLagChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "lag_native"
	time_dependent = true
	if ClassDB.class_exists("GNNativeLagChop"):
		_processor = ClassDB.instantiate("GNNativeLagChop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels", "In")
	add_output("out", GNFamily.Type.CHOP, "Smoothed channels", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("attack", 0.2, 0.0, 10.0, 0.01,
		"Attack Time (sec)", "Rise smoothing time in seconds"))
	add_parameter(GNParameter.create_float("release", 0.2, 0.0, 10.0, 0.01,
		"Release Time (sec)", "Fall smoothing time in seconds"))
	add_parameter(GNParameter.create_bool("reset", false, "", "Clear smooth state"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data := _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var attack: float = get_param_value("attack")
	var release: float = get_param_value("release")
	var do_reset: bool = get_param_value("reset")

	if do_reset and _processor != null:
		_processor.reset()

	var out := _prepare_output(in_data.sample_rate)

	for ch_name in in_data.channels:
		var samples: PackedFloat32Array = in_data.channels[ch_name]
		if _processor != null:
			out.channels[ch_name] = _processor.process(samples, attack, release, current_delta)
		else:
			out.channels[ch_name] = samples.duplicate()

	out.length = in_data.length
	return out
