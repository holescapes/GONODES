extends Node
## Hand-written tests for gn_ext_opencv operators.
## Covers port structure, parameter defaults, multi-output routing,
## and cook behavior (both null-input and with valid image input).

var _network: GNNetwork
var _engine: GNCookEngine


func before_each() -> void:
	_network = GNNetwork.new()
	_engine = GNCookEngine.new()
	_engine.network = _network
	_engine.cooking_enabled = false
	_engine.elapsed_time = 1.0
	_engine.frame_count = 60
	_engine.current_delta = 1.0 / 60.0
	add_child(_engine)


func after_each() -> void:
	if is_instance_valid(_engine):
		remove_child(_engine)
		_engine.queue_free()


func _make_node(node: GNNode, id: String) -> GNNode:
	node.initialize(id)
	_network.add_node(node)
	_engine.add_child(node)
	return node


func _cook_no_input(node: GNNode) -> GNData:
	var inputs: Array[GNData] = []
	node.execute_cook(inputs, _engine.frame_count)
	return node.cached_output


func _cook_with(node: GNNode, inputs: Array[GNData]) -> GNData:
	node.execute_cook(inputs, _engine.frame_count)
	return node.cached_output


func _make_test_image_data() -> GNImageData:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 1.0))
	var data := GNImageData.new()
	data.set_image(img)
	return data


# ═══════════════════════════════════════════════════════════════════════════════
# ThresholdIMG — single-output IMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_threshold_instantiate() -> void:
	var node := _make_node(ThresholdIMG.new(), "thresh1")
	GNTestAssert.assert_not_null(node, "ThresholdIMG created")
	GNTestAssert.assert_eq(node.node_type, "threshold", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.IMG, "family is IMG")

func test_threshold_ports() -> void:
	var node := _make_node(ThresholdIMG.new(), "thresh2")
	GNTestAssert.assert_eq(node.input_ports.size(), 1, "1 input port")
	GNTestAssert.assert_eq(node.output_ports.size(), 1, "1 output port")
	GNTestAssert.assert_eq(node.input_ports[0].family, GNFamily.Type.IMG, "input is IMG")
	GNTestAssert.assert_eq(node.output_ports[0].family, GNFamily.Type.IMG, "output is IMG")

func test_threshold_parameters() -> void:
	var node := _make_node(ThresholdIMG.new(), "thresh3")
	GNTestAssert.assert_true(node.parameters.has("method"), "has method")
	GNTestAssert.assert_true(node.parameters.has("threshold"), "has threshold")
	GNTestAssert.assert_true(node.parameters.has("max_value"), "has max_value")
	GNTestAssert.assert_true(node.parameters.has("block_size"), "has block_size")
	GNTestAssert.assert_true(node.parameters.has("active"), "has active")
	GNTestAssert.assert_eq(node.get_param_value("threshold"), 128.0, "default threshold")
	GNTestAssert.assert_eq(node.get_param_value("max_value"), 255.0, "default max_value")

func test_threshold_cook_null() -> void:
	var node := _make_node(ThresholdIMG.new(), "thresh4")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "ThresholdIMG cook-null no crash")

func test_threshold_cook_with_image() -> void:
	var node := _make_node(ThresholdIMG.new(), "thresh5")
	var img_data := _make_test_image_data()
	var inputs: Array[GNData] = [img_data]
	var out := _cook_with(node, inputs)
	GNTestAssert.assert_not_null(out, "ThresholdIMG produces output with input")

func test_threshold_description() -> void:
	var node := _make_node(ThresholdIMG.new(), "thresh6")
	GNTestAssert.assert_true(not node.node_description.is_empty(), "has description")


# ═══════════════════════════════════════════════════════════════════════════════
# MorphIMG — single-output IMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_morph_instantiate() -> void:
	var node := _make_node(MorphIMG.new(), "morph1")
	GNTestAssert.assert_not_null(node, "MorphIMG created")
	GNTestAssert.assert_eq(node.node_type, "morph", "node_type")

