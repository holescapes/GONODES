class_name SlopeCHOPNative
extends GNChopBase
## Native-accelerated derivative — delegates to GNNativeSlopeChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "slope_native"
	time_dependent = true
	node_description = "Per-sample derivative of channels — native C++ accelerated."
	if ClassDB.class_exists("GNNativeSlopeChop"):
		_processor = ClassDB.instantiate("GNNativeSlopeChop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels")
	add_output("out", GNFamily.Type.CHOP, "Derivative channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("order",
		PackedStringArray(["1st Derivative", "2nd Derivative"]), 0, "", "Order"))
	add_parameter(GNParameter.create_bool("normalize", true, "Normalize by dt", ""))
	add_parameter(GNParameter.create_float("multiply", 1.0, null, null, 0.01, "Multiply", "Output scale"))
	add_parameter(GNParameter.create_bool("reset", false, "", "Reset state"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var order: int = get_param_value("order")
	var scale: float = get_param_value("multiply")
	var do_reset: bool = get_param_value("reset")

	if _processor != null:
		var channels := {}
		for ch_name in in_data.channels:
			channels[ch_name] = in_data.channels[ch_name]
		var result: Dictionary = _processor.process(channels, order, scale, do_reset)
		var out: GNChannelData = _prepare_output(in_data.sample_rate)
		for key in result:
			out.channels[key] = result[key]
		out.length = in_data.length
		return out
	else:
		return null
