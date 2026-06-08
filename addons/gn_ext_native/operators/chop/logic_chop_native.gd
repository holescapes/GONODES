class_name LogicCHOPNative
extends GNChopBase
## Native-accelerated boolean logic — delegates to GNNativeLogicChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "logic_native"
	if ClassDB.class_exists("GNNativeLogicChop"):
		_processor = ClassDB.instantiate("GNNativeLogicChop")


func _init_ports() -> void:
	add_input("A", GNFamily.Type.CHOP, false, "First input", "A")
	add_input("B", GNFamily.Type.CHOP, true, "Second input (unused for NOT)", "B")
	add_output("out", GNFamily.Type.CHOP, "Logic result", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("operation",
		PackedStringArray(["AND", "OR", "XOR", "NAND", "NOR", "NOT"]), 0,
		"Operation", "Boolean logic operation"))
	add_parameter(GNParameter.create_float("threshold", 0.5, 0.0, 1.0, 0.01,
		"Threshold", "Values above this are treated as true"))


func _cook(inputs: Array[GNData]) -> GNData:
	var chop_a := _get_input_chop(inputs, 0)
	if not chop_a:
		return null
	if not _processor:
		return null

	var chop_b := _get_input_chop(inputs, 1)
	var op: int = get_param_value("operation")
	var threshold: float = get_param_value("threshold")

	var b_dict: Dictionary = chop_b.channels if chop_b else {}
	var result: Dictionary = _processor.process(chop_a.channels, b_dict, op, threshold)
	var out := _prepare_output(chop_a.sample_rate)
	for ch_name in result:
		out.channels[ch_name] = result[ch_name]
	out.length = chop_a.length
	return out
