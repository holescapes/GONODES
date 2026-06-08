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
