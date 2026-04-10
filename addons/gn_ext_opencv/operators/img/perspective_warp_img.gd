class_name PerspectiveWarpIMG
extends GNImgBase
## 4-point homography perspective warp.
##
## Maps a quadrilateral in the source image to a rectangle in the output (or
## vice versa).  Useful for keystoning, surface mapping, and document
## scanning.  Source and destination corners are specified as normalized
## coordinates (0..1).
##
## Requires GNOpenCV GDExtension.
##
## Native: GNOpenCV.perspective_warp(rgba, w, h, src_points, dst_points,
##         out_w, out_h, interpolation) -> PackedByteArray

var _cv: RefCounted = null


func _init() -> void:
	node_type = "perspective_warp"
	node_description = "4-point homography perspective warp. Requires gn_ext_opencv."


func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, true, "Input image")
	add_output("out", GNFamily.Type.IMG, "Warped output")


func _init_parameters() -> void:
	# Source corners (normalized 0..1) — default = full image
	add_parameter(GNParameter.create_float("src_x0", 0.0, 0.0, 1.0, 0.01,
		"Src TL X", "Source top-left X"))
	add_parameter(GNParameter.create_float("src_y0", 0.0, 0.0, 1.0, 0.01,
		"Src TL Y", "Source top-left Y"))
	add_parameter(GNParameter.create_float("src_x1", 1.0, 0.0, 1.0, 0.01,
		"Src TR X", "Source top-right X"))
	add_parameter(GNParameter.create_float("src_y1", 0.0, 0.0, 1.0, 0.01,
		"Src TR Y", "Source top-right Y"))
	add_parameter(GNParameter.create_float("src_x2", 1.0, 0.0, 1.0, 0.01,
		"Src BR X", "Source bottom-right X"))
	add_parameter(GNParameter.create_float("src_y2", 1.0, 0.0, 1.0, 0.01,
		"Src BR Y", "Source bottom-right Y"))
	add_parameter(GNParameter.create_float("src_x3", 0.0, 0.0, 1.0, 0.01,
		"Src BL X", "Source bottom-left X"))
	add_parameter(GNParameter.create_float("src_y3", 1.0, 0.0, 1.0, 0.01,
		"Src BL Y", "Source bottom-left Y"))
	# Destination corners — default = full output
	add_parameter(GNParameter.create_float("dst_x0", 0.0, 0.0, 1.0, 0.01,
		"Dst TL X", "Destination top-left X"))
	add_parameter(GNParameter.create_float("dst_y0", 0.0, 0.0, 1.0, 0.01,
		"Dst TL Y", "Destination top-left Y"))
	add_parameter(GNParameter.create_float("dst_x1", 1.0, 0.0, 1.0, 0.01,
		"Dst TR X", "Destination top-right X"))
	add_parameter(GNParameter.create_float("dst_y1", 0.0, 0.0, 1.0, 0.01,
		"Dst TR Y", "Destination top-right Y"))
	add_parameter(GNParameter.create_float("dst_x2", 1.0, 0.0, 1.0, 0.01,
		"Dst BR X", "Destination bottom-right X"))
	add_parameter(GNParameter.create_float("dst_y2", 1.0, 0.0, 1.0, 0.01,
		"Dst BR Y", "Destination bottom-right Y"))
	add_parameter(GNParameter.create_float("dst_x3", 0.0, 0.0, 1.0, 0.01,
		"Dst BL X", "Destination bottom-left X"))
	add_parameter(GNParameter.create_float("dst_y3", 1.0, 0.0, 1.0, 0.01,
		"Dst BL Y", "Destination bottom-left Y"))
	add_parameter(GNParameter.create_enum("interpolation",
		PackedStringArray(["Nearest", "Linear", "Cubic", "Lanczos"]), 1,
		"Interpolation", "Pixel interpolation mode"))
	add_parameter(GNParameter.create_bool("active", true, "",
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

	# Build source and dest point arrays (pixel coords)
	var src_pts := PackedFloat32Array([
		get_param_value("src_x0") * w, get_param_value("src_y0") * h,
		get_param_value("src_x1") * w, get_param_value("src_y1") * h,
		get_param_value("src_x2") * w, get_param_value("src_y2") * h,
		get_param_value("src_x3") * w, get_param_value("src_y3") * h,
	])
	var dst_pts := PackedFloat32Array([
		get_param_value("dst_x0") * w, get_param_value("dst_y0") * h,
		get_param_value("dst_x1") * w, get_param_value("dst_y1") * h,
		get_param_value("dst_x2") * w, get_param_value("dst_y2") * h,
		get_param_value("dst_x3") * w, get_param_value("dst_y3") * h,
	])
	var interp: int = get_param_value("interpolation")

	var result: PackedByteArray = _cv.perspective_warp(
		rgba, w, h, src_pts, dst_pts, w, h, interp)
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
		GNLogger.error("PerspectiveWarpIMG", "'%s': failed to instantiate GNOpenCV" % id)