func test_morph_ports() -> void:
	var node := _make_node(MorphIMG.new(), "morph2")
	GNTestAssert.assert_eq(node.input_ports.size(), 1, "1 input")
	GNTestAssert.assert_eq(node.output_ports.size(), 1, "1 output")

func test_morph_cook_null() -> void:
	var node := _make_node(MorphIMG.new(), "morph3")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "MorphIMG cook-null no crash")


# ═══════════════════════════════════════════════════════════════════════════════
# BlobTrackIMG — multi-output: IMG + CHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_blob_track_instantiate() -> void:
	var node := _make_node(BlobTrackIMG.new(), "blob1")
	GNTestAssert.assert_not_null(node, "BlobTrackIMG created")
	GNTestAssert.assert_eq(node.node_type, "blob_track", "node_type")

func test_blob_track_ports() -> void:
	var node := _make_node(BlobTrackIMG.new(), "blob2")
	GNTestAssert.assert_eq(node.input_ports.size(), 1, "1 input")
	GNTestAssert.assert_eq(node.output_ports.size(), 2, "2 outputs")
	GNTestAssert.assert_eq(node.output_ports[0].family, GNFamily.Type.IMG, "port 0 is IMG")
	GNTestAssert.assert_eq(node.output_ports[1].family, GNFamily.Type.CHOP, "port 1 is CHOP")

func test_blob_track_parameters() -> void:
	var node := _make_node(BlobTrackIMG.new(), "blob3")
	GNTestAssert.assert_true(node.parameters.has("min_area"), "has min_area")
	GNTestAssert.assert_true(node.parameters.has("max_area"), "has max_area")
	GNTestAssert.assert_true(node.parameters.has("draw_ids"), "has draw_ids")
	GNTestAssert.assert_true(node.parameters.has("draw_bbox"), "has draw_bbox")
	GNTestAssert.assert_true(node.parameters.has("active"), "has active")

func test_blob_track_cook_null() -> void:
	var node := _make_node(BlobTrackIMG.new(), "blob4")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "BlobTrackIMG cook-null no crash")

func test_blob_track_time_dependent() -> void:
	var node := _make_node(BlobTrackIMG.new(), "blob5")
	GNTestAssert.assert_true(node.time_dependent, "blob tracker is time_dependent")


# ═══════════════════════════════════════════════════════════════════════════════
# BackgroundSubtractIMG — single-output IMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_bg_subtract_instantiate() -> void:
	var node := _make_node(BackgroundSubtractIMG.new(), "bgsub1")
	GNTestAssert.assert_not_null(node, "BackgroundSubtractIMG created")
	GNTestAssert.assert_eq(node.node_type, "bg_subtract", "node_type")

func test_bg_subtract_cook_null() -> void:
	var node := _make_node(BackgroundSubtractIMG.new(), "bgsub2")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "BackgroundSubtractIMG cook-null no crash")


# ═══════════════════════════════════════════════════════════════════════════════
# ContourIMG — multi-output: IMG + DAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_contour_instantiate() -> void:
	var node := _make_node(ContourIMG.new(), "cont1")
	GNTestAssert.assert_not_null(node, "ContourIMG created")
	GNTestAssert.assert_eq(node.node_type, "contour", "node_type")

func test_contour_ports() -> void:
	var node := _make_node(ContourIMG.new(), "cont2")
	GNTestAssert.assert_eq(node.output_ports.size(), 2, "2 outputs")
	GNTestAssert.assert_eq(node.output_ports[0].family, GNFamily.Type.IMG, "port 0 is IMG")
	GNTestAssert.assert_eq(node.output_ports[1].family, GNFamily.Type.DAT, "port 1 is DAT")

func test_contour_parameters() -> void:
	var node := _make_node(ContourIMG.new(), "cont3")
	GNTestAssert.assert_true(node.parameters.has("mode"), "has mode")
	GNTestAssert.assert_true(node.parameters.has("method"), "has method")
	GNTestAssert.assert_true(node.parameters.has("min_area"), "has min_area")
	GNTestAssert.assert_true(node.parameters.has("color"), "has color")
	GNTestAssert.assert_true(node.parameters.has("thickness"), "has thickness")
	GNTestAssert.assert_true(node.parameters.has("draw_all"), "has draw_all")

