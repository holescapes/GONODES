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


func _cook_no_input(node: GNNode) -> GNData:
	var inputs: Array[GNData] = []
	node.execute_cook(inputs, _engine.frame_count)
	return node.cached_output


# ═══════════════════════════════════════════════════════════════════════════════
# DepthSensorIMG — Multi-output: IMG + CHOP (skeleton) + CHOP (hands) + SOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_depth_sensor_img_instantiate() -> void:
	var node := _make_node(DepthSensorIMG.new(), "ds1")
	GNTestAssert.assert_not_null(node, "DepthSensorIMG created")
	GNTestAssert.assert_eq(node.node_type, "depthsensor", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.IMG, "family is IMG")

func test_depth_sensor_img_ports() -> void:
	var node := _make_node(DepthSensorIMG.new(), "ds2")
	GNTestAssert.assert_eq(node.input_ports.size(), 0, "no input ports")
	GNTestAssert.assert_eq(node.output_ports.size(), 4, "4 output ports")
	GNTestAssert.assert_eq(node.output_ports[0].family, GNFamily.Type.IMG, "port 0 is IMG")
	GNTestAssert.assert_eq(node.output_ports[1].family, GNFamily.Type.CHOP, "port 1 is CHOP")
	GNTestAssert.assert_eq(node.output_ports[2].family, GNFamily.Type.CHOP, "port 2 is CHOP")
	GNTestAssert.assert_eq(node.output_ports[3].family, GNFamily.Type.SOP, "port 3 is SOP")

func test_depth_sensor_img_parameters() -> void:
	var node := _make_node(DepthSensorIMG.new(), "ds3")
	GNTestAssert.assert_true(node.parameters.has("device"), "has device param")
	GNTestAssert.assert_true(node.parameters.has("stream"), "has stream param")
	GNTestAssert.assert_true(node.parameters.has("max_depth_mm"), "has max_depth_mm")
	GNTestAssert.assert_true(node.parameters.has("max_bodies"), "has max_bodies")
	GNTestAssert.assert_true(node.parameters.has("min_confidence"), "has min_confidence")
	GNTestAssert.assert_true(node.parameters.has("point_skip"), "has point_skip")
	GNTestAssert.assert_true(node.parameters.has("active"), "has active param")
	GNTestAssert.assert_true(node.parameters.has("timeout_ms"), "has timeout_ms")

func test_depth_sensor_img_cook_null() -> void:
	var node := _make_node(DepthSensorIMG.new(), "ds4")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "DepthSensorIMG cook-null no crash")

func test_depth_sensor_img_time_dependent() -> void:
	var node := _make_node(DepthSensorIMG.new(), "ds5")
	GNTestAssert.assert_true(node.time_dependent, "time_dependent is true")

func test_depth_sensor_img_description() -> void:
	var node := _make_node(DepthSensorIMG.new(), "ds6")
	GNTestAssert.assert_true(not node.node_description.is_empty(), "has node_description")

func test_depth_sensor_img_param_defaults() -> void:
	var node := _make_node(DepthSensorIMG.new(), "ds7")
	GNTestAssert.assert_eq(node.get_param_value("stream"), 0, "default stream is Depth (0)")
	GNTestAssert.assert_eq(node.get_param_value("max_depth_mm"), 5000, "default max_depth_mm")
	GNTestAssert.assert_eq(node.get_param_value("max_bodies"), 6, "default max_bodies")
	GNTestAssert.assert_eq(node.get_param_value("active"), true, "default active is true")
	GNTestAssert.assert_eq(node.get_param_value("point_skip"), 1, "default point_skip is 1")


# ═══════════════════════════════════════════════════════════════════════════════
# DepthSensorDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_depth_sensor_dat_instantiate() -> void:
	var node := _make_node(DepthSensorDAT.new(), "depth1")
	GNTestAssert.assert_not_null(node, "DepthSensorDAT created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.DAT, "family is DAT")

func test_depth_sensor_dat_cook_null() -> void:
	var node := _make_node(DepthSensorDAT.new(), "depth2")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "DepthSensorDAT cook-null no crash")
