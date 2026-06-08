class_name EdgeDetectIMGNative
extends GNImgBase
## Native-accelerated edge detection — delegates to GNNativeEdgeDetect (C++)
## when available, falls back to pure GDScript otherwise.

var _processor: RefCounted = null


func _init() -> void:
	node_type = "edgedetectimg_native"
	node_description = "CPU edge detection (Sobel/Prewitt) — native C++ accelerated."
	if ClassDB.class_exists("GNNativeEdgeDetect"):
		_processor = ClassDB.instantiate("GNNativeEdgeDetect")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, false, "Input image", "In")
	add_output("out", GNFamily.Type.IMG, "Edge-detected image", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("kernel", 0, 0, 1,
		"Kernel", "0 = Sobel, 1 = Prewitt"))
	add_parameter(GNParameter.create_float("strength", 1.0, 0.1, 10.0, 0.1,
		"Strength", "Edge intensity multiplier"))
	add_parameter(GNParameter.create_bool("invert", false,
		"Invert", "Invert output"))
	add_parameter(GNParameter.create_bool("color_edges", false,
		"Color Edges", "Output gradient direction as color"))


func _cook(inputs: Array[GNData]) -> GNData:
	var src: GNImageData = _get_input_img(inputs, 0)
	if src == null or src.image == null:
		return null

	var kernel: int = get_param_value("kernel")
	var strength: float = get_param_value("strength")
	var invert: bool = get_param_value("invert")
	var color_edges: bool = get_param_value("color_edges")

	var result_image: Image
	if _processor != null:
		result_image = _processor.process(src.image, kernel, strength, invert, color_edges)
	else:
		return null  # Fallback handled by core EdgeDetectIMG

	if result_image == null:
		return null

	var out := _prepare_image()
	out.image = result_image
	out.resolution = Vector2i(result_image.get_width(), result_image.get_height())
	out.format = result_image.get_format()
	return out
