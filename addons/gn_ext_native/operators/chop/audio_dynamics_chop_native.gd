class_name AudioDynamicsCHOPNative
extends GNChopBase
## Native-accelerated dynamics processor — delegates to GNNativeAudioDynamicsChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "audio_dynamics"
	time_dependent = true
	node_description = "Compressor / Limiter / Expander / Gate — native C++ accelerated."
	if ClassDB.class_exists("GNNativeAudioDynamicsChop"):
		_processor = ClassDB.instantiate("GNNativeAudioDynamicsChop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input audio channels")
	add_output("out", GNFamily.Type.CHOP, "Processed channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Compressor", "Limiter", "Expander", "Gate"]), 0, "Mode", ""))
	add_parameter(GNParameter.create_float("threshold", -18.0, -60.0, 0.0, 0.5, "Threshold (dBFS)", ""))
	add_parameter(GNParameter.create_float("ratio", 4.0, 1.0, 20.0, 0.5, "Ratio", ""))
	add_parameter(GNParameter.create_float("attack", 10.0, 0.1, 500.0, 1.0, "Attack (ms)", ""))
	add_parameter(GNParameter.create_float("release", 100.0, 1.0, 2000.0, 10.0, "Release (ms)", ""))
	add_parameter(GNParameter.create_float("makeup", 0.0, -20.0, 40.0, 0.5, "Makeup (dBFS)", ""))
	add_parameter(GNParameter.create_bool("reset", false, "", "Clear envelope state"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var out: GNChannelData = _prepare_output(in_data.sample_rate)
	if not _processor:
		return out

	var result: Dictionary = _processor.process(in_data.channels,
		get_param_value("mode"), get_param_value("threshold"),
		get_param_value("ratio"), get_param_value("attack"),
		get_param_value("release"), get_param_value("makeup"),
		in_data.sample_rate, get_param_value("reset"))

	for key in result:
		if result[key] is PackedFloat32Array:
			out.set_channel(key, result[key])

	out.length = in_data.length
	return out
