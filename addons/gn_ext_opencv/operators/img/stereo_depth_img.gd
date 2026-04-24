class_name StereoDepthIMG
extends GNImgBase
## Depth map from a stereo image pair (left / right cameras).
##
## Computes a disparity map using the Semi-Global Block Matching (SGBM)
## algorithm.  No depth-sensor hardware needed — just two camera views.
##
## Requires GNOpenCV GDExtension.
##
## Native: GNOpenCV.stereo_depth(rgba_left, rgba_right, w, h,
##         num_disparities, block_size, min_disparity,
##         uniqueness_ratio, speckle_window, speckle_range)
##         -> PackedByteArray (normalized depth image)

var _cv: RefCounted = null


func _init() -> void:
	node_type = "stereo_depth"
	node_description = "Stereo depth map from left/right pair. Requires gn_ext_opencv."


func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])


func _init_ports() -> void:
	add_input("left", GNFamily.Type.IMG, true, "Left camera image")
	add_input("right", GNFamily.Type.IMG, true, "Right camera image")
	add_output("out", GNFamily.Type.IMG, "Depth map (grayscale)")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("num_disparities", 64, 16, 256,
		"Num Disparities", "Range of disparity search (must be multiple of 16)"))
	add_parameter(GNParameter.create_int("block_size", 5, 3, 21,
		"Block Size", "Matching block size (odd, 3-21)"))
	add_parameter(GNParameter.create_int("min_disparity", 0, -128, 128,
		"Min Disparity", "Minimum possible disparity value"))
	add_parameter(GNParameter.create_int("uniqueness", 10, 0, 30,
		"Uniqueness Ratio", "Best match margin of improvement over second-best (%)"))
	add_parameter(GNParameter.create_int("speckle_window", 100, 0, 500,
		"Speckle Window", "Window size for speckle noise filtering"))
	add_parameter(GNParameter.create_int("speckle_range", 32, 0, 128,
		"Speckle Range", "Max disparity variation within speckle component"))
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

	var left := _get_input_img(inputs, 0)
	var right := _get_input_img(inputs, 1)
	if left == null or left.image == null or right == null or right.image == null:
		return out

	_ensure_cv()
	if _cv == null:
		return out

	var conv_l := GNOpenCVHelper.image_to_rgba(left.image)
	var conv_r := GNOpenCVHelper.image_to_rgba(right.image)
	var rgba_l: PackedByteArray = conv_l[0]
	var wl: int = conv_l[1]
	var hl: int = conv_l[2]
	var rgba_r: PackedByteArray = conv_r[0]
	if rgba_l.is_empty() or rgba_r.is_empty():
		return out

	# Ensure num_disparities is multiple of 16
	var nd: int = get_param_value("num_disparities")
	nd = maxi((nd / 16) * 16, 16)
	var bs: int = get_param_value("block_size")
	if bs % 2 == 0:
		bs += 1

	var result: PackedByteArray = _cv.stereo_depth(
		rgba_l, rgba_r, wl, hl,
		nd, bs,
		get_param_value("min_disparity"),
		get_param_value("uniqueness"),
		get_param_value("speckle_window"),
		get_param_value("speckle_range"))
	if result.is_empty():
		return out

	var img := GNOpenCVHelper.rgba_to_image(result, wl, hl)
	if img != null:
		out.set_image(img)
	return out


func _ensure_cv() -> void:
	if _cv != null:
		return
	_cv = GNOpenCVHelper.create_instance()
	if _cv == null:
		GNLogger.error("StereoDepthIMG", "'%s': failed to instantiate GNOpenCV" % id)
