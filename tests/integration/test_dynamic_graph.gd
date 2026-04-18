extends Node
## Integration tests for runtime dynamic graph modification.
##
## Verifies that nodes can be added, connected, disconnected, and removed
## from an active network while the cook engine is running — matching the
## capabilities exposed by the libgonodes C API (Gap 7).

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
	return node


func _wire(from_id: String, from_port: int, to_id: String, to_port: int) -> void:
	_network.connect_nodes(from_id, from_port, to_id, to_port)


func _cook_frame() -> void:
	for nid in _network.nodes:
		_network.nodes[nid].dirty = true
	_engine.cook_frame(_engine.current_delta)


func _sink(ids: Array) -> void:
	var typed: Array[String] = []
	for id in ids:
		typed.append(str(id))
	_engine.set_active_sinks(typed)


# ═══════════════════════════════════════════════════════════════════════════════
# Add nodes at runtime
# ═══════════════════════════════════════════════════════════════════════════════

func test_add_node_to_running_network() -> void:
	# Start with a single node, cook, then add a second and cook again.
	var c1 := _add(ConstantCHOP.new(), "const1")
	c1.set_param_value("value0", 10.0)
	_sink(["const1"])
	_cook_frame()

	var out1: GNChannelData = c1.cached_output as GNChannelData
	GNTestAssert.assert_not_null(out1, "initial cook produced output")

	# Add second node and wire it
	var math := _add(MathCHOP.new(), "math1")
	math.set_param_value("operation", 0)  # Add
	_wire("const1", 0, "math1", 0)
	_sink(["math1"])
	_cook_frame()

	var out2: GNChannelData = math.cached_output as GNChannelData
	GNTestAssert.assert_not_null(out2, "dynamically added node cooked")


func test_add_node_mid_chain() -> void:
	# Build a → c chain, cook, then insert b between a and c.
	var a := _add(ConstantCHOP.new(), "a")
	a.set_param_value("value0", 5.0)
	var c := _add(NullCHOP.new(), "c")
	_wire("a", 0, "c", 0)
	_sink(["c"])
	_cook_frame()

	var before: GNChannelData = c.cached_output as GNChannelData
	GNTestAssert.assert_not_null(before, "initial chain cooks")

	# Insert b: disconnect a→c, add b, wire a→b→c
	_network.disconnect_nodes("a", 0, "c", 0)
	var b := _add(MathCHOP.new(), "b")
	b.set_param_value("operation", 2)  # Multiply
	b.set_param_value("operand", 3.0)
	_wire("a", 0, "b", 0)
	_wire("b", 0, "c", 0)
	_cook_frame()

	var after: GNChannelData = c.cached_output as GNChannelData
	GNTestAssert.assert_not_null(after, "chain with inserted node cooks")


# ═══════════════════════════════════════════════════════════════════════════════
# Remove nodes at runtime
# ═══════════════════════════════════════════════════════════════════════════════

func test_remove_node_from_running_network() -> void:
	var c1 := _add(ConstantCHOP.new(), "const1")
	var n1 := _add(NullCHOP.new(), "null1")
	_wire("const1", 0, "null1", 0)
	_sink(["null1"])
	_cook_frame()

	GNTestAssert.assert_not_null(n1.cached_output, "null1 cooked initially")

	# Remove const1 — null1 should still cook but with null input
	_network.remove_node("const1")
	_cook_frame()

	# Network should still function with null1 having no input
	GNTestAssert.assert_true(_network.nodes.has("null1"), "null1 still in network")
	GNTestAssert.assert_false(_network.nodes.has("const1"), "const1 removed")


func test_remove_mid_chain_node() -> void:
	# a → b → c, then remove b
	var a := _add(ConstantCHOP.new(), "a")
	a.set_param_value("value0", 7.0)
	var b := _add(NullCHOP.new(), "b")
	var c := _add(NullCHOP.new(), "c")
	_wire("a", 0, "b", 0)
	_wire("b", 0, "c", 0)
	_sink(["c"])
	_cook_frame()

	GNTestAssert.assert_not_null(c.cached_output, "c cooks through chain")

	# Remove b (handles disconnect + cleanup) and reconnect a→c directly
	_network.remove_node("b")
	_wire("a", 0, "c", 0)
	_cook_frame()

	var out: GNChannelData = c.cached_output as GNChannelData
	GNTestAssert.assert_not_null(out, "c cooks after bypass")


# ═══════════════════════════════════════════════════════════════════════════════
# Reconnect at runtime
# ═══════════════════════════════════════════════════════════════════════════════

func test_disconnect_and_reconnect() -> void:
	var c1 := _add(ConstantCHOP.new(), "c1")
	c1.set_param_value("value0", 1.0)
	var c2 := _add(ConstantCHOP.new(), "c2")
	c2.set_param_value("value0", 99.0)
	var n := _add(NullCHOP.new(), "n")
	_wire("c1", 0, "n", 0)
	_sink(["n"])
	_cook_frame()

	# Switch input: disconnect c1, connect c2
	_network.disconnect_nodes("c1", 0, "n", 0)
	_wire("c2", 0, "n", 0)
	_cook_frame()

	var out: GNChannelData = n.cached_output as GNChannelData
	GNTestAssert.assert_not_null(out, "cooks after reconnect")


# ═══════════════════════════════════════════════════════════════════════════════
# Multiple families
# ═══════════════════════════════════════════════════════════════════════════════

func test_dynamic_sop_chain() -> void:
	var box := _add(BoxSOP.new(), "box1")
	_sink(["box1"])
	_cook_frame()

	var geo: GNGeoData = box.cached_output as GNGeoData
	GNTestAssert.assert_not_null(geo, "box cooks")

	# Dynamically add transform
	var xf := _add(TransformSOP.new(), "xf1")
	xf.set_param_value("sx", 2.0)
	_wire("box1", 0, "xf1", 0)
	_sink(["xf1"])
	_cook_frame()

	var out: GNGeoData = xf.cached_output as GNGeoData
	GNTestAssert.assert_not_null(out, "dynamically added SOP produces geometry")
	GNTestAssert.assert_true(out.has_geometry(), "has geometry data")


func test_dynamic_dat_chain() -> void:
	var cd := _add(ConstantDAT.new(), "dat1")
	_sink(["dat1"])
	_cook_frame()

	# Add null downstream
	var n := _add(NullDAT.new(), "nd1")
	_wire("dat1", 0, "nd1", 0)
	_sink(["nd1"])
	_cook_frame()

	GNTestAssert.assert_not_null(n.cached_output, "dynamically wired DAT cooks")


# ═══════════════════════════════════════════════════════════════════════════════
# Dirty propagation after dynamic edits
# ═══════════════════════════════════════════════════════════════════════════════

func test_dirty_propagates_after_add() -> void:
	var a := _add(ConstantCHOP.new(), "a")
	a.set_param_value("value0", 1.0)
	_sink(["a"])
	_cook_frame()

	# Add b wired to a — b should be dirty and cook
	var b := _add(NullCHOP.new(), "b")
	_wire("a", 0, "b", 0)
	_sink(["b"])

	# Only mark b dirty (simulating the cook engine's response to a new wire)
	b.dirty = true
	_engine.cook_frame(_engine.current_delta)

	GNTestAssert.assert_not_null(b.cached_output, "newly wired node cooks via dirty propagation")
