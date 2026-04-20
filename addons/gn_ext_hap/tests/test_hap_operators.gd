extends Node
## Tests for gn_ext_hap operators.

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
# HapInTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_hap_in_top_instantiate() -> void:
	var node := _make_node(HapInTOP.new(), "hapin1")
	GNTestAssert.assert_not_null(node, "HapInTOP created")
	GNTestAssert.assert_eq(node.node_type, "hapin", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.TOP, "family is TOP")

func test_hap_in_top_ports() -> void:
	var node := _make_node(HapInTOP.new(), "hapin2")
	GNTestAssert.assert_eq(node.output_ports.size(), 1, "1 output")
	GNTestAssert.assert_eq(node.output_ports[0].family, GNFamily.Type.TOP, "output is TOP")

func test_hap_in_top_parameters() -> void:
	var node := _make_node(HapInTOP.new(), "hapin3")
	GNTestAssert.assert_true(node.parameters.has("file"), "has file param")

func test_hap_in_top_set_file() -> void:
	var node := _make_node(HapInTOP.new(), "hapin4")
	node.set_param_value("file", "test.mov")
	GNTestAssert.assert_eq(node.get_param_value("file"), "test.mov", "file param set")

func test_hap_in_top_cook_null() -> void:
	var node := _make_node(HapInTOP.new(), "hapin5")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "HapInTOP cook-null no crash")

func test_hap_in_top_description() -> void:
	var node := _make_node(HapInTOP.new(), "hapin6")
	GNTestAssert.assert_true(not node.node_description.is_empty(), "has description")


# ═══════════════════════════════════════════════════════════════════════════════
# HapOUT
# ═══════════════════════════════════════════════════════════════════════════════

func test_hap_out_instantiate() -> void:
	var node := _make_node(HapOUT.new(), "hapout1")
	GNTestAssert.assert_not_null(node, "HapOUT created")
	GNTestAssert.assert_eq(node.node_type, "hap_out", "node_type")

func test_hap_out_ports() -> void:
	var node := _make_node(HapOUT.new(), "hapout2")
	GNTestAssert.assert_eq(node.input_ports.size(), 1, "1 input")
	GNTestAssert.assert_eq(node.input_ports[0].family, GNFamily.Type.TOP, "input is TOP")

func test_hap_out_parameters() -> void:
	var node := _make_node(HapOUT.new(), "hapout3")
	GNTestAssert.assert_true(node.parameters.has("file_path"), "has file_path")
	GNTestAssert.assert_true(node.parameters.has("variant"), "has variant")
	GNTestAssert.assert_true(node.parameters.has("fps"), "has fps")
	GNTestAssert.assert_true(node.parameters.has("record"), "has record")

func test_hap_out_cook_null() -> void:
	var node := _make_node(HapOUT.new(), "hapout4")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "HapOUT cook-null no crash")
