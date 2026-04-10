class_name ColorTrackIMG
extends GNImgBase
## Track a color range in HSV space — outputs a binary mask.
##
## Converts the input to HSV and applies an in-range filter centered on the
## target color.  The output mask is white where the color matches and black
## elsewhere.  Useful as input to BlobTrackIMG or ContourIMG.
##
## Requires GNOpenCV GDExtension.
##
## Native: GNOpenCV.color_range_mask(rgba, w, h, low_h, low_s, low_v,
##         high_h, high_s, high_v) -> PackedByteArray (mask)

var _cv: RefCounted = null
var _cached_chop_data: GNChannelData = null


func _init() -> void:
	node_type = "color_track"
	node_description = "HSV color-range tracking. Requires gn_ext_opencv."


func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, true, "Input image")
	add_output("out", GNFamily.Type.IMG, "Binary mask of matching pixels")
	add_output("data", GNFamily.Type.CHOP, "Tracking channels (cx, cy, area, pixel_count)")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_color("target_color",
		Color(1.0, 0.0, 0.0, 1.0),
		"Target Color", "Center color to track (converted to HSV internally)"))
	add_parameter(GNParameter.create_float("hue_range", 15.0, 0.0, 90.0, 1.0,
		"Hue Range", "Hue tolerance (+/-) in degrees (0-180 scale)"))
	add_parameter(GNParameter.create_float("sat_min", 50.0, 0.0, 255.0, 1.0,
		"Sat Min", "Minimum saturation"))
	add_parameter(GNParameter.create_float("sat_max", 255.0, 0.0, 255.0, 1.0,
		"Sat Max", "Maximum saturation"))
	add_parameter(GNParameter.create_float("val_min", 50.0, 0.0, 255.0, 1.0,
		"Val Min", "Minimum value (brightness)"))
	add_parameter(GNParameter.create_float("val_max", 255.0, 0.0, 255.0, 1.0,
		"Val Max", "Maximum value"))
	add_parameter(GNParameter.create_bool("invert", false,
		"Invert", "Invert the output mask"))
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

	# Convert target color to HSV range
	var tc: Color = get_param_value("target_color")
	var hue_range: float = get_param_value("hue_range")
	# Godot Color.h is 0..1, OpenCV HSV hue is 0..180
	var center_h: float = tc.h * 180.0
	var low_h: float = maxf(center_h - hue_range, 0.0)
	var high_h: float = minf(center_h + hue_range, 180.0)
	var low_s: float = get_param_value("sat_min")
	var high_s: float = get_param_value("sat_max")
	var low_v: float = get_param_value("val_min")
	var high_v: float = get_param_value("val_max")

	var result: PackedByteArray = _cv.color_range_mask(
		rgba, w, h, low_h, low_s, low_v, high_h, high_s, high_v)

	# Populate CHOP data from color tracking (skip if port 1 unconnected)
	if is_output_demanded(1):
		_pull_color_chop()

	if not is_output_demanded(0) or result.is_empty():
		return out

	# Invert if requested (swap 0↔255 in all RGBA channels)
	if get_param_value("invert"):
		for i in range(result.size()):
			# Skip alpha channel (every 4th byte), keep it opaque
			if (i + 1) % 4 != 0:
				result[i] = 255 - result[i]

	var img := GNOpenCVHelper.rgba_to_image(result, w, h)
	if img != null:
		out.set_image(img)
	return out


## Route multi-output: port 0 = IMG mask, port 1 = CHOP tracking data.
func get_output_data(port_index: int) -> GNData:
	if port_index == 1:
		return _cached_chop_data
	return cached_output


func _pull_color_chop() -> void:
	if _cached_chop_data == null:
		_cached_chop_data = GNChannelData.new()
	_cached_chop_data.channels.clear()

	if _cv == null:
		_cached_chop_data.set_single_value("pixel_count", 0.0)
		return

	# get_color_track_data() -> PackedFloat32Array [cx, cy, area, pixel_count]
	var data: PackedFloat32Array = _cv.get_color_track_data()
	if data.size() >= 4:
		_cached_chop_data.set_single_value("cx", data[0])
		_cached_chop_data.set_single_value("cy", data[1])
		_cached_chop_data.set_single_value("area", data[2])
		_cached_chop_data.set_single_value("pixel_count", data[3])
	else:
		_cached_chop_data.set_single_value("cx", 0.0)
		_cached_chop_data.set_single_value("cy", 0.0)
		_cached_chop_data.set_single_value("area", 0.0)
		_cached_chop_data.set_single_value("pixel_count", 0.0)


func _ensure_cv() -> void:
	if _cv != null:
		return
	_cv = GNOpenCVHelper.create_instance()
	if _cv == null:
		GNLogger.error("ColorTrackIMG", "'%s': failed to instantiate GNOpenCV" % id)
