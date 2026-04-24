class_name CrossCHOPNative
extends GNChopBase
## Native-accelerated cross-fade — delegates to GNNativeCrossChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "cross_native"
	if ClassDB.class_exists("GNNativeCrossChop"):
		_processor = ClassDB.instantiate("GNNativeCrossChop")


func _init_ports() -> void:
	add_input("A", GNFamily.Type.CHOP, false, "First input")
	add_input("B", GNFamily.Type.CHOP, false, "Second input")
	add_output("out", GNFamily.Type.CHOP, "Blended output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("cross", 0.5, 0.0, 1.0, 0.01,
		"Cross Value", "Blend factor (0 = A, 1 = B)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var chop_a := _get_input_chop(inputs, 0)
	var chop_b := _get_input_chop(inputs, 1)
	if not chop_a or not chop_b:
		return chop_a if chop_a else chop_b
	if not _processor:
		return null

	var cross_val: float = get_param_value("cross")
	var result: Dictionary = _processor.process(chop_a.channels, chop_b.channels, cross_val)
	var out := _prepare_output(chop_a.sample_rate)
	for ch_name in result:
		out.channels[ch_name] = result[ch_name]
	out.length = maxi(chop_a.length, chop_b.length)
	return out
