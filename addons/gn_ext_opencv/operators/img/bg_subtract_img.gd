class_name BackgroundSubtractIMG
extends GNImgBase
## Adaptive background subtraction (MOG2 / KNN).
##
## Maintains an adaptive background model and outputs a foreground mask
## suitable for compositing or further analysis.  Stateful — the model
## learns over time.
##
## Requires GNOpenCV GDExtension.
##
## Native: GNOpenCV.bg_subtract_init(method, history, threshold) -> void
## Native: GNOpenCV.bg_subtract_apply(rgba, w, h, learning_rate,
##         detect_shadows) -> PackedByteArray (mask)
## Native: GNOpenCV.bg_subtract_reset() -> void

var _cv: RefCounted = null
var _bg_initialized: bool = false
var _last_method: int = -1


func _init() -> void:
	node_type = "bg_subtract"
	node_description = "Background subtraction (MOG2 / KNN). Requires gn_ext_opencv."
	time_dependent = true


func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, true, "Input image (video frames)")
	add_output("out", GNFamily.Type.IMG, "Foreground mask")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("method",
		PackedStringArray(["MOG2", "KNN"]), 0,
		"Method", "Background subtraction algorithm"))
	add_parameter(GNParameter.create_int("history", 500, 1, 5000,
		"History", "Number of frames used to build the background model"))
	add_parameter(GNParameter.create_float("threshold", 16.0, 1.0, 256.0, 1.0,
		"Threshold", "Distance threshold for pixel/background decision"))
	add_parameter(GNParameter.create_float("learning_rate", -1.0, -1.0, 1.0, 0.01,
		"Learning Rate", "Model update speed (-1 = auto)"))
	add_parameter(GNParameter.create_bool("detect_shadows", true,
		"Detect Shadows", "Mark shadow pixels as gray (127) instead of white"))
	add_parameter(GNParameter.create_pulse("reset", "Reset Model",
		"Discard background model and re-learn from scratch"))
	add_parameter(GNParameter.create_bool("active", true, "Enable or disable the operator",
		"Enable / disable processing"))


func _pre_cook(_delta: float) -> void:
	if get_param_value("reset"):
		set_param_value("reset", false)
		if _cv != null:
			_cv.bg_subtract_reset()
		_bg_initialized = false


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

	# Re-init if method changed
	var method: int = get_param_value("method")
	if not _bg_initialized or method != _last_method:
		_cv.bg_subtract_init(method,
			get_param_value("history"),
			get_param_value("threshold"))
		_bg_initialized = true
		_last_method = method

	var lr: float = get_param_value("learning_rate")
	var shadows: bool = get_param_value("detect_shadows")

	var result: PackedByteArray = _cv.bg_subtract_apply(
		rgba, w, h, lr, shadows)
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
		GNLogger.error("BackgroundSubtractIMG", "'%s': failed to instantiate GNOpenCV" % id)
