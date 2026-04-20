extends Node
## Tests for gn_ext_blackmagic operators.

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
# BlackmagicInIMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_blackmagic_in_img_instantiate() -> void:
	var node := _make_node(BlackmagicInIMG.new(), "bmin1")
	GNTestAssert.assert_not_null(node, "BlackmagicInIMG created")
	GNTestAssert.assert_eq(node.node_type, "blackmagicin", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.IMG, "family is IMG")

func test_blackmagic_in_img_ports() -> void:
	var node := _make_node(BlackmagicInIMG.new(), "bmin2")
	GNTestAssert.assert_eq(node.output_ports.size(), 2, "2 output ports")
	GNTestAssert.assert_eq(node.output_ports[0].family, GNFamily.Type.IMG, "port 0 is IMG")
	GNTestAssert.assert_eq(node.output_ports[1].family, GNFamily.Type.CHOP, "port 1 is CHOP")

func test_blackmagic_in_img_parameters() -> void:
	var node := _make_node(BlackmagicInIMG.new(), "bmin3")
	GNTestAssert.assert_true(node.parameters.has("device"), "has device param")
	GNTestAssert.assert_true(node.parameters.has("resolution"), "has resolution param")
	GNTestAssert.assert_true(node.parameters.has("fps"), "has fps param")
	GNTestAssert.assert_true(node.parameters.has("active"), "has active param")

func test_blackmagic_in_img_cook_null() -> void:
	var node := _make_node(BlackmagicInIMG.new(), "bmin4")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "BlackmagicInIMG cook-null no crash")

func test_blackmagic_in_img_time_dependent() -> void:
	var node := _make_node(BlackmagicInIMG.new(), "bmin5")
	GNTestAssert.assert_true(node.time_dependent, "time_dependent is true")

func test_blackmagic_in_img_description() -> void:
	var node := _make_node(BlackmagicInIMG.new(), "bmin6")
	GNTestAssert.assert_true(not node.node_description.is_empty(), "has node_description")


# ═══════════════════════════════════════════════════════════════════════════════
# BlackmagicOutIMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_blackmagic_out_img_instantiate() -> void:
	var node := _make_node(BlackmagicOutIMG.new(), "bmout1")
	GNTestAssert.assert_not_null(node, "BlackmagicOutIMG created")
	GNTestAssert.assert_eq(node.node_type, "blackmagicout", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.IMG, "family is IMG")

func test_blackmagic_out_img_ports() -> void:
	var node := _make_node(BlackmagicOutIMG.new(), "bmout2")
	GNTestAssert.assert_eq(node.input_ports.size(), 1, "1 input port")
	GNTestAssert.assert_eq(node.input_ports[0].family, GNFamily.Type.IMG, "input is IMG")
	GNTestAssert.assert_eq(node.output_ports.size(), 1, "1 output port")
	GNTestAssert.assert_eq(node.output_ports[0].family, GNFamily.Type.IMG, "output is IMG")

func test_blackmagic_out_img_parameters() -> void:
	var node := _make_node(BlackmagicOutIMG.new(), "bmout3")
	GNTestAssert.assert_true(node.parameters.has("device"), "has device param")
	GNTestAssert.assert_true(node.parameters.has("resolution"), "has resolution param")
	GNTestAssert.assert_true(node.parameters.has("fps"), "has fps param")
	GNTestAssert.assert_true(node.parameters.has("active"), "has active param")

func test_blackmagic_out_img_cook_null() -> void:
	var node := _make_node(BlackmagicOutIMG.new(), "bmout4")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "BlackmagicOutIMG cook-null no crash")

func test_blackmagic_out_img_time_dependent() -> void:
	var node := _make_node(BlackmagicOutIMG.new(), "bmout5")
	GNTestAssert.assert_true(node.time_dependent, "time_dependent is true")


# ═══════════════════════════════════════════════════════════════════════════════
# BlackmagicDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_blackmagic_dat_instantiate() -> void:
	var node := _make_node(BlackmagicDAT.new(), "bm1")
	GNTestAssert.assert_not_null(node, "BlackmagicDAT created")
	GNTestAssert.assert_eq(node.node_type, "blackmagic", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.DAT, "family is DAT")

func test_blackmagic_dat_cook_null() -> void:
	var node := _make_node(BlackmagicDAT.new(), "bm2")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "BlackmagicDAT cook-null no crash")
