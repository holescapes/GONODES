class_name AreaCHOPNative
extends GNChopBase
## Native-accelerated numerical integration — delegates to GNNativeAreaChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "area_native"
	if ClassDB.class_exists("GNNativeAreaChop"):
		_processor = ClassDB.instantiate("GNNativeAreaChop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels to integrate")
	add_output("out", GNFamily.Type.CHOP, "Integrated area values")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("method",
		PackedStringArray(["Trapezoidal", "Simpson's", "Rectangle"]), 0,
		"Method", "Integration method"))
	add_parameter(GNParameter.create_bool("cumulative", false,
		"Cumulative", "Output running integral per sample instead of total area"))


func _cook(inputs: Array[GNData]) -> GNData:
	var input_chop := _get_input_chop(inputs, 0)
	if not input_chop:
		return null
	if not _processor:
		return null

	var method: int = get_param_value("method")
	var cumulative: bool = get_param_value("cumulative")
	var dt: float = 1.0 / maxf(input_chop.sample_rate, 1.0)

	var result: Dictionary = _processor.process(input_chop.channels, method, cumulative, dt)
	var out := _prepare_output(input_chop.sample_rate)
	for ch_name in result:
		out.channels[ch_name] = result[ch_name]
	out.length = input_chop.length
	return out
