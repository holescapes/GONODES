class_name HoughLinesIMG
extends GNImgBase
## Probabilistic Hough line detection with drawn overlay.
##
## Detects straight line segments in an edge-detected image and draws them.
## Best used after EdgeDetectIMG or ThresholdIMG.
##
## Requires GNOpenCV GDExtension.
##
## Native: GNOpenCV.hough_lines(rgba, w, h, rho, theta, threshold,
##         min_length, max_gap, color_r, color_g, color_b,
##         thickness) -> PackedByteArray (overlay)

var _cv: RefCounted = null
var _cached_table: GNTableData = null


func _init() -> void:
	node_type = "hough_lines"
	node_description = "Probabilistic Hough line detection. Requires gn_ext_opencv."


func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, true, "Edge-detected or binary input")
	add_output("out", GNFamily.Type.IMG, "Overlay with detected lines drawn")
	add_output("data", GNFamily.Type.DAT, "Line segments table (x1, y1, x2, y2, length, angle)")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("rho", 1.0, 0.1, 10.0, 0.1,
		"Rho", "Distance resolution in pixels"))
	add_parameter(GNParameter.create_float("theta", 1.0, 0.1, 90.0, 0.1,
		"Theta", "Angle resolution in degrees"))
	add_parameter(GNParameter.create_int("threshold", 50, 1, 500,
		"Threshold", "Minimum vote count for a line"))
	add_parameter(GNParameter.create_float("min_length", 50.0, 0.0, 2000.0, 1.0,
		"Min Length", "Minimum line segment length in pixels"))
	add_parameter(GNParameter.create_float("max_gap", 10.0, 0.0, 200.0, 1.0,
		"Max Gap", "Maximum gap between segments to merge"))
	add_parameter(GNParameter.create_color("color", Color(1.0, 0.0, 0.0, 1.0),
		"Color", "Line drawing color"))
	add_parameter(GNParameter.create_int("thickness", 2, 1, 10,
		"Thickness", "Line drawing thickness"))
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

	var c: Color = get_param_value("color")
	var theta_deg: float = get_param_value("theta")
	# Convert theta from degrees to radians for OpenCV
	var theta_rad: float = deg_to_rad(theta_deg)

	var result: PackedByteArray = _cv.hough_lines(
		rgba, w, h,
		get_param_value("rho"), theta_rad,
		get_param_value("threshold"),
		get_param_value("min_length"),
		get_param_value("max_gap"),
		c.r, c.g, c.b,
		get_param_value("thickness"))

	# Populate DAT with line data (skip if port 1 unconnected)
	if is_output_demanded(1):
		_pull_lines_table()

	if not is_output_demanded(0) or result.is_empty():
		return out

	var img := GNOpenCVHelper.rgba_to_image(result, w, h)
	if img != null:
		out.set_image(img)
	return out


## Route multi-output: port 0 = IMG overlay, port 1 = DAT line table.
func get_output_data(port_index: int) -> GNData:
	if port_index == 1:
		return _cached_table
	return cached_output


func _pull_lines_table() -> void:
	if _cached_table == null:
		_cached_table = GNTableData.new()
	_cached_table.clear()
	_cached_table.set_headers(PackedStringArray(["x1", "y1", "x2", "y2", "length", "angle"]))

	if _cv == null:
		return

	# get_line_data() -> PackedFloat32Array [count, x1_0,y1_0,x2_0,y2_0, x1_1,...]
	var data: PackedFloat32Array = _cv.get_line_data()
	if data.is_empty():
		return

	var count: int = int(data[0])
	var pos: int = 1
	for i in range(count):
		if pos + 4 > data.size():
			break
		var x1: float = data[pos]
		var y1: float = data[pos + 1]
		var x2: float = data[pos + 2]
		var y2: float = data[pos + 3]
		var dx := x2 - x1
		var dy := y2 - y1
		var length := sqrt(dx * dx + dy * dy)
		var angle := rad_to_deg(atan2(dy, dx))
		_cached_table.append_row(PackedStringArray([
			str(int(x1)), str(int(y1)), str(int(x2)), str(int(y2)),
			"%.1f" % length, "%.1f" % angle
		]))
		pos += 4


func _ensure_cv() -> void:
	if _cv != null:
		return
	_cv = GNOpenCVHelper.create_instance()
	if _cv == null:
		GNLogger.error("HoughLinesIMG", "'%s': failed to instantiate GNOpenCV" % id)
