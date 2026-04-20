extends Node
## Tests for gn_ext_spout operators.

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
# SpoutInTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_spout_in_top_instantiate() -> void:
	var node := _make_node(SpoutInTOP.new(), "spoutin1")
	GNTestAssert.assert_not_null(node, "SpoutInTOP created")
	GNTestAssert.assert_eq(node.node_type, "spoutintop", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.TOP, "family is TOP")

func test_spout_in_top_ports() -> void:
	var node := _make_node(SpoutInTOP.new(), "spoutin2")
	GNTestAssert.assert_eq(node.input_ports.size(), 0, "no inputs")
	GNTestAssert.assert_eq(node.output_ports.size(), 1, "1 output")
	GNTestAssert.assert_eq(node.output_ports[0].family, GNFamily.Type.TOP, "output is TOP")

func test_spout_in_top_parameters() -> void:
	var node := _make_node(SpoutInTOP.new(), "spoutin3")
	GNTestAssert.assert_true(node.parameters.has("sender_name"), "has sender_name")
	GNTestAssert.assert_true(node.parameters.has("resolution"), "has resolution")

func test_spout_in_top_cook_null() -> void:
	var node := _make_node(SpoutInTOP.new(), "spoutin4")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "SpoutInTOP cook-null no crash")

func test_spout_in_top_time_dependent() -> void:
	var node := _make_node(SpoutInTOP.new(), "spoutin5")
	GNTestAssert.assert_true(node.time_dependent, "time_dependent is true")


# ═══════════════════════════════════════════════════════════════════════════════
# SpoutOutTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_spout_out_top_instantiate() -> void:
	var node := _make_node(SpoutOutTOP.new(), "spoutout1")
	GNTestAssert.assert_not_null(node, "SpoutOutTOP created")
	GNTestAssert.assert_eq(node.node_type, "spoutouttop", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.TOP, "family is TOP")

func test_spout_out_top_ports() -> void:
	var node := _make_node(SpoutOutTOP.new(), "spoutout2")
	GNTestAssert.assert_eq(node.input_ports.size(), 1, "1 input")
	GNTestAssert.assert_eq(node.input_ports[0].family, GNFamily.Type.TOP, "input is TOP")
	GNTestAssert.assert_eq(node.output_ports.size(), 1, "1 output (pass-through)")

func test_spout_out_top_parameters() -> void:
	var node := _make_node(SpoutOutTOP.new(), "spoutout3")
	GNTestAssert.assert_true(node.parameters.has("sender_name"), "has sender_name")
	GNTestAssert.assert_true(node.parameters.has("active"), "has active")

func test_spout_out_top_cook_null() -> void:
	var node := _make_node(SpoutOutTOP.new(), "spoutout4")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "SpoutOutTOP cook-null no crash")

func test_spout_out_top_is_sink() -> void:
	var node := _make_node(SpoutOutTOP.new(), "spoutout5")
	GNTestAssert.assert_true(node.is_sink, "is_sink is true")
