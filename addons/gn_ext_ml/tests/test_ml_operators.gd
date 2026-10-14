extends Node
## Tests for gn_ext_ml operators.

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


# ═══════════════════════════════════════════════════════════════════════════════
# DepthEstimateIMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_depth_estimate_img_instantiate() -> void:
	var node := _make_node(DepthEstimateIMG.new(), "de1")
	GNTestAssert.assert_not_null(node, "DepthEstimateIMG created")


# ═══════════════════════════════════════════════════════════════════════════════
# SegmentationIMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_segmentation_img_instantiate() -> void:
	var node := _make_node(SegmentationIMG.new(), "seg1")
	GNTestAssert.assert_not_null(node, "SegmentationIMG created")


# ═══════════════════════════════════════════════════════════════════════════════
# StyleTransferIMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_style_transfer_img_instantiate() -> void:
	var node := _make_node(StyleTransferIMG.new(), "st1")
	GNTestAssert.assert_not_null(node, "StyleTransferIMG created")


# ═══════════════════════════════════════════════════════════════════════════════
# FaceDetectCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_face_detect_chop_instantiate() -> void:
	var node := _make_node(FaceDetectCHOP.new(), "facedetect1")
	GNTestAssert.assert_not_null(node, "FaceDetectCHOP created")


# ═══════════════════════════════════════════════════════════════════════════════
# HandDetectCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_hand_detect_chop_instantiate() -> void:
	var node := _make_node(HandDetectCHOP.new(), "handdetect1")
	GNTestAssert.assert_not_null(node, "HandDetectCHOP created")


# ═══════════════════════════════════════════════════════════════════════════════
# PoseDetectCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_pose_detect_chop_instantiate() -> void:
	var node := _make_node(PoseDetectCHOP.new(), "posedetect1")
	GNTestAssert.assert_not_null(node, "PoseDetectCHOP created")


# ═══════════════════════════════════════════════════════════════════════════════
# ObjectDetectDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_object_detect_dat_instantiate() -> void:
	var node := _make_node(ObjectDetectDAT.new(), "objdet1")
	GNTestAssert.assert_not_null(node, "ObjectDetectDAT created")


func test_ml_img_operators_instantiate() -> void:
	GNTestAssert.assert_not_null(_make_node(DepthEstimateIMG.new(), "de_ml"), "depth created")
	GNTestAssert.assert_not_null(_make_node(SegmentationIMG.new(), "seg_ml"), "segmentation created")
	GNTestAssert.assert_not_null(_make_node(StyleTransferIMG.new(), "st_ml"), "style created")


func test_ml_session_missing_model_sets_error() -> void:
	var session := GNMlSession.new()
	var loaded := session.begin(0, "res://addons/gn_ext_ml/models/does_not_exist.onnx", "")
	GNTestAssert.assert_false(loaded, "a missing model does not load")
	GNTestAssert.assert_false(session.last_error.is_empty(), "a missing model sets last_error")


func test_ml_detector_input_is_img() -> void:
	var pose := _make_node(PoseDetectCHOP.new(), "pose_img")
	var hand := _make_node(HandDetectCHOP.new(), "hand_img")
	var face := _make_node(FaceDetectCHOP.new(), "face_img")
	var objects := _make_node(ObjectDetectDAT.new(), "obj_img")
	GNTestAssert.assert_eq(pose.get_input_port(0).family, GNFamily.Type.IMG, "pose input is IMG")
	GNTestAssert.assert_eq(hand.get_input_port(0).family, GNFamily.Type.IMG, "hand input is IMG")
	GNTestAssert.assert_eq(face.get_input_port(0).family, GNFamily.Type.IMG, "face input is IMG")
	GNTestAssert.assert_eq(objects.get_input_port(0).family, GNFamily.Type.IMG, "object detect input is IMG")


func test_ml_style_mosaic_runs() -> void:
	var session := GNMlSession.new()
	var path := StyleTransferIMG.model_for_style(0, "")
	var loaded := session.begin(0, path, "")
	GNTestAssert.assert_true(loaded, session.last_error)
	GNTestAssert.assert_eq(session.image_size(0, 0), Vector2i(224, 224), "mosaic input is 224")
	var image := Image.create(32, 32, false, Image.FORMAT_RGB8)
	image.fill(Color(0.4, 0.2, 0.1))
	var ran := session.run_image(image, StyleTransferIMG.MODEL_W, StyleTransferIMG.MODEL_H)
	GNTestAssert.assert_true(ran, session.last_error)
	GNTestAssert.assert_false(session.output_names().is_empty(), "style model has an output")


func test_ml_style_model_path() -> void:
	GNTestAssert.assert_eq(
		StyleTransferIMG.model_for_style(0, "custom.onnx"),
		"res://addons/gn_ext_ml/models/style_mosaic.onnx",
		"style 0 is mosaic")
	GNTestAssert.assert_eq(
		StyleTransferIMG.model_for_style(4, "custom.onnx"),
		"res://addons/gn_ext_ml/models/style_pointilism.onnx",
		"style 4 is pointillism")
	GNTestAssert.assert_eq(
		StyleTransferIMG.model_for_style(5, "res://models/mine.onnx"),
		"res://models/mine.onnx",
		"style 5 is the custom path")
