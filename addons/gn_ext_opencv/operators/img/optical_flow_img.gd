class_name OpticalFlowIMG
extends GNImgBase
## Dense Farneback optical flow — outputs an RG motion-field image.
##
## Red channel encodes horizontal motion, Green channel encodes vertical
## motion.  The magnitude can be scaled for visualization.  Cross-platform
## CPU implementation (no NVIDIA GPU required).
##
## Requires GNOpenCV GDExtension.
##
## Native: GNOpenCV.optical_flow_farneback(prev_rgba, curr_rgba, w, h,
##         pyr_scale, levels, winsize, iterations, poly_n, poly_sigma,
##         magnitude_scale) -> PackedByteArray (RG flow image)

var _cv: RefCounted = null
var _prev_rgba: PackedByteArray = PackedByteArray()
var _prev_w: int = 0
var _prev_h: int = 0


func _init() -> void:
	node_type = "optical_flow"
	node_description = "Dense optical flow (Farneback). Requires gn_ext_opencv."
	time_dependent = true


func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, true, "Input image (video frames)", "In")
	add_output("out", GNFamily.Type.IMG, "RG motion-field image", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("pyr_scale", 0.5, 0.1, 0.95, 0.05,
		"Pyramid Scale", "Scale between pyramid levels (lower = more levels)"))
	add_parameter(GNParameter.create_int("levels", 3, 1, 10,
		"Levels", "Number of pyramid levels"))
	add_parameter(GNParameter.create_int("winsize", 15, 3, 99,
		"Window Size", "Averaging window size (odd)"))
	add_parameter(GNParameter.create_int("iterations", 3, 1, 20,
		"Iterations", "Solver iterations per pyramid level"))
	add_parameter(GNParameter.create_int("poly_n", 5, 3, 9,
		"Poly N", "Polynomial expansion neighborhood size"))
	add_parameter(GNParameter.create_float("poly_sigma", 1.2, 0.1, 5.0, 0.1,
		"Poly Sigma", "Gaussian sigma for polynomial expansion"))
	add_parameter(GNParameter.create_float("mag_scale", 10.0, 0.1, 100.0, 0.1,
		"Magnitude Scale", "Multiplier for visualizing small motions"))
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

	# First frame — store and return black
	if _prev_rgba.is_empty() or _prev_w != w or _prev_h != h:
		_prev_rgba = rgba.duplicate()
		_prev_w = w
		_prev_h = h
		out.set_image(Image.create(w, h, false, Image.FORMAT_RGBA8))
		return out

	var result: PackedByteArray = _cv.optical_flow_farneback(
		_prev_rgba, rgba, w, h,
		get_param_value("pyr_scale"),
		get_param_value("levels"),
		get_param_value("winsize"),
		get_param_value("iterations"),
		get_param_value("poly_n"),
		get_param_value("poly_sigma"),
		get_param_value("mag_scale"))

	_prev_rgba = rgba.duplicate()

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
		GNLogger.error("OpticalFlowIMG", "'%s': failed to instantiate GNOpenCV" % id)
