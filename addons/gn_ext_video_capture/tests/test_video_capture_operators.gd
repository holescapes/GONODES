extends Node
## Tests for gn_ext_video_capture operators.

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
# VideoDeviceInIMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_video_device_in_img_instantiate() -> void:
	var node := _make_node(VideoDeviceInIMG.new(), "vdevice1")
	GNTestAssert.assert_not_null(node, "VideoDeviceInIMG created")
	GNTestAssert.assert_eq(node.node_type, "videodeviceinimg", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.IMG, "family is IMG")

func test_video_device_in_img_ports() -> void:
	var node := _make_node(VideoDeviceInIMG.new(), "vdevice2")
	GNTestAssert.assert_eq(node.input_ports.size(), 0, "no inputs")
	GNTestAssert.assert_eq(node.output_ports.size(), 1, "1 output")
	GNTestAssert.assert_eq(node.output_ports[0].family, GNFamily.Type.IMG, "output is IMG")

func test_video_device_in_img_parameters() -> void:
	var node := _make_node(VideoDeviceInIMG.new(), "vdevice3")
	GNTestAssert.assert_true(node.parameters.has("device_index"), "has device_index")
	GNTestAssert.assert_true(node.parameters.has("resolution"), "has resolution")
	GNTestAssert.assert_true(node.parameters.has("fps"), "has fps")
	GNTestAssert.assert_true(node.parameters.has("active"), "has active")

func test_video_device_in_img_param_defaults() -> void:
	var node := _make_node(VideoDeviceInIMG.new(), "vdevice4")
	GNTestAssert.assert_eq(node.get_param_value("device_index"), 0, "default device_index is 0")
	GNTestAssert.assert_eq(node.get_param_value("fps"), 30, "default fps is 30")
	GNTestAssert.assert_eq(node.get_param_value("active"), true, "default active is true")

func test_video_device_in_img_cook_null() -> void:
	var node := _make_node(VideoDeviceInIMG.new(), "vdevice5")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "VideoDeviceInIMG cook-null no crash")

func test_video_device_in_img_time_dependent() -> void:
	var node := _make_node(VideoDeviceInIMG.new(), "vdevice6")
	GNTestAssert.assert_true(node.time_dependent, "time_dependent is true")

func test_video_device_in_img_description() -> void:
	var node := _make_node(VideoDeviceInIMG.new(), "vdevice7")
	GNTestAssert.assert_true(not node.node_description.is_empty(), "has description")