func test_contour_cook_null() -> void:
	var node := _make_node(ContourIMG.new(), "cont4")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "ContourIMG cook-null no crash")


# ═══════════════════════════════════════════════════════════════════════════════
# OpticalFlowIMG — single-output IMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_optical_flow_instantiate() -> void:
	var node := _make_node(OpticalFlowIMG.new(), "oflow1")
	GNTestAssert.assert_not_null(node, "OpticalFlowIMG created")
	GNTestAssert.assert_eq(node.node_type, "optical_flow", "node_type")

func test_optical_flow_cook_null() -> void:
	var node := _make_node(OpticalFlowIMG.new(), "oflow2")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "OpticalFlowIMG cook-null no crash")


# ═══════════════════════════════════════════════════════════════════════════════
# ColorTrackIMG — multi-output: IMG + CHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_color_track_instantiate() -> void:
	var node := _make_node(ColorTrackIMG.new(), "ctrack1")
	GNTestAssert.assert_not_null(node, "ColorTrackIMG created")
	GNTestAssert.assert_eq(node.node_type, "color_track", "node_type")

func test_color_track_ports() -> void:
	var node := _make_node(ColorTrackIMG.new(), "ctrack2")
	GNTestAssert.assert_eq(node.output_ports.size(), 2, "2 outputs")
	GNTestAssert.assert_eq(node.output_ports[0].family, GNFamily.Type.IMG, "port 0 is IMG")
	GNTestAssert.assert_eq(node.output_ports[1].family, GNFamily.Type.CHOP, "port 1 is CHOP")

func test_color_track_cook_null() -> void:
	var node := _make_node(ColorTrackIMG.new(), "ctrack3")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "ColorTrackIMG cook-null no crash")


# ═══════════════════════════════════════════════════════════════════════════════
# ObjectTrackIMG — multi-output: IMG + CHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_object_track_instantiate() -> void:
	var node := _make_node(ObjectTrackIMG.new(), "otrack1")
	GNTestAssert.assert_not_null(node, "ObjectTrackIMG created")
	GNTestAssert.assert_eq(node.node_type, "object_track", "node_type")

func test_object_track_ports() -> void:
	var node := _make_node(ObjectTrackIMG.new(), "otrack2")
	GNTestAssert.assert_eq(node.output_ports.size(), 2, "2 outputs")
	GNTestAssert.assert_eq(node.output_ports[0].family, GNFamily.Type.IMG, "port 0 is IMG")
	GNTestAssert.assert_eq(node.output_ports[1].family, GNFamily.Type.CHOP, "port 1 is CHOP")

func test_object_track_cook_null() -> void:
	var node := _make_node(ObjectTrackIMG.new(), "otrack3")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "ObjectTrackIMG cook-null no crash")


# ═══════════════════════════════════════════════════════════════════════════════
# HoughLinesIMG — multi-output: IMG + DAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_hough_lines_instantiate() -> void:
	var node := _make_node(HoughLinesIMG.new(), "hlines1")
	GNTestAssert.assert_not_null(node, "HoughLinesIMG created")
	GNTestAssert.assert_eq(node.node_type, "hough_lines", "node_type")

func test_hough_lines_ports() -> void:
	var node := _make_node(HoughLinesIMG.new(), "hlines2")
	GNTestAssert.assert_eq(node.output_ports.size(), 2, "2 outputs")
	GNTestAssert.assert_eq(node.output_ports[0].family, GNFamily.Type.IMG, "port 0 is IMG")
	GNTestAssert.assert_eq(node.output_ports[1].family, GNFamily.Type.DAT, "port 1 is DAT")

func test_hough_lines_cook_null() -> void:
	var node := _make_node(HoughLinesIMG.new(), "hlines3")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "HoughLinesIMG cook-null no crash")


# ═══════════════════════════════════════════════════════════════════════════════
# HoughCirclesIMG — multi-output: IMG + DAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_hough_circles_instantiate() -> void:
	var node := _make_node(HoughCirclesIMG.new(), "hcirc1")
	GNTestAssert.assert_not_null(node, "HoughCirclesIMG created")
	GNTestAssert.assert_eq(node.node_type, "hough_circles", "node_type")

