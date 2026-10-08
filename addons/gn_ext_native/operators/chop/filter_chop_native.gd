class_name FilterCHOPNative
extends GNChopBase
## Native-accelerated IIR filter — delegates to GNNativeFilterChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "filter_native"
	node_description = "Smooth/filter channels with LP or HP — native C++ accelerated."
	if ClassDB.class_exists("GNNativeFilterChop"):
		_processor = ClassDB.instantiate("GNNativeFilterChop")


func update_time_dependency() -> void:
	time_dependent = _temporal_moving


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels", "In")
	add_output("out", GNFamily.Type.CHOP, "Filtered channels", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("type",
		PackedStringArray(["Low Pass", "High Pass"]), 0, "", "Filter algorithm"))
	add_parameter(GNParameter.create_float("cutoff", 0.1, 0.001, 1.0, 0.001,
		"Filter Cutoff (0-1)", "Cutoff frequency"))
	add_parameter(GNParameter.create_bool("reset", false, "", "Clear filter state"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var filter_type: int = get_param_value("type")
	var cutoff: float = get_param_value("cutoff")
	var do_reset: bool = get_param_value("reset")

	if do_reset:
		_temporal_end_state.clear()
	if _processor == null:
		_finish_temporal_cook(true)
		return null
	var channels := {}
	for ch_name in in_data.channels:
		channels[ch_name] = in_data.channels[ch_name]
	var result: Dictionary = _processor.process(channels, filter_type, cutoff, do_reset)
	var out: GNChannelData = _prepare_output(in_data.sample_rate)
	for key in result:
		out.channels[key] = result[key]
	out.length = in_data.length
	var moved := false
	for ch_name in out.channels:
		var samples: PackedFloat32Array = out.channels[ch_name]
		if _temporal_sample_moved(str(ch_name), _temporal_end_sample(samples)):
			moved = true
	_finish_temporal_cook(moved)
	return out
