class_name ArucoDetectIMG
extends GNImgBase
## ArUco / AprilTag fiducial marker detection with drawn overlay.
##
## Detects ArUco markers in the input image and draws their outlines and IDs.
## Huge for interactive installations and spatial tracking.
##
## Requires GNOpenCV GDExtension (opencv_contrib aruco module).
##
## Native: GNOpenCV.detect_aruco(rgba, w, h, dictionary,
##         draw_color_r, draw_color_g, draw_color_b,
##         draw_thickness, draw_ids) -> PackedByteArray (overlay)
## Native: GNOpenCV.get_aruco_data() -> PackedFloat32Array
##         [count, id0,cx0,cy0,x0_0,y0_0,...x3_0,y3_0, id1,...]

var _cv: RefCounted = null
var _cached_table: GNTableData = null


func _init() -> void:
	node_type = "aruco_detect"
	node_description = "ArUco / AprilTag fiducial marker detection. Requires gn_ext_opencv."


func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, true, "Input image", "In")
	add_output("out", GNFamily.Type.IMG, "Overlay with detected markers drawn", "Out")
	add_output("data", GNFamily.Type.DAT, "Marker table (id, cx, cy, corners)", "Data")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("dictionary",
		PackedStringArray([
			"4x4_50", "4x4_100", "4x4_250", "4x4_1000",
			"5x5_50", "5x5_100", "5x5_250", "5x5_1000",
			"6x6_50", "6x6_100", "6x6_250", "6x6_1000",
			"7x7_50", "7x7_100", "7x7_250", "7x7_1000",
			"AprilTag 16h5", "AprilTag 25h9", "AprilTag 36h10", "AprilTag 36h11"
		]), 0,
		"Dictionary", "ArUco marker dictionary to search for"))
	add_parameter(GNParameter.create_color("draw_color",
		Color(0.0, 1.0, 0.0, 1.0),
		"Draw Color", "Marker outline color"))
	add_parameter(GNParameter.create_int("thickness", 2, 1, 10,
		"Thickness", "Marker outline thickness"))
	add_parameter(GNParameter.create_bool("draw_ids", true,
		"Draw IDs", "Overlay numeric marker IDs"))
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

	var c: Color = get_param_value("draw_color")

	var result: PackedByteArray = _cv.detect_aruco(
		rgba, w, h,
		get_param_value("dictionary"),
		c.r, c.g, c.b,
		get_param_value("thickness"),
		get_param_value("draw_ids"))

	# Populate DAT with marker data (skip if port 1 unconnected)
	if is_output_demanded(1):
		_pull_aruco_table()

	if not is_output_demanded(0) or result.is_empty():
		return out

	var img := GNOpenCVHelper.rgba_to_image(result, w, h)
	if img != null:
		out.set_image(img)
	return out


## Route multi-output: port 0 = IMG overlay, port 1 = DAT marker table.
func get_output_data(port_index: int) -> GNData:
	if port_index == 1:
		return _cached_table
	return cached_output


func _pull_aruco_table() -> void:
	if _cached_table == null:
		_cached_table = GNTableData.new()
	_cached_table.clear()
	_cached_table.set_headers(PackedStringArray([
		"id", "cx", "cy",
		"c0_x", "c0_y", "c1_x", "c1_y",
		"c2_x", "c2_y", "c3_x", "c3_y"
	]))

	if _cv == null:
		return

	# get_aruco_data() -> PackedFloat32Array [count, id0,cx0,cy0,x0_0,y0_0,...x3_0,y3_0, id1,...]
	var data: PackedFloat32Array = _cv.get_aruco_data()
	if data.is_empty():
		return

	var count: int = int(data[0])
	var pos: int = 1
	# Each marker: id + cx + cy + 4 corners (8) = 11 floats
	for i in range(count):
		if pos + 11 > data.size():
			break
		_cached_table.append_row(PackedStringArray([
			str(int(data[pos])),
			"%.1f" % data[pos + 1],
			"%.1f" % data[pos + 2],
			"%.1f" % data[pos + 3], "%.1f" % data[pos + 4],
			"%.1f" % data[pos + 5], "%.1f" % data[pos + 6],
			"%.1f" % data[pos + 7], "%.1f" % data[pos + 8],
			"%.1f" % data[pos + 9], "%.1f" % data[pos + 10]
		]))
		pos += 11


func _ensure_cv() -> void:
	if _cv != null:
		return
	_cv = GNOpenCVHelper.create_instance()
	if _cv == null:
		GNLogger.error("ArucoDetectIMG", "'%s': failed to instantiate GNOpenCV" % id)
