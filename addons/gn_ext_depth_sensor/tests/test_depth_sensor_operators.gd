extends Node
## Tests for gn_ext_depth_sensor operators.

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
# DepthSensorTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_depth_sensor_top_instantiate() -> void:
	var node := _make_node(DepthSensorTOP.new(), "ds1")
	GNTestAssert.assert_not_null(node, "DepthSensorTOP created")


# ═══════════════════════════════════════════════════════════════════════════════
# DepthPointCloudSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_depthpointcloud_sop_instantiate() -> void:
	var node := _make_node(DepthPointCloudSOP.new(), "dpc1")
	GNTestAssert.assert_not_null(node, "DepthPointCloudSOP created")


# ═══════════════════════════════════════════════════════════════════════════════
# DepthHandCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_depth_hand_chop_instantiate() -> void:
	var node := _make_node(DepthHandCHOP.new(), "depthhand1")
	GNTestAssert.assert_not_null(node, "DepthHandCHOP created")


# ═══════════════════════════════════════════════════════════════════════════════
# DepthSkeletonCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_depth_skeleton_chop_instantiate() -> void:
	var node := _make_node(DepthSkeletonCHOP.new(), "depthskeleton1")
	GNTestAssert.assert_not_null(node, "DepthSkeletonCHOP created")


# ═══════════════════════════════════════════════════════════════════════════════
# DepthSensorDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_depth_sensor_dat_instantiate() -> void:
	var node := _make_node(DepthSensorDAT.new(), "depth1")
	GNTestAssert.assert_not_null(node, "DepthSensorDAT created")
