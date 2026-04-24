class_name CompositeCHOPNative
extends GNChopBase
## Native-accelerated multi-input channel blending — delegates to GNNativeCompositeChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "composite_native"
	node_description = "Blend multiple CHOP inputs with weighted operations — native C++ accelerated."
	if ClassDB.class_exists("GNNativeCompositeChop"):
		_processor = ClassDB.instantiate("GNNativeCompositeChop")


func _init_ports() -> void:
	_enable_dynamic_inputs(GNFamily.Type.CHOP, "ch", "CHOP Input")
	add_output("out", GNFamily.Type.CHOP, "Blended channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("operation",
		PackedStringArray(["Weighted Average", "Add", "Max", "Min"]), 0,
		"Operation", "How to combine inputs"))
	add_parameter(GNParameter.create_string("weights", "1,1,1,1",
		"Weights", "Comma-separated weights for each input"))


func _cook(inputs: Array[GNData]) -> GNData:
	if not _processor:
		return null

	# Collect input channel dictionaries
	var input_dicts: Array = []
	for inp in inputs:
		if inp is GNChannelData:
			input_dicts.append(inp.channels)
	if input_dicts.is_empty():
		return null

	# Parse weights
	var weight_str: String = get_param_value("weights")
	var weight_parts: PackedStringArray = weight_str.split(",")
	var weights := PackedFloat32Array()
	for part in weight_parts:
		weights.append(part.strip_edges().to_float())

	var result: Dictionary = _processor.process(input_dicts, weights,
		get_param_value("operation"))

	var out: GNChannelData = _prepare_output(60.0)
	for ch_name in result:
		out.channels[ch_name] = result[ch_name]
	if not result.is_empty():
		var first_key: String = result.keys()[0]
		out.length = result[first_key].size()
	return out
