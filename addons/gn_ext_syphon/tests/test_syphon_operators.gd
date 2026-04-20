extends Node
## Tests for gn_ext_syphon operators.

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
# SyphonInTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_syphon_in_top_instantiate() -> void:
	var node := _make_node(SyphonInTOP.new(), "syphonin1")
	GNTestAssert.assert_not_null(node, "SyphonInTOP created")
	GNTestAssert.assert_eq(node.node_type, "syphonintop", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.TOP, "family is TOP")

func test_syphon_in_top_ports() -> void:
	var node := _make_node(SyphonInTOP.new(), "syphonin2")
	GNTestAssert.assert_eq(node.input_ports.size(), 0, "no inputs")
	GNTestAssert.assert_eq(node.output_ports.size(), 1, "1 output")
	GNTestAssert.assert_eq(node.output_ports[0].family, GNFamily.Type.TOP, "output is TOP")

func test_syphon_in_top_cook_null() -> void:
	var node := _make_node(SyphonInTOP.new(), "syphonin3")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "SyphonInTOP cook-null no crash")

func test_syphon_in_top_time_dependent() -> void:
	var node := _make_node(SyphonInTOP.new(), "syphonin4")
	GNTestAssert.assert_true(node.time_dependent, "time_dependent is true")


# ═══════════════════════════════════════════════════════════════════════════════
# SyphonOutTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_syphon_out_top_instantiate() -> void:
	var node := _make_node(SyphonOutTOP.new(), "syphonout1")
	GNTestAssert.assert_not_null(node, "SyphonOutTOP created")
	GNTestAssert.assert_eq(node.node_type, "syphonouttop", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.TOP, "family is TOP")

func test_syphon_out_top_ports() -> void:
	var node := _make_node(SyphonOutTOP.new(), "syphonout2")
	GNTestAssert.assert_eq(node.input_ports.size(), 1, "1 input")
	GNTestAssert.assert_eq(node.input_ports[0].family, GNFamily.Type.TOP, "input is TOP")
	GNTestAssert.assert_eq(node.output_ports.size(), 1, "1 output (pass-through)")

func test_syphon_out_top_cook_null() -> void:
	var node := _make_node(SyphonOutTOP.new(), "syphonout3")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "SyphonOutTOP cook-null no crash")

func test_syphon_out_top_is_sink() -> void:
	var node := _make_node(SyphonOutTOP.new(), "syphonout4")
	GNTestAssert.assert_true(node.is_sink, "is_sink is true")
