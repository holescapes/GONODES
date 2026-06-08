class_name AnalyzeCHOPNative
extends GNChopBase
## Native-accelerated statistical analysis — delegates to GNNativeAnalyzeChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "analyze_native"
	if ClassDB.class_exists("GNNativeAnalyzeChop"):
		_processor = ClassDB.instantiate("GNNativeAnalyzeChop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels", "In")
	add_output("out", GNFamily.Type.CHOP, "Analysis result (single-sample per channel)", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("function",
		PackedStringArray(["Average", "Minimum", "Maximum", "Sum", "RMS", "Range", "Count"]), 0,
		"Function", "Statistical function to apply"))


func _cook(inputs: Array[GNData]) -> GNData:
	var input_chop := _get_input_chop(inputs, 0)
	if not input_chop:
		return null
	if not _processor:
		return null

	var func_idx: int = get_param_value("function")
	var result: Dictionary = _processor.process(input_chop.channels, func_idx)
	var out := _prepare_output(input_chop.sample_rate)
	for ch_name in result:
		out.channels[ch_name] = result[ch_name]
	out.length = 1
	return out
