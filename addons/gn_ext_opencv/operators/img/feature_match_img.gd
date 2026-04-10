class_name FeatureMatchIMG
extends GNImgBase
## Keypoint detection + descriptor matching between two images.
##
## Detects features in both inputs using ORB, SIFT, or AKAZE, matches
## descriptors, and draws match lines on a side-by-side composite.
## Useful for image registration, panorama stitching, and object recognition.
##
## Requires GNOpenCV GDExtension.
##
## Native: GNOpenCV.detect_features(rgba, w, h, method,
##         max_features) -> PackedFloat32Array (keypoints)
## Native: GNOpenCV.match_features(rgba_a, w_a, h_a, rgba_b, w_b, h_b,
##         method, max_features, max_dist,
##         color_r, color_g, color_b,
##         thickness) -> PackedByteArray (composite overlay)

var _cv: RefCounted = null


func _init() -> void:
	node_type = "feature_match"
	node_description = "Keypoint detection + descriptor matching. Requires gn_ext_opencv."


func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])


func _init_ports() -> void:
	add_input("in_a", GNFamily.Type.IMG, true, "First image")
	add_input("in_b", GNFamily.Type.IMG, true, "Second image")
	add_output("out", GNFamily.Type.IMG, "Side-by-side match overlay")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("method",
		PackedStringArray(["ORB", "SIFT", "AKAZE"]), 0,
		"Method", "Feature detection algorithm"))
	add_parameter(GNParameter.create_int("max_features", 500, 10, 10000,
		"Max Features", "Maximum number of keypoints to detect"))
	add_parameter(GNParameter.create_float("max_dist", 50.0, 1.0, 500.0, 1.0,
		"Max Distance", "Maximum descriptor distance to accept a match"))
	add_parameter(GNParameter.create_color("color", Color(0.0, 1.0, 0.0, 1.0),
		"Color", "Match line drawing color"))
	add_parameter(GNParameter.create_int("thickness", 1, 1, 5,
		"Thickness", "Match line thickness"))
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

	var src_a := _get_input_img(inputs, 0)
	var src_b := _get_input_img(inputs, 1)
	if src_a == null or src_a.image == null or src_b == null or src_b.image == null:
		return out

	_ensure_cv()
	if _cv == null:
		return out

	var conv_a := GNOpenCVHelper.image_to_rgba(src_a.image)
	var conv_b := GNOpenCVHelper.image_to_rgba(src_b.image)
	var rgba_a: PackedByteArray = conv_a[0]
	var wa: int = conv_a[1]
	var ha: int = conv_a[2]
	var rgba_b: PackedByteArray = conv_b[0]
	var wb: int = conv_b[1]
	var hb: int = conv_b[2]
	if rgba_a.is_empty() or rgba_b.is_empty():
		return out

	var c: Color = get_param_value("color")

	var result: PackedByteArray = _cv.match_features(
		rgba_a, wa, ha, rgba_b, wb, hb,
		get_param_value("method"),
		get_param_value("max_features"),
		get_param_value("max_dist"),
		c.r, c.g, c.b,
		get_param_value("thickness"))
	if result.is_empty():
		return out

	# Result image is side-by-side: (wa + wb) x max(ha, hb)
	var out_w: int = wa + wb
	var out_h: int = maxi(ha, hb)
	var img := GNOpenCVHelper.rgba_to_image(result, out_w, out_h)
	if img != null:
		out.set_image(img)
	return out


func _ensure_cv() -> void:
	if _cv != null:
		return
	_cv = GNOpenCVHelper.create_instance()
	if _cv == null:
		GNLogger.error("FeatureMatchIMG", "'%s': failed to instantiate GNOpenCV" % id)
