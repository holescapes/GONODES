class_name BlobTrackIMG
extends GNImgBase
## Blob detection with persistent ID tracking across frames.
##
## Detects connected bright regions (blobs) in the input image and draws
## overlay circles / bounding boxes with tracked IDs.  Configurable area,
## circularity, convexity, and inertia filters.
##
## Requires GNOpenCV GDExtension.
##
## Native: GNOpenCV.detect_blobs(rgba, w, h, min_area, max_area,
##         circ_min, circ_max, conv_min, conv_max, iner_min, iner_max,
##         draw_overlay) -> PackedByteArray (overlay image)
## Native: GNOpenCV.get_blob_data() -> PackedFloat32Array
##         [count, id0,x0,y0,r0,w0,h0, id1,x1,y1,r1,w1,h1, ...]

var _cv: RefCounted = null
var _cached_chop_data: GNChannelData = null


func _init() -> void:
	node_type = "blob_track"
	node_description = "Blob detection with persistent ID tracking. Requires gn_ext_opencv."
	time_dependent = true


func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, true, "Input image (usually thresholded)", "In")
	add_output("out", GNFamily.Type.IMG, "Overlay with tracked blobs drawn", "Out")
	add_output("data", GNFamily.Type.CHOP, "Tracking channels (id, cx, cy, area, width, height per blob)", "Data")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("min_area", 25.0, 1.0, 100000.0, 1.0,
		"Min Area", "Minimum blob area in pixels"))
	add_parameter(GNParameter.create_float("max_area", 50000.0, 1.0, 500000.0, 1.0,
		"Max Area", "Maximum blob area in pixels"))
	add_parameter(GNParameter.create_float("circ_min", 0.0, 0.0, 1.0, 0.01,
		"Circularity Min", "Minimum circularity (0 = any shape, 1 = perfect circle)"))
	add_parameter(GNParameter.create_float("circ_max", 1.0, 0.0, 1.0, 0.01,
		"Circularity Max", "Maximum circularity"))
	add_parameter(GNParameter.create_float("conv_min", 0.0, 0.0, 1.0, 0.01,
		"Convexity Min", "Minimum convexity ratio"))
	add_parameter(GNParameter.create_float("conv_max", 1.0, 0.0, 1.0, 0.01,
		"Convexity Max", "Maximum convexity ratio"))
	add_parameter(GNParameter.create_float("iner_min", 0.0, 0.0, 1.0, 0.01,
		"Inertia Min", "Minimum inertia ratio (elongation filter)"))
	add_parameter(GNParameter.create_float("iner_max", 1.0, 0.0, 1.0, 0.01,
		"Inertia Max", "Maximum inertia ratio"))
	add_parameter(GNParameter.create_float("max_track_dist", 50.0, 1.0, 1000.0, 1.0,
		"Max Track Dist", "Maximum pixel distance for ID persistence between frames"))
	add_parameter(GNParameter.create_int("max_lost_frames", 5, 1, 120,
		"Max Lost Frames", "Frames a blob can be missing before its ID is retired"))
	add_parameter(GNParameter.create_bool("draw_ids", true,
		"Draw IDs", "Draw numeric IDs on each blob"))
	add_parameter(GNParameter.create_bool("draw_bbox", false,
		"Draw BBox", "Draw bounding boxes around blobs"))
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

	# Configure tracker persistence
	_cv.set_blob_tracker_params(
		get_param_value("max_track_dist"),
		get_param_value("max_lost_frames"))

	var result: PackedByteArray = _cv.detect_blobs(
		rgba, w, h,
		get_param_value("min_area"), get_param_value("max_area"),
		get_param_value("circ_min"), get_param_value("circ_max"),
		get_param_value("conv_min"), get_param_value("conv_max"),
		get_param_value("iner_min"), get_param_value("iner_max"),
		get_param_value("draw_ids"), get_param_value("draw_bbox"))

	# Populate CHOP data from blob tracking results (skip if port 1 unconnected)
	if is_output_demanded(1):
		_pull_blob_chop()

	if not is_output_demanded(0) or result.is_empty():
		return out

	var img := GNOpenCVHelper.rgba_to_image(result, w, h)
	if img != null:
		out.set_image(img)
	return out


## Route multi-output: port 0 = IMG overlay, port 1 = CHOP tracking data.
func get_output_data(port_index: int) -> GNData:
	if port_index == 1:
		return _cached_chop_data
	return cached_output


func _pull_blob_chop() -> void:
	if _cached_chop_data == null:
		_cached_chop_data = GNChannelData.new()
	_cached_chop_data.channels.clear()

	if _cv == null:
		_cached_chop_data.set_single_value("count", 0.0)
		return

	var data: PackedFloat32Array = _cv.get_blob_data()
	if data.is_empty():
		_cached_chop_data.set_single_value("count", 0.0)
		return

	# Parse: [count, id0,cx0,cy0,r0,w0,h0, id1,...]
	var count: int = int(data[0])
	_cached_chop_data.set_single_value("count", float(count))
	var idx: int = 1
	for i in range(count):
		if idx + 6 > data.size():
			break
		var s := str(i)
		_cached_chop_data.set_single_value("id" + s, data[idx])
		_cached_chop_data.set_single_value("cx" + s, data[idx + 1])
		_cached_chop_data.set_single_value("cy" + s, data[idx + 2])
		_cached_chop_data.set_single_value("area" + s, data[idx + 3])
		_cached_chop_data.set_single_value("width" + s, data[idx + 4])
		_cached_chop_data.set_single_value("height" + s, data[idx + 5])
		idx += 6


func _ensure_cv() -> void:
	if _cv != null:
		return
	_cv = GNOpenCVHelper.create_instance()
	if _cv == null:
		GNLogger.error("BlobTrackIMG", "'%s': failed to instantiate GNOpenCV" % id)
