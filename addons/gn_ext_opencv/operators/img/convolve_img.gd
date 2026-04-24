class_name ConvolveIMG
extends GNImgBase
## Arbitrary NxN kernel convolution.
##
## Applies a user-defined convolution kernel to the input image.  Includes
## preset kernels (sharpen, emboss, blur, edge) and a custom mode where the
## kernel is entered as comma-separated values.
##
## Requires GNOpenCV GDExtension.
##
## Native: GNOpenCV.convolve(rgba, w, h, kernel, kernel_w, kernel_h,
##         normalize, border_mode) -> PackedByteArray

var _cv: RefCounted = null

# Built-in kernel presets (row-major, 3x3)
const KERNELS := {
	# 0 = Custom
	1: { "name": "Sharpen", "w": 3, "h": 3, "data": [0,-1,0, -1,5,-1, 0,-1,0] },
	2: { "name": "Emboss", "w": 3, "h": 3, "data": [-2,-1,0, -1,1,1, 0,1,2] },
	3: { "name": "Box Blur 3x3", "w": 3, "h": 3, "data": [1,1,1, 1,1,1, 1,1,1] },
	4: { "name": "Box Blur 5x5", "w": 5, "h": 5, "data": [
		1,1,1,1,1, 1,1,1,1,1, 1,1,1,1,1, 1,1,1,1,1, 1,1,1,1,1] },
	5: { "name": "Edge Detect", "w": 3, "h": 3, "data": [-1,-1,-1, -1,8,-1, -1,-1,-1] },
	6: { "name": "Ridge", "w": 3, "h": 3, "data": [-1,-1,-1, -1,4,-1, -1,-1,-1] },
	7: { "name": "Unsharp", "w": 5, "h": 5, "data": [
		-1,-4,-6,-4,-1, -4,-16,-24,-16,-4, -6,-24,476,-24,-6,
		-4,-16,-24,-16,-4, -1,-4,-6,-4,-1] },
}


func _init() -> void:
	node_type = "convolve"
	node_description = "Arbitrary NxN kernel convolution. Requires gn_ext_opencv."


func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, true, "Input image")
	add_output("out", GNFamily.Type.IMG, "Convolved output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("preset",
		PackedStringArray(["Custom", "Sharpen", "Emboss", "Box Blur 3x3",
			"Box Blur 5x5", "Edge Detect", "Ridge", "Unsharp"]), 1,
		"Preset", "Built-in kernel preset (0 = Custom)"))
	add_parameter(GNParameter.create_string("custom_kernel", "0,-1,0,-1,5,-1,0,-1,0",
		"Custom Kernel", "Comma-separated kernel values (row-major)"))
	add_parameter(GNParameter.create_int("custom_w", 3, 1, 15,
		"Custom Width", "Kernel width (must be odd)"))
	add_parameter(GNParameter.create_int("custom_h", 3, 1, 15,
		"Custom Height", "Kernel height (must be odd)"))
	add_parameter(GNParameter.create_bool("normalize", true,
		"Normalize", "Normalize kernel so values sum to 1"))
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

	var preset: int = get_param_value("preset")
	var kernel := PackedFloat32Array()
	var kw: int
	var kh: int

	if preset > 0 and KERNELS.has(preset):
		var k: Dictionary = KERNELS[preset]
		kw = k["w"]
		kh = k["h"]
		var data: Array = k["data"]
		kernel.resize(data.size())
		for i in range(data.size()):
			kernel[i] = float(data[i])
	else:
		# Custom kernel from string
		kw = get_param_value("custom_w")
		kh = get_param_value("custom_h")
		if kw % 2 == 0: kw += 1
		if kh % 2 == 0: kh += 1
		var raw: String = get_param_value("custom_kernel")
		var parts := raw.split(",")
		kernel.resize(kw * kh)
		for i in range(mini(parts.size(), kw * kh)):
			kernel[i] = parts[i].strip_edges().to_float()

	var do_normalize: bool = get_param_value("normalize")

	var result: PackedByteArray = _cv.convolve(
		rgba, w, h, kernel, kw, kh, do_normalize)
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
		GNLogger.error("ConvolveIMG", "'%s': failed to instantiate GNOpenCV" % id)
