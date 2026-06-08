class_name ThresholdIMG
extends GNImgBase
## Binary, Otsu, and adaptive Gaussian/mean thresholding.
##
## Converts an input image into a binary (or to-zero) mask using global or
## spatially-adaptive threshold methods.  Requires GNOpenCV GDExtension.
##
## Native: GNOpenCV.threshold(rgba, w, h, thresh_val, max_val, method,
##         block_size, c_offset) -> PackedByteArray

var _cv: RefCounted = null


func _init() -> void:
	node_type = "threshold"
	node_description = "Binary / Otsu / adaptive thresholding. Requires gn_ext_opencv."


func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, true, "Input image", "In")
	add_output("out", GNFamily.Type.IMG, "Thresholded output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("method",
		PackedStringArray(["Binary", "Binary Inv", "Truncate", "To Zero",
			"To Zero Inv", "Otsu", "Adaptive Mean", "Adaptive Gaussian"]), 0,
		"Method", "Thresholding algorithm"))
	add_parameter(GNParameter.create_float("threshold", 128.0, 0.0, 255.0, 1.0,
		"Threshold", "Global threshold value (ignored by adaptive methods)"))
	add_parameter(GNParameter.create_float("max_value", 255.0, 0.0, 255.0, 1.0,
		"Max Value", "Value assigned to pixels passing the threshold"))
	add_parameter(GNParameter.create_int("block_size", 11, 3, 99,
		"Block Size", "Neighborhood size for adaptive methods (must be odd)"))
	add_parameter(GNParameter.create_float("c_offset", 2.0, -50.0, 50.0, 0.5,
		"C Offset", "Constant subtracted from mean in adaptive methods"))
	add_parameter(GNParameter.create_bool("active", true, "Enable or disable the operator",
		"Enable / disable processing"))


func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_image()
	if not GNOpenCVHelper.is_available():
		return out
	if not get_param_value("active"):
		var src := _get_input_img(inputs, 0)
		if src != null and src.image != null:
			out.set_image(src.image)
		return out

	var src := _get_input_img(inputs, 0)
	if src == null or src.image == null:
		return out

	_ensure_cv()
	if _cv == null:
		return out

	var conv := GNOpenCVHelper.image_to_rgba(src.image)
	var rgba: PackedByteArray = conv[0]
	var w: int = conv[1]
	var h: int = conv[2]
	if rgba.is_empty():
		return out

	var method_idx: int = get_param_value("method")
	var thresh_val: float = get_param_value("threshold")
	var max_val: float = get_param_value("max_value")
	var block: int = get_param_value("block_size")
	if block % 2 == 0:
		block += 1
	var c_off: float = get_param_value("c_offset")

	var result: PackedByteArray = _cv.threshold(
		rgba, w, h, thresh_val, max_val, method_idx, block, c_off)
	if result.is_empty():
		return out

	var img := GNOpenCVHelper.rgba_to_image(result, w, h)
	if img != null:
		out.set_image(img)
	return out


func _ensure_cv() -> void:
	if _cv != null:
		return
	_cv = GNOpenCVHelper.create_instance()
	if _cv == null:
		GNLogger.error("ThresholdIMG", "'%s': failed to instantiate GNOpenCV" % id)