func test_hough_circles_ports() -> void:
	var node := _make_node(HoughCirclesIMG.new(), "hcirc2")
	GNTestAssert.assert_eq(node.output_ports.size(), 2, "2 outputs")
	GNTestAssert.assert_eq(node.output_ports[0].family, GNFamily.Type.IMG, "port 0 is IMG")
	GNTestAssert.assert_eq(node.output_ports[1].family, GNFamily.Type.DAT, "port 1 is DAT")

func test_hough_circles_cook_null() -> void:
	var node := _make_node(HoughCirclesIMG.new(), "hcirc3")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "HoughCirclesIMG cook-null no crash")


# ═══════════════════════════════════════════════════════════════════════════════
# ConvolveIMG — single-output IMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_convolve_instantiate() -> void:
	var node := _make_node(ConvolveIMG.new(), "conv1")
	GNTestAssert.assert_not_null(node, "ConvolveIMG created")
	GNTestAssert.assert_eq(node.node_type, "convolve", "node_type")

func test_convolve_cook_null() -> void:
	var node := _make_node(ConvolveIMG.new(), "conv2")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "ConvolveIMG cook-null no crash")


# ═══════════════════════════════════════════════════════════════════════════════
# CameraCalibDAT — DAT output
# ═══════════════════════════════════════════════════════════════════════════════

func test_camera_calib_instantiate() -> void:
	var node := _make_node(CameraCalibDAT.new(), "calib1")
	GNTestAssert.assert_not_null(node, "CameraCalibDAT created")
	GNTestAssert.assert_eq(node.node_type, "camera_calib", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.DAT, "family is DAT")

func test_camera_calib_cook_null() -> void:
	var node := _make_node(CameraCalibDAT.new(), "calib2")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "CameraCalibDAT cook-null no crash")


# ═══════════════════════════════════════════════════════════════════════════════
# CameraUndistortIMG — single-output IMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_camera_undistort_instantiate() -> void:
	var node := _make_node(CameraUndistortIMG.new(), "undist1")
	GNTestAssert.assert_not_null(node, "CameraUndistortIMG created")
	GNTestAssert.assert_eq(node.node_type, "camera_undistort", "node_type")

func test_camera_undistort_cook_null() -> void:
	var node := _make_node(CameraUndistortIMG.new(), "undist2")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "CameraUndistortIMG cook-null no crash")


# ═══════════════════════════════════════════════════════════════════════════════
# PerspectiveWarpIMG — single-output IMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_perspective_warp_instantiate() -> void:
	var node := _make_node(PerspectiveWarpIMG.new(), "pwarp1")
	GNTestAssert.assert_not_null(node, "PerspectiveWarpIMG created")
	GNTestAssert.assert_eq(node.node_type, "perspective_warp", "node_type")

func test_perspective_warp_cook_null() -> void:
	var node := _make_node(PerspectiveWarpIMG.new(), "pwarp2")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "PerspectiveWarpIMG cook-null no crash")


# ═══════════════════════════════════════════════════════════════════════════════
# ArucoDetectIMG — multi-output: IMG + DAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_aruco_detect_instantiate() -> void:
	var node := _make_node(ArucoDetectIMG.new(), "aruco1")
	GNTestAssert.assert_not_null(node, "ArucoDetectIMG created")
	GNTestAssert.assert_eq(node.node_type, "aruco_detect", "node_type")

func test_aruco_detect_ports() -> void:
	var node := _make_node(ArucoDetectIMG.new(), "aruco2")
	GNTestAssert.assert_eq(node.output_ports.size(), 2, "2 outputs")
	GNTestAssert.assert_eq(node.output_ports[0].family, GNFamily.Type.IMG, "port 0 is IMG")
	GNTestAssert.assert_eq(node.output_ports[1].family, GNFamily.Type.DAT, "port 1 is DAT")

func test_aruco_detect_cook_null() -> void:
	var node := _make_node(ArucoDetectIMG.new(), "aruco3")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "ArucoDetectIMG cook-null no crash")


