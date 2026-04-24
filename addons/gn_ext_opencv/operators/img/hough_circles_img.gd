class_name HoughCirclesIMG
extends GNImgBase
## Hough circle detection with drawn overlay.
##
## Detects circles in a grayscale or edge-detected image and draws them.
##
## Requires GNOpenCV GDExtension.
##
## Native: GNOpenCV.hough_circles(rgba, w, h, dp, min_dist,
##         high_threshold, center_threshold, min_radius, max_radius,
##         color_r, color_g, color_b, thickness) -> PackedByteArray

var _cv: RefCounted = null
var _cached_table: GNTableData = null


func _init() -> void:
	node_type = "hough_circles"
	node_description = "Hough circle detection. Requires gn_ext_opencv."


func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, true, "Input image")
	add_output("out", GNFamily.Type.IMG, "Overlay with detected circles drawn")
	add_output("data", GNFamily.Type.DAT, "Detected circles table (cx, cy, radius)")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("dp", 1.0, 0.5, 4.0, 0.1,
		"DP", "Inverse ratio of accumulator resolution to image resolution"))
	add_parameter(GNParameter.create_float("min_dist", 50.0, 1.0, 1000.0, 1.0,
		"Min Dist", "Minimum distance between detected circle centers"))
	add_parameter(GNParameter.create_float("high_thresh", 100.0, 1.0, 500.0, 1.0,
		"Canny High", "Upper Canny edge threshold"))
	add_parameter(GNParameter.create_float("center_thresh", 100.0, 1.0, 500.0, 1.0,
		"Center Threshold", "Accumulator threshold for center detection"))
	add_parameter(GNParameter.create_int("min_radius", 0, 0, 2000,
		"Min Radius", "Minimum circle radius (0 = no minimum)"))
	add_parameter(GNParameter.create_int("max_radius", 0, 0, 2000,
		"Max Radius", "Maximum circle radius (0 = no maximum)"))
	add_parameter(GNParameter.create_color("color", Color(0.0, 1.0, 1.0, 1.0),
		"Color", "Circle drawing color"))
	add_parameter(GNParameter.create_int("thickness", 2, 1, 10,
		"Thickness", "Circle drawing thickness"))
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

	var c: Color = get_param_value("color")

	var result: PackedByteArray = _cv.hough_circles(
		rgba, w, h,
		get_param_value("dp"),
		get_param_value("min_dist"),
		get_param_value("high_thresh"),
		get_param_value("center_thresh"),
		get_param_value("min_radius"),
		get_param_value("max_radius"),
		c.r, c.g, c.b,
		get_param_value("thickness"))

	# Populate DAT with circle data (skip if port 1 unconnected)
	if is_output_demanded(1):
		_pull_circles_table()

	if not is_output_demanded(0) or result.is_empty():
		return out

	var img := GNOpenCVHelper.rgba_to_image(result, w, h)
	if img != null:
		out.set_image(img)
	return out


## Route multi-output: port 0 = IMG overlay, port 1 = DAT circle table.
func get_output_data(port_index: int) -> GNData:
	if port_index == 1:
		return _cached_table
	return cached_output


func _pull_circles_table() -> void:
	if _cached_table == null:
		_cached_table = GNTableData.new()
	_cached_table.clear()
	_cached_table.set_headers(PackedStringArray(["cx", "cy", "radius"]))

	if _cv == null:
		return

	# get_circle_data() -> PackedFloat32Array [count, cx0,cy0,r0, cx1,cy1,r1, ...]
	var data: PackedFloat32Array = _cv.get_circle_data()
	if data.is_empty():
		return

	var count: int = int(data[0])
	var pos: int = 1
	for i in range(count):
		if pos + 3 > data.size():
			break
		_cached_table.append_row(PackedStringArray([
			"%.1f" % data[pos],
			"%.1f" % data[pos + 1],
			"%.1f" % data[pos + 2]
		]))
		pos += 3


func _ensure_cv() -> void:
	if _cv != null:
		return
	_cv = GNOpenCVHelper.create_instance()
	if _cv == null:
		GNLogger.error("HoughCirclesIMG", "'%s': failed to instantiate GNOpenCV" % id)
