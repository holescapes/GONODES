extends Node
## Integration tests: multi-node cook chains via GNCookEngine.cook_frame().
##
## Unlike unit tests that call execute_cook() directly on each operator,
## these tests wire real operators through GNNetwork connections and let
## the cook engine resolve inputs, topological order, and dirty propagation.
## This verifies the full pipeline end-to-end.

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


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _add(node: GNNode, id: String) -> GNNode:
	node.initialize(id)
	_network.add_node(node)
	_engine.add_child(node)
	return node


func _wire(from_id: String, from_port: int, to_id: String, to_port: int) -> void:
	_network.connect_nodes(from_id, from_port, to_id, to_port)


func _cook_frame() -> void:
	# Mark all nodes dirty so the first cook processes everything
	for nid in _network.nodes:
		_network.nodes[nid].dirty = true
	_engine.cook_frame(_engine.current_delta)


# ═══════════════════════════════════════════════════════════════════════════════
# SOP chains
# ═══════════════════════════════════════════════════════════════════════════════

func test_box_into_transform_sop() -> void:
	_add(BoxSOP.new(), "box1")
	var xf := _add(TransformSOP.new(), "xf1")
	xf.set_param_value("ty", 5.0)
	_wire("box1", 0, "xf1", 0)
	_cook_frame()

	var geo: GNGeoData = xf.cached_output as GNGeoData
	GNTestAssert.assert_not_null(geo, "transform produced output")
	GNTestAssert.assert_true(geo.has_geometry(), "has geometry")
	# All verts should be shifted up by 5
	var positions := geo.get_positions()
	GNTestAssert.assert_gt(positions.size(), 0, "has verts")
	var min_y: float = INF
	for p in positions:
		if p.y < min_y:
			min_y = p.y
	GNTestAssert.assert_gt(min_y, 3.5, "lowest vert shifted up by ty=5")


func test_box_into_null_sop_passthrough() -> void:
	_add(BoxSOP.new(), "box1")
	var ns := _add(NullSOP.new(), "null1")
	_wire("box1", 0, "null1", 0)
	_cook_frame()

	var geo: GNGeoData = ns.cached_output as GNGeoData
	GNTestAssert.assert_not_null(geo, "null passed through")
	GNTestAssert.assert_true(geo.has_geometry(), "has geometry")


func test_sop_three_node_chain() -> void:
	_add(BoxSOP.new(), "box1")
	var xf := _add(TransformSOP.new(), "xf1")
	xf.set_param_value("sx", 2.0)
	_add(NullSOP.new(), "null1")
	_wire("box1", 0, "xf1", 0)
	_wire("xf1", 0, "null1", 0)
	_cook_frame()

	var geo: GNGeoData = _network.nodes["null1"].cached_output as GNGeoData
	GNTestAssert.assert_not_null(geo, "end-of-chain has output")
	GNTestAssert.assert_true(geo.has_geometry(), "has geometry")


# ═══════════════════════════════════════════════════════════════════════════════
# CHOP chains
# ═══════════════════════════════════════════════════════════════════════════════

func test_constant_into_null_chop() -> void:
	var c := _add(ConstantCHOP.new(), "const1")
	c.set_param_value("name0", "val")
	c.set_param_value("value0", 42.0)
	_add(NullCHOP.new(), "null1")
	_wire("const1", 0, "null1", 0)
	_cook_frame()

	var chop: GNChannelData = _network.nodes["null1"].cached_output as GNChannelData
	GNTestAssert.assert_not_null(chop, "null passed through CHOP data")
	if chop != null:
		GNTestAssert.assert_approx(chop.get_value("val", -1), 42.0, 0.01,
			"channel value preserved through chain")


func test_constant_into_math_chop() -> void:
	var c := _add(ConstantCHOP.new(), "const1")
	c.set_param_value("name0", "x")
	c.set_param_value("value0", 10.0)
	var m := _add(MathCHOP.new(), "math1")
	m.set_param_value("gain", 2.0)
	_wire("const1", 0, "math1", 0)
	_cook_frame()

	var chop: GNChannelData = m.cached_output as GNChannelData
	GNTestAssert.assert_not_null(chop, "math produced output")
	if chop != null:
		GNTestAssert.assert_approx(chop.get_value("x", -1), 20.0, 0.1,
			"gain=2 doubles value")


# ═══════════════════════════════════════════════════════════════════════════════
# DAT chains
# ═══════════════════════════════════════════════════════════════════════════════

func test_constant_dat_into_null_dat() -> void:
	var cd := _add(ConstantDAT.new(), "cdat1")
	cd.set_param_value("value", "hello")
	_add(NullDAT.new(), "null1")
	_wire("cdat1", 0, "null1", 0)
	_cook_frame()

	var dat: GNTableData = _network.nodes["null1"].cached_output as GNTableData
	GNTestAssert.assert_not_null(dat, "null passed through DAT data")


func test_dat_into_transpose_chain() -> void:
	var td := _add(TextDAT.new(), "text1")
	td.set_param_value("text", "a,b,c\n1,2,3\n4,5,6")
	td.set_param_value("output_mode", 1)  # CSV table mode
	var tr := _add(TransposeDAT.new(), "tr1")
	_wire("text1", 0, "tr1", 0)
	_cook_frame()

	var out: GNTableData = tr.cached_output as GNTableData
	GNTestAssert.assert_not_null(out, "transpose produced output")
	if out is GNTableData:
		GNTestAssert.assert_true(out.num_rows() > 0, "has rows after transpose")


# ═══════════════════════════════════════════════════════════════════════════════
# Cross-family chain
# ═══════════════════════════════════════════════════════════════════════════════

func test_dirty_propagation_through_chain() -> void:
	var c := _add(ConstantCHOP.new(), "const1")
	c.set_param_value("name0", "v")
	c.set_param_value("value0", 1.0)
	_add(NullCHOP.new(), "null1")
	_wire("const1", 0, "null1", 0)

	# First cook
	_cook_frame()
	var v1: float = 0.0
	var chop: GNChannelData = _network.nodes["null1"].cached_output as GNChannelData
	if chop != null:
		v1 = chop.get_value("v", -1)

	# Change upstream param — downstream should update
	c.set_param_value("value0", 99.0)
	c.dirty = true
	_engine.cook_frame(_engine.current_delta)

	chop = _network.nodes["null1"].cached_output as GNChannelData
	if chop != null:
		GNTestAssert.assert_approx(chop.get_value("v", -1), 99.0, 0.1,
			"dirty propagation updated downstream")
