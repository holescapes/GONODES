class_name LimitCHOPNative
extends GNChopBase
## Native-accelerated value clamping — delegates to GNNativeLimitChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "limit"
	if ClassDB.class_exists("GNNativeLimitChop"):
		_processor = ClassDB.instantiate("GNNativeLimitChop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels")
	add_output("out", GNFamily.Type.CHOP, "Limited output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("type",
		PackedStringArray(["Clamp", "Loop", "Zig-Zag"]), 0,
		"Type", "Limiting method"))
	add_parameter(GNParameter.create_float("min", 0.0, -1000.0, 1000.0, 0.01,
		"Min", "Minimum value"))
	add_parameter(GNParameter.create_float("max", 1.0, -1000.0, 1000.0, 0.01,
		"Max", "Maximum value"))


func _cook(inputs: Array[GNData]) -> GNData:
	var input_chop := _get_input_chop(inputs, 0)
	if not input_chop:
		return null
	if not _processor:
		return null

	var type: int = get_param_value("type")
	var lo: float = get_param_value("min")
	var hi: float = get_param_value("max")

	var result: Dictionary = _processor.process(input_chop.channels, type, lo, hi)
	var out := _prepare_output(input_chop.sample_rate)
	for ch_name in result:
		out.channels[ch_name] = result[ch_name]
	out.length = input_chop.length
	return out
