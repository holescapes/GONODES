extends Node
## Phase 4a audit tests — cook engine behavioural contracts.
##
## Covers selective input pruning, expression-driven switch hold,
## per-port demand stamping, parallel CPU cook, subnet inner engine,
## and cycle rejection on connect_nodes.


var _engine: GNCookEngine
var _network: GNNetwork


func before_each() -> void:
	_network = GNNetwork.new()
	_engine = GNCookEngine.new()
	_engine.network = _network
	_engine.cooking_enabled = false
	_engine.elapsed_time = 1.0
	_engine.frame_count = 0
	_engine.current_delta = 1.0 / 60.0
	add_child(_engine)


func after_each() -> void:
	if is_instance_valid(_engine):
		_engine.queue_free()
	_engine = null
	_network = null


func _make(script_class, id: String) -> GNNode:
	var node: GNNode = script_class.new()
	node.initialize(id)
	_network.add_node(node)
	return node


func _make_probe(id: String, ch_value: float = 1.0) -> CookProbeCHOP:
	var node := _make(CookProbeCHOP, id) as CookProbeCHOP
	node.set_param_value("name0", "out")
	node.set_param_value("value0", ch_value)
	return node


func _cook() -> void:
	_engine.cook_frame(_engine.current_delta)


# ═══════════════════════════════════════════════════════════════════════════════
# 1. Selective pruning — get_active_input_indices()
# ═══════════════════════════════════════════════════════════════════════════════

func test_cook_selective_pruning_active_input_indices() -> void:
	var probe0 := _make_probe("probe0", 10.0)
	var probe1 := _make_probe("probe1", 20.0)
	var switch_node := _make(SwitchCHOP, "switch") as SwitchCHOP
	switch_node.set_param_value("index", 0)

	_network.connect_nodes("probe0", 0, "switch", 0)
	_network.connect_nodes("probe1", 0, "switch", 1)

	probe0.mark_dirty()
	probe1.mark_dirty()
	switch_node.mark_dirty()

	var sinks: Array[String] = ["switch"]
	_engine.set_active_sinks(sinks)
	_cook()

	GNTestAssert.assert_gt(probe0.cook_count, 0, "selected upstream branch must cook")
	GNTestAssert.assert_eq(probe1.cook_count, 0, "pruned upstream branch must not cook")
	GNTestAssert.assert_true(probe0.is_active, "selected probe stays active")
	GNTestAssert.assert_false(probe1.is_active, "pruned probe is inactive")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. One-frame Switch hold — expression-driven index lags active set by one frame
# ═══════════════════════════════════════════════════════════════════════════════

func test_cook_switch_expression_one_frame_hold() -> void:
	var probe0 := _make_probe("probe0", 1.0)
	var probe1 := _make_probe("probe1", 2.0)
	var driver := _make(ConstantCHOP, "driver")
	driver.set_param_value("name0", "sel")
	driver.set_param_value("value0", 0.0)

	var switch_node := _make(SwitchCHOP, "switch") as SwitchCHOP
	switch_node.get_parameter("index").set_expression('pari("driver", "value0")')

	_network.connect_nodes("probe0", 0, "switch", 0)
	_network.connect_nodes("probe1", 0, "switch", 1)

	var sinks: Array[String] = ["switch"]
	_engine.set_active_sinks(sinks)

	# Frame 1 — expression index resolves to 0; only probe0 is in the active chain.
	probe0.mark_dirty()
	probe1.mark_dirty()
	switch_node.mark_dirty()
	_cook()

	GNTestAssert.assert_gt(probe0.cook_count, 0, "frame 1: branch 0 active")
	GNTestAssert.assert_eq(probe1.cook_count, 0, "frame 1: branch 1 pruned")

	# Change driver before frame 2. Active set still uses last frame's index (0).
	driver.set_param_value("value0", 1.0)
	probe0.cook_count = 0
	probe1.cook_count = 0
	probe0.mark_dirty()
	probe1.mark_dirty()
	switch_node.mark_dirty()
	_cook()

	GNTestAssert.assert_gt(probe0.cook_count, 0,
		"frame 2: active set still on branch 0 despite expression change")
	GNTestAssert.assert_eq(probe1.cook_count, 0,
		"frame 2: branch 1 still pruned until next active-set rebuild")

	# Frame 3 — active set rebuilt with index 1 from prior frame's resolved value.
	probe0.cook_count = 0
	probe1.cook_count = 0
	probe0.mark_dirty()
	probe1.mark_dirty()
	switch_node.mark_dirty()
	_cook()

	GNTestAssert.assert_eq(probe0.cook_count, 0, "frame 3: branch 0 pruned")
	GNTestAssert.assert_gt(probe1.cook_count, 0, "frame 3: branch 1 now active")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. Demand culling — _stamp_demanded_outputs()
# ═══════════════════════════════════════════════════════════════════════════════

func test_cook_demand_culling_stamps_outputs() -> void:
	var dual := _make(DualOutputCHOP, "dual") as DualOutputCHOP
	var sink := _make(NullCHOP, "sink")
	sink.is_sink = true

	_network.connect_nodes("dual", 0, "sink", 0)

	dual.mark_dirty()
	_engine.set_active_sinks([] as Array[String])
	_cook()

	GNTestAssert.assert_gt(dual.cook_count, 0, "dual-output node must cook to stamp demand")
	GNTestAssert.assert_true(dual.is_output_demanded(0), "wired port 0 is demanded")
	GNTestAssert.assert_false(dual.is_output_demanded(1), "unwired port 1 is not demanded")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. Parallel cook — CPU batch >= parallel_min_batch
