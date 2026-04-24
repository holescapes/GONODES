class_name ObjectTrackIMG
extends GNImgBase
## Single-object visual tracker (KCF / CSRT / MOSSE).
##
## Initializes a tracking rectangle from a user-defined ROI (or auto-detects
## from the first frame if left at default).  Each subsequent frame updates
## the tracker; the overlay shows the bounding box.
##
## Requires GNOpenCV GDExtension.
##
## Native: GNOpenCV.tracker_init(rgba, w, h, method, roi_x, roi_y,
##         roi_w, roi_h) -> bool
## Native: GNOpenCV.tracker_update(rgba, w, h,
##         draw_color_r, draw_color_g, draw_color_b,
##         draw_thickness) -> PackedByteArray (overlay image)
## Native: GNOpenCV.tracker_get_roi() -> PackedFloat32Array [x,y,w,h,conf]

var _cv: RefCounted = null
var _tracker_ready: bool = false
var _last_method: int = -1
var _cached_chop_data: GNChannelData = null


func _init() -> void:
	node_type = "object_track"
	node_description = "Single-object visual tracker. Requires gn_ext_opencv."
	time_dependent = true


func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, true, "Input image (video frames)")
	add_output("out", GNFamily.Type.IMG, "Overlay with tracked bounding box")
	add_output("data", GNFamily.Type.CHOP, "Tracked ROI (cx, cy, w, h, confidence)")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("method",
		PackedStringArray(["KCF", "CSRT", "MOSSE"]), 1,
		"Method", "Tracking algorithm (CSRT = accurate, MOSSE = fast)"))
	add_parameter(GNParameter.create_float("roi_x", 0.25, 0.0, 1.0, 0.01,
		"ROI X", "Initial ROI normalized X (0..1)"))
	add_parameter(GNParameter.create_float("roi_y", 0.25, 0.0, 1.0, 0.01,
		"ROI Y", "Initial ROI normalized Y"))
	add_parameter(GNParameter.create_float("roi_w", 0.5, 0.01, 1.0, 0.01,
		"ROI Width", "Initial ROI normalized width"))
	add_parameter(GNParameter.create_float("roi_h", 0.5, 0.01, 1.0, 0.01,
		"ROI Height", "Initial ROI normalized height"))
	add_parameter(GNParameter.create_color("draw_color",
		Color(0.0, 1.0, 0.0, 1.0),
		"Draw Color", "Bounding box overlay color"))
	add_parameter(GNParameter.create_int("draw_thickness", 2, 1, 10,
		"Thickness", "Bounding box line thickness"))
	add_parameter(GNParameter.create_pulse("reinit", "Re-init Tracker",
		"Re-initialize the tracker from the current ROI"))
	add_parameter(GNParameter.create_bool("active", true, "Enable or disable the operator",
		"Enable / disable processing"))


func _pre_cook(_delta: float) -> void:
	if get_param_value("reinit"):
		set_param_value("reinit", false)
		_tracker_ready = false


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

	var method: int = get_param_value("method")

	# Re-init tracker if needed
	if not _tracker_ready or method != _last_method:
		var rx: int = int(get_param_value("roi_x") * w)
		var ry: int = int(get_param_value("roi_y") * h)
		var rw: int = maxi(int(get_param_value("roi_w") * w), 1)
		var rh: int = maxi(int(get_param_value("roi_h") * h), 1)
		_cv.tracker_init(rgba, w, h, method, rx, ry, rw, rh)
		_tracker_ready = true
		_last_method = method

	var c: Color = get_param_value("draw_color")
	var thickness: int = get_param_value("draw_thickness")

	var result: PackedByteArray = _cv.tracker_update(
		rgba, w, h, c.r, c.g, c.b, thickness)

	# Populate CHOP data from tracker ROI (skip if port 1 unconnected)
	if is_output_demanded(1):
		_pull_tracker_chop(w, h)

	if not is_output_demanded(0):
		return out

	if result.is_empty():
		# Tracker lost — pass through original
		out.set_image(src.image)
		return out

	var img := GNOpenCVHelper.rgba_to_image(result, w, h)
	if img != null:
		out.set_image(img)
	return out


## Route multi-output: port 0 = IMG overlay, port 1 = CHOP tracking ROI.
func get_output_data(port_index: int) -> GNData:
	if port_index == 1:
		return _cached_chop_data
	return cached_output


func _pull_tracker_chop(img_w: int, img_h: int) -> void:
	if _cached_chop_data == null:
		_cached_chop_data = GNChannelData.new()
	_cached_chop_data.channels.clear()

	if _cv == null:
		return

	# tracker_get_roi() -> PackedFloat32Array [x, y, w, h, confidence]
	var roi: PackedFloat32Array = _cv.tracker_get_roi()
	if roi.size() >= 5:
		# Output normalized center + size
		_cached_chop_data.set_single_value("cx", (roi[0] + roi[2] * 0.5) / maxf(img_w, 1))
		_cached_chop_data.set_single_value("cy", (roi[1] + roi[3] * 0.5) / maxf(img_h, 1))
		_cached_chop_data.set_single_value("w", roi[2] / maxf(img_w, 1))
		_cached_chop_data.set_single_value("h", roi[3] / maxf(img_h, 1))
		_cached_chop_data.set_single_value("confidence", roi[4])
	else:
		_cached_chop_data.set_single_value("cx", 0.0)
		_cached_chop_data.set_single_value("cy", 0.0)
		_cached_chop_data.set_single_value("w", 0.0)
		_cached_chop_data.set_single_value("h", 0.0)
		_cached_chop_data.set_single_value("confidence", 0.0)


func _ensure_cv() -> void:
	if _cv != null:
		return
	_cv = GNOpenCVHelper.create_instance()
	if _cv == null:
		GNLogger.error("ObjectTrackIMG", "'%s': failed to instantiate GNOpenCV" % id)
