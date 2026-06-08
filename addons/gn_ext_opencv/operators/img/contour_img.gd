class_name ContourIMG
extends GNImgBase
## Find and draw contours on a binary / thresholded image.
##
## Detects contours using configurable retrieval mode and approximation
## method, then draws them as colored overlays.  Use with ThresholdIMG
## or BackgroundSubtractIMG upstream.
##
## Requires GNOpenCV GDExtension.
##
## Native: GNOpenCV.find_contours(rgba, w, h, mode, method) -> PackedFloat32Array
## Native: GNOpenCV.draw_contours(rgba, w, h, idx, color_r, color_g, color_b,
##         thickness, min_area) -> PackedByteArray

var _cv: RefCounted = null
var _cached_table: GNTableData = null


func _init() -> void:
	node_type = "contour"
	node_description = "Contour detection and drawing. Requires gn_ext_opencv."


func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, true, "Binary / thresholded input", "In")
	add_output("out", GNFamily.Type.IMG, "Overlay with contours drawn", "Out")
	add_output("data", GNFamily.Type.DAT, "Contour table (index, area, cx, cy, perimeter, vertices)", "Data")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["External", "List", "Connected Components", "Tree"]), 0,
		"Retrieval Mode", "Contour retrieval mode"))
	add_parameter(GNParameter.create_enum("method",
		PackedStringArray(["None", "Simple", "TC89 L1", "TC89 KCOS"]), 1,
		"Approximation", "Contour approximation method"))
	add_parameter(GNParameter.create_float("min_area", 0.0, 0.0, 100000.0, 1.0,
		"Min Area", "Ignore contours smaller than this area"))
	add_parameter(GNParameter.create_color("color", Color(0.0, 1.0, 0.0, 1.0),
		"Color", "Draw color for contour outlines"))
	add_parameter(GNParameter.create_int("thickness", 2, 1, 20,
		"Thickness", "Contour line thickness (-1 = filled)"))
	add_parameter(GNParameter.create_bool("draw_all", true,
		"Draw All", "Draw all contours (off = draw only the largest)"))
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

	var mode_idx: int = get_param_value("mode")
	var method_idx: int = get_param_value("method")
	var min_area: float = get_param_value("min_area")
	var c: Color = get_param_value("color")
	var thickness: int = get_param_value("thickness")
	var draw_all: bool = get_param_value("draw_all")

	# -1 for all contours, 0 for largest only
	var draw_idx: int = -1 if draw_all else 0

	var result: PackedByteArray = _cv.draw_contours(
		rgba, w, h, mode_idx, method_idx, draw_idx,
		c.r, c.g, c.b, thickness, min_area)

	# Populate DAT with contour metadata (skip if port 1 unconnected)
	if is_output_demanded(1):
		_pull_contour_table()

	if not is_output_demanded(0) or result.is_empty():
		return out

	var img := GNOpenCVHelper.rgba_to_image(result, w, h)
	if img != null:
		out.set_image(img)
	return out


## Route multi-output: port 0 = IMG overlay, port 1 = DAT contour table.
func get_output_data(port_index: int) -> GNData:
	if port_index == 1:
		return _cached_table
	return cached_output


func _pull_contour_table() -> void:
	if _cached_table == null:
		_cached_table = GNTableData.new()
	_cached_table.clear()
	_cached_table.set_headers(PackedStringArray(["index", "area", "cx", "cy", "perimeter", "vertices"]))

	if _cv == null:
		return

	# get_contour_data() -> PackedFloat32Array [count, idx0,area0,cx0,cy0,peri0,verts0, ...]
	var data: PackedFloat32Array = _cv.get_contour_data()
	if data.is_empty():
		return

	var count: int = int(data[0])
	var pos: int = 1
	for i in range(count):
		if pos + 6 > data.size():
			break
		_cached_table.append_row(PackedStringArray([
			str(int(data[pos])),
			"%.1f" % data[pos + 1],
			"%.1f" % data[pos + 2],
			"%.1f" % data[pos + 3],
			"%.1f" % data[pos + 4],
			str(int(data[pos + 5]))
		]))
		pos += 6


func _ensure_cv() -> void:
	if _cv != null:
		return
	_cv = GNOpenCVHelper.create_instance()
	if _cv == null:
		GNLogger.error("ContourIMG", "'%s': failed to instantiate GNOpenCV" % id)