# ═══════════════════════════════════════════════════════════════════════════════
# ArucoPoseDAT — DAT output
# ═══════════════════════════════════════════════════════════════════════════════

func test_aruco_pose_instantiate() -> void:
	var node := _make_node(ArucoPoseDAT.new(), "apose1")
	GNTestAssert.assert_not_null(node, "ArucoPoseDAT created")
	GNTestAssert.assert_eq(node.node_type, "aruco_pose", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.DAT, "family is DAT")

func test_aruco_pose_cook_null() -> void:
	var node := _make_node(ArucoPoseDAT.new(), "apose2")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "ArucoPoseDAT cook-null no crash")


# ═══════════════════════════════════════════════════════════════════════════════
# QRCodeDAT — DAT output
# ═══════════════════════════════════════════════════════════════════════════════

func test_qrcode_instantiate() -> void:
	var node := _make_node(QRCodeDAT.new(), "qr1")
	GNTestAssert.assert_not_null(node, "QRCodeDAT created")
	GNTestAssert.assert_eq(node.node_type, "qrcode", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.DAT, "family is DAT")

func test_qrcode_ports() -> void:
	var node := _make_node(QRCodeDAT.new(), "qr2")
	GNTestAssert.assert_eq(node.input_ports.size(), 1, "1 input")
	GNTestAssert.assert_eq(node.input_ports[0].family, GNFamily.Type.IMG, "input is IMG")
	GNTestAssert.assert_eq(node.output_ports.size(), 1, "1 output")
	GNTestAssert.assert_eq(node.output_ports[0].family, GNFamily.Type.DAT, "output is DAT")

func test_qrcode_cook_null() -> void:
	var node := _make_node(QRCodeDAT.new(), "qr3")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "QRCodeDAT cook-null no crash")


# ═══════════════════════════════════════════════════════════════════════════════
# FeatureMatchIMG — single-output IMG (2 inputs)
# ═══════════════════════════════════════════════════════════════════════════════

func test_feature_match_instantiate() -> void:
	var node := _make_node(FeatureMatchIMG.new(), "fmatch1")
	GNTestAssert.assert_not_null(node, "FeatureMatchIMG created")
	GNTestAssert.assert_eq(node.node_type, "feature_match", "node_type")

func test_feature_match_ports() -> void:
	var node := _make_node(FeatureMatchIMG.new(), "fmatch2")
	GNTestAssert.assert_eq(node.input_ports.size(), 2, "2 inputs (left + right)")

func test_feature_match_cook_null() -> void:
	var node := _make_node(FeatureMatchIMG.new(), "fmatch3")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "FeatureMatchIMG cook-null no crash")


# ═══════════════════════════════════════════════════════════════════════════════
# StereoDepthIMG — single-output IMG (2 inputs)
# ═══════════════════════════════════════════════════════════════════════════════

func test_stereo_depth_instantiate() -> void:
	var node := _make_node(StereoDepthIMG.new(), "stereo1")
	GNTestAssert.assert_not_null(node, "StereoDepthIMG created")
	GNTestAssert.assert_eq(node.node_type, "stereo_depth", "node_type")

func test_stereo_depth_ports() -> void:
	var node := _make_node(StereoDepthIMG.new(), "stereo2")
	GNTestAssert.assert_eq(node.input_ports.size(), 2, "2 inputs (left + right)")

func test_stereo_depth_cook_null() -> void:
	var node := _make_node(StereoDepthIMG.new(), "stereo3")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "StereoDepthIMG cook-null no crash")


# ═══════════════════════════════════════════════════════════════════════════════
# DrawOverlayIMG — single-output IMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_draw_overlay_instantiate() -> void:
	var node := _make_node(DrawOverlayIMG.new(), "draw1")
	GNTestAssert.assert_not_null(node, "DrawOverlayIMG created")
	GNTestAssert.assert_eq(node.node_type, "draw_overlay", "node_type")

func test_draw_overlay_cook_null() -> void:
	var node := _make_node(DrawOverlayIMG.new(), "draw2")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "DrawOverlayIMG cook-null no crash")
