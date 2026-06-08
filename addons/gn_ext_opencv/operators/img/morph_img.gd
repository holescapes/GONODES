class_name MorphIMG
extends GNImgBase
## Morphological operations — erode, dilate, open, close, gradient, top-hat,
## black-hat.  Configurable structuring-element shape and kernel size.
##
## Requires GNOpenCV GDExtension.
##
## Native: GNOpenCV.morphology(rgba, w, h, operation, kernel_shape,
##         kernel_size, iterations) -> PackedByteArray

var _cv: RefCounted = null


func _init() -> void:
	node_type = "morph"
	node_description = "Morphological operations. Requires gn_ext_opencv."


func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, true, "Input image", "In")
	add_output("out", GNFamily.Type.IMG, "Morphed output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("operation",
		PackedStringArray(["Erode", "Dilate", "Open", "Close",
			"Gradient", "Top Hat", "Black Hat"]), 0,
		"Operation", "Morphological operation to apply"))
	add_parameter(GNParameter.create_enum("kernel_shape",
		PackedStringArray(["Rectangle", "Cross", "Ellipse"]), 0,
		"Kernel Shape", "Shape of the structuring element"))
	add_parameter(GNParameter.create_int("kernel_size", 5, 1, 99,
		"Kernel Size", "Size of the structuring element (must be odd)"))
	add_parameter(GNParameter.create_int("iterations", 1, 1, 20,
		"Iterations", "Number of times to apply the operation"))
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

	var op: int = get_param_value("operation")
	var shape: int = get_param_value("kernel_shape")
	var ksize: int = get_param_value("kernel_size")
	if ksize % 2 == 0:
		ksize += 1
	var iters: int = get_param_value("iterations")

	var result: PackedByteArray = _cv.morphology(
		rgba, w, h, op, shape, ksize, iters)
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
		GNLogger.error("MorphIMG", "'%s': failed to instantiate GNOpenCV" % id)