# ═══════════════════════════════════════════════════════════════════════════════

func test_cook_parallel_cpu_batch() -> void:
	_engine.parallel_cook_enabled = true
	_network.multithreading_enabled = true

	var p1 := _make_probe("par1", 1.0)
	var p2 := _make_probe("par2", 2.0)
	var p3 := _make_probe("par3", 3.0)

	p1.mark_dirty()
	p2.mark_dirty()
	p3.mark_dirty()

	var sinks: Array[String] = ["par1", "par2", "par3"]
	_engine.set_active_sinks(sinks)
	_cook()

	GNTestAssert.assert_true(_engine.parallel_cook_enabled, "parallel cook must be enabled")
	GNTestAssert.assert_true(_network.multithreading_enabled, "network multithreading must be enabled")
	GNTestAssert.assert_true(_engine._threads_available,
		"parallel branch unreachable — threads unavailable in headless")

	GNTestAssert.assert_eq(p1.cook_count, 1, "parallel probe 1 cooked")
	GNTestAssert.assert_eq(p2.cook_count, 1, "parallel probe 2 cooked")
	GNTestAssert.assert_eq(p3.cook_count, 1, "parallel probe 3 cooked")

	var actual_cooked := 0
	for probe in [p1, p2, p3]:
		if probe.cook_count > 0:
			actual_cooked += 1
	GNTestAssert.assert_eq(_engine._cooked_this_frame.size(), actual_cooked,
		"engine accounting matches nodes that actually cooked")


# ═══════════════════════════════════════════════════════════════════════════════
# 5. Subnet inner engine — SubNetworkNode._inner_cook_engine.cook_frame
# ═══════════════════════════════════════════════════════════════════════════════

func test_cook_subnet_inner_engine_frame() -> void:
	var subnet := _make(SubNetworkNode, "subnet") as SubNetworkNode
	# SubNetworkNode::_on_inner_graph_changed() takes no args but graph_changed
	# emits one — disconnect during setup to avoid script errors in the runner.
	var inner_net := subnet.inner_network
	var graph_handler := Callable(subnet, "_on_inner_graph_changed")
	if inner_net.graph_changed.is_connected(graph_handler):
		inner_net.graph_changed.disconnect(graph_handler)

	var out_tunnel := OutTunnel.new()
	out_tunnel.tunnel_family = GNFamily.Type.CHOP
	out_tunnel.initialize("out0")
	inner_net.add_node(out_tunnel)
	subnet._inner_cook_engine.add_child(out_tunnel)

	var inner_probe := CookProbeCHOP.new()
	inner_probe.initialize("inner_const")
	inner_probe.set_param_value("name0", "out")
	inner_probe.set_param_value("value0", 5.0)
	inner_net.add_node(inner_probe)
	subnet._inner_cook_engine.add_child(inner_probe)

	inner_net.connect_nodes("inner_const", 0, "out0", 0)
	if not inner_net.graph_changed.is_connected(graph_handler):
		inner_net.graph_changed.connect(graph_handler)
	subnet.sync_ports_from_tunnels()

	var inner_fc_before := subnet._inner_cook_engine.frame_count
	subnet.mark_dirty()

	var sinks: Array[String] = ["subnet"]
	_engine.set_active_sinks(sinks)
	_cook()

	GNTestAssert.assert_gt(subnet._inner_cook_engine.frame_count, inner_fc_before,
		"inner cook engine frame_count must increase")
	GNTestAssert.assert_gt(inner_probe.cook_count, 0, "dirty inner node must cook")


# ═══════════════════════════════════════════════════════════════════════════════
# 6. Cycle rejection — connect_nodes rolls back cyclic edges
# ═══════════════════════════════════════════════════════════════════════════════

func test_cook_cycle_rejection_connect_nodes() -> void:
	var node_a := _make(NullCHOP, "node_a")
	var node_b := _make(NullCHOP, "node_b")

	GNTestAssert.assert_true(
		_network.connect_nodes("node_a", 0, "node_b", 0),
		"A→B should connect")
	GNTestAssert.assert_false(
		_network.connect_nodes("node_b", 0, "node_a", 0),
		"B→A must be rejected")

	var cycle_edge_exists := false
	for conn in _network.connections:
		if conn.from_node == "node_b" and conn.to_node == "node_a":
			cycle_edge_exists = true
			break
	GNTestAssert.assert_false(cycle_edge_exists, "rejected cycle edge must be erased")
	GNTestAssert.assert_false(_network.has_cycle(), "graph stays acyclic after rejection")


# ─── Test-local probe nodes ───────────────────────────────────────────────────

class CookProbeCHOP extends ConstantCHOP:
	var cook_count: int = 0

	func _cook(inputs: Array[GNData]) -> GNData:
		cook_count += 1
		return super._cook(inputs)


class DualOutputCHOP extends GNChopBase:
	var cook_count: int = 0

	func _init() -> void:
		node_type = "dual_out_test"

	func _init_ports() -> void:
		add_output("out0", GNFamily.Type.CHOP, "First output")
		add_output("out1", GNFamily.Type.CHOP, "Second output")

	func _init_parameters() -> void:
		pass

	func _cook(_inputs: Array[GNData]) -> GNData:
		cook_count += 1
		if _cached_channel_data == null:
			_cached_channel_data = GNChannelData.new()
		_cached_channel_data.set_single_value("out", 1.0)
		return _cached_channel_data
