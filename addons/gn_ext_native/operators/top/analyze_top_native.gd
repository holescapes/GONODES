class_name AnalyzeTOPNative
extends GNTopBase
## Native-accelerated pixel analysis — delegates to GNNativeAnalyzeTop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "analyze"
	node_description = "Per-pixel min/max/avg/sum statistics — native C++ accelerated."
	if ClassDB.class_exists("GNNativeAnalyzeTop"):
		_processor = ClassDB.instantiate("GNNativeAnalyzeTop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture to analyze")
	add_output("out", GNFamily.Type.TOP, "Analyzed texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Min", "Max", "Average", "Sum"]), 0, "", "Statistical operation"))
	add_parameter(GNParameter.create_int("kernel_size", 8, 1, 64, "Kernel Size", "Neighbourhood radius"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if in_data == null or in_data.texture == null:
		return null

	var mode: int = get_param_value("mode")
	var kernel_size: int = get_param_value("kernel_size")

	if _processor != null:
		var source_image: Image = in_data.texture.get_image()
		if source_image == null:
			return null
		var result: Dictionary = _processor.process(source_image, mode, kernel_size)
		if result.has("image"):
			var out := GNTextureData.new()
			out.set_from_image(result["image"])
			return out

	return null
