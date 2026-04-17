extends Node
## Integration tests — Network serialization round-trip.
##
## Tests verify that a complete network (nodes + connections + parameter state)
## survives serialization to JSON and deserialization back, including expression
## parameters, multi-node chains, and edge cases.

var _engine: GNCookEngine
var _network: GNNetwork


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func before_each() -> void:
	_network = GNNetwork.new()
	_engine = GNCookEngine.new()
	_engine.network = _network
	_engine.cooking_enabled = false
	_engine.elapsed_time = 1.0
	_engine.frame_count = 30
	_engine.current_delta = 1.0 / 60.0
	add_child(_engine)


func after_each() -> void:
	if is_instance_valid(_engine):
		_engine.queue_free()
	_engine = null
	_network = null


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _make_node(script_class: GDScript, id: String) -> GNNode:
	var node: GNNode = script_class.new()
	node.initialize(id)
	_network.add_node(node)
	return node


func _cook_one_frame() -> void:
	_engine.cook_frame(_engine.current_delta)


func _rebuild_network_from_dict(d: Dictionary) -> GNNetwork:
	## Constructs a fresh network from a serialized dictionary.
	## Uses the same logic the editor's load path would.
	var net := GNNetwork.new()
	net.from_dict(d)
	return net


# ═══════════════════════════════════════════════════════════════════════════════
# Empty Network Round-Trip
# ═══════════════════════════════════════════════════════════════════════════════

func test_empty_network_roundtrip() -> void:
	var d := _network.to_dict()
	GNTestAssert.assert_has_key(d, "nodes", "should have nodes key")
	GNTestAssert.assert_has_key(d, "connections", "should have connections key")
	GNTestAssert.assert_eq(d["nodes"].size(), 0, "no nodes")
	GNTestAssert.assert_eq(d["connections"].size(), 0, "no connections")


# ═══════════════════════════════════════════════════════════════════════════════
# Single Node — Parameter Values Preserved
# ═══════════════════════════════════════════════════════════════════════════════

func test_single_node_params_preserved() -> void:
	var c := _make_node(ConstantCHOP, "myconst")
	c.set_param_value("name0", "custom_name")
	c.set_param_value("value0", 77.0)
	c.graph_position = Vector2(100, 200)

	var d := _network.to_dict()
	GNTestAssert.assert_has_key(d["nodes"], "myconst", "node in dict")

	var node_dict: Dictionary = d["nodes"]["myconst"]
	GNTestAssert.assert_eq(node_dict["type"], "ConstantCHOP", "type preserved")
	GNTestAssert.assert_has_key(node_dict, "parameters", "has params")

	# Verify value0 was serialized
	var params_dict: Dictionary = node_dict["parameters"]
	GNTestAssert.assert_has_key(params_dict, "value0", "value0 in params")


# ═══════════════════════════════════════════════════════════════════════════════
# Connections Preserved
# ═══════════════════════════════════════════════════════════════════════════════

func test_connections_preserved() -> void:
	_make_node(ConstantCHOP, "a")
	_make_node(NullCHOP, "b")
	_network.connect_nodes("a", 0, "b", 0)

	var d := _network.to_dict()
	GNTestAssert.assert_eq(d["connections"].size(), 1, "one connection")

	var conn: Dictionary = d["connections"][0]
	GNTestAssert.assert_eq(conn["from"], "a", "from")
	GNTestAssert.assert_eq(conn["to"], "b", "to")
	GNTestAssert.assert_eq(conn["from_port"], 0, "from_port")
	GNTestAssert.assert_eq(conn["to_port"], 0, "to_port")


# ═══════════════════════════════════════════════════════════════════════════════
# Expression Mode Survives Round-Trip
# ═══════════════════════════════════════════════════════════════════════════════

func test_expression_param_roundtrip() -> void:
	var c := _make_node(ConstantCHOP, "expr_node")
	var p: GNParameter = c.parameters["value0"]
	p.set_expression("time * 10.0 + 5.0")

	var d := _network.to_dict()
	var node_dict: Dictionary = d["nodes"]["expr_node"]
	var params: Dictionary = node_dict["parameters"]
	var val0: Dictionary = params["value0"]

	GNTestAssert.assert_eq(val0.get("mode", ""), "EXPRESSION", "mode saved")
	GNTestAssert.assert_eq(val0.get("expression", ""), "time * 10.0 + 5.0", "expression saved")


# ═══════════════════════════════════════════════════════════════════════════════
# Multi-Node Chain — Cook After Deserialize
# ═══════════════════════════════════════════════════════════════════════════════

func test_chain_cook_after_deserialize() -> void:
	## Build chain: Constant(val=5) → Math(*3) → Null
	## Serialize → deserialize → cook → verify output = 15
	var c := _make_node(ConstantCHOP, "src")
	c.set_param_value("name0", "x")
	c.set_param_value("value0", 5.0)

	var m := _make_node(MathCHOP, "mul")
	m.set_param_value("operation", 2)  # Multiply
	m.set_param_value("operand", 3.0)
	_network.connect_nodes("src", 0, "mul", 0)

	var n := _make_node(NullCHOP, "sink")
	_network.connect_nodes("mul", 0, "sink", 0)

	# Serialize
	var d := _network.to_dict()

	# Deserialize into fresh network + engine
	var net2 := GNNetwork.new()
	net2.from_dict(d)

	var engine2 := GNCookEngine.new()
	engine2.network = net2
	engine2.cooking_enabled = false
	engine2.elapsed_time = 1.0
	engine2.frame_count = 0
	engine2.current_delta = 1.0 / 60.0
	add_child(engine2)

	engine2.set_active_sinks(["sink"] as Array[String])
	engine2.cook_frame(engine2.current_delta)

	var sink_node: GNNode = net2.nodes.get("sink", null)
	GNTestAssert.assert_not_null(sink_node, "sink exists after deserialize")

	var output := sink_node.cached_output as GNChannelData
	GNTestAssert.assert_not_null(output, "output after round-trip cook")
	GNTestAssert.assert_approx(output.get_value("x"), 15.0, 0.001, "5 * 3 = 15 after round-trip")

	engine2.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# Node Count Survives
# ═══════════════════════════════════════════════════════════════════════════════

func test_node_count_preserved() -> void:
	_make_node(ConstantCHOP, "a")
	_make_node(ConstantCHOP, "b")
	_make_node(MathCHOP, "c")
	_make_node(NullCHOP, "d")
	_network.connect_nodes("a", 0, "c", 0)
	_network.connect_nodes("b", 0, "c", 1)
	_network.connect_nodes("c", 0, "d", 0)

	var d := _network.to_dict()
	GNTestAssert.assert_eq(d["nodes"].size(), 4, "4 nodes serialized")
	GNTestAssert.assert_eq(d["connections"].size(), 3, "3 connections serialized")

	var net2 := GNNetwork.new()
	net2.from_dict(d)
	GNTestAssert.assert_eq(net2.nodes.size(), 4, "4 nodes restored")
	GNTestAssert.assert_eq(net2.connections.size(), 3, "3 connections restored")
