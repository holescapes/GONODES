class_name GNCookEngine
extends Node
## The frame-driven cook engine for GONODES.
## Processes the node graph each frame: marks time-dependent nodes dirty,
## resolves parameters (expressions, binds, exports), topologically sorts
## dirty nodes, and cooks them in order.
##
## Operator nodes (GNNode) are children of this Node in the scene tree.
## The cook engine adopts them when a network is assigned, giving TOPs
## direct subtree ownership of their SubViewports.

# ─── References ────────────────────────────────────────────────────────────────

## The network this engine operates on.
var network: GNNetwork = null

# ─── Frame State ───────────────────────────────────────────────────────────────

## Current frame number (increments each cook cycle).
var frame_count: int = 0

## Accumulated wall-clock time since the engine started (seconds).
var elapsed_time: float = 0.0

## Delta time of the current frame (seconds).
var current_delta: float = 0.0

## Total cook time for the last frame (ms), across all nodes.
var frame_cook_time_ms: float = 0.0

# ─── Configuration ─────────────────────────────────────────────────────────────

## If true, the engine cooks every frame. Set false to pause cooking.
var cooking_enabled: bool = true

## Maximum nodes to cook per frame (0 = unlimited).
## Can be used to throttle heavy patches on low-end hardware.
var max_cooks_per_frame: int = 0

# ─── Expression Context ───────────────────────────────────────────────────────

## Reusable expression evaluation helpers — built once, updated each frame.
## These are callables passed into Expression.execute() for op(), chop(), top(), etc.
var _op_func: Callable = Callable()
var _chop_func: Callable = Callable()
var _top_func: Callable = Callable()

## Tracks whether network nodes have been adopted into the scene tree.
var _nodes_adopted: bool = false

# ─── Signals ───────────────────────────────────────────────────────────────────

## Emitted after all nodes in a frame have been cooked.
signal frame_cooked(frame: int, cook_time_ms: float)

## Emitted when a cook error occurs on a specific node.
signal cook_error(node_id: String, error_message: String)


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_build_expression_helpers()
	_adopt_network_nodes()
	GNLogger.info("CookEngine", "Engine ready — cooking_enabled=%s" % str(cooking_enabled))


func _process(delta: float) -> void:
	if not cooking_enabled or network == null:
		return
	# Ensure any newly added network nodes are in the scene tree
	if not _nodes_adopted:
		_adopt_network_nodes()
	current_delta = delta
	elapsed_time += delta
	cook_frame(delta)


# ═══════════════════════════════════════════════════════════════════════════════
# Node Adoption — GNNodes are children of CookEngine in the scene tree
# ═══════════════════════════════════════════════════════════════════════════════

## Adds all network nodes as children of this CookEngine node.
## This places TOPs' SubViewports and WindowTOPs' Windows into the scene tree.
func _adopt_network_nodes() -> void:
	if network == null:
		return
	var adopted_count := 0
	for node_id in network.nodes:
		var node: GNNode = network.nodes[node_id]
		if node.get_parent() == null:
			add_child(node)
			adopted_count += 1
	# Wire signals for future dynamic node additions
	if not network.node_added.is_connected(_on_network_node_added):
		network.node_added.connect(_on_network_node_added)
	_nodes_adopted = true
	GNLogger.info("CookEngine", "Adopted %d node(s) into scene tree" % adopted_count)


## Called when a node is dynamically added to the network at runtime.
func _on_network_node_added(node_id: String) -> void:
	var node: GNNode = network.nodes.get(node_id, null)
	if node and node.get_parent() == null:
		add_child(node)
		GNLogger.debug("CookEngine", "Dynamically adopted node '%s' (%s)" % [node_id, node.node_type])


# ═══════════════════════════════════════════════════════════════════════════════
# Cook Loop
# ═══════════════════════════════════════════════════════════════════════════════

## Executes one full cook cycle for the current frame.
func cook_frame(delta: float) -> void:
	var frame_start := Time.get_ticks_usec()

	# Step 1: Pre-cook pass — let time-dependent nodes mark themselves dirty
	_pre_cook_pass(delta)

	# Step 2: Get topological order
	var topo_order: Array[GNNode] = network.get_topological_order()

	# Step 3: Cook dirty nodes in order
	var cooked_count := 0
	for node in topo_order:
		if not node.dirty:
			continue

		# Inject timing context (so operators can use self.current_delta, etc.)
		node.current_delta = current_delta
		node.elapsed_time = elapsed_time
		node.current_frame = frame_count

		# Resolve parameters (expressions, binds) before cooking
		_resolve_node_parameters(node)

		# Gather input data from upstream cached outputs
		var inputs: Array[GNData] = _gather_inputs(node)

		# Cook the node
		var result := node.execute_cook(inputs, frame_count)

		if result == null and node.input_ports.size() > 0:
			# Only warn for nodes that expected to produce output
			GNLogger.warn("CookEngine", "Node '%s' (%s) cook returned null" % [node.id, node.node_type])
			cook_error.emit(node.id, "cook returned null")
		else:
			GNLogger.debug("CookEngine", "Cooked '%s' (%s) in %.3fms" % [node.id, node.node_type, node.cook_time_ms])

		# Propagate dirty downstream
		if result != null:
			network.propagate_dirty(node.id)

		cooked_count += 1
		if max_cooks_per_frame > 0 and cooked_count >= max_cooks_per_frame:
			break

	# Step 4: Process export mappings (post-MVP, CHOP exports push values)
	_process_export_mappings()

	# Step 5: Frame bookkeeping
	frame_count += 1
	var frame_end := Time.get_ticks_usec()
	frame_cook_time_ms = (frame_end - frame_start) / 1000.0
	GNLogger.debug("CookEngine", "Frame %d: cooked %d node(s) in %.2fms" % [frame_count, cooked_count, frame_cook_time_ms])
	frame_cooked.emit(frame_count, frame_cook_time_ms)


# ═══════════════════════════════════════════════════════════════════════════════
# Pre-Cook
# ═══════════════════════════════════════════════════════════════════════════════

## Calls [method GNNode._pre_cook] on every node so time-dependent ones
## can mark themselves dirty.
func _pre_cook_pass(delta: float) -> void:
	for node_id in network.nodes:
		var node: GNNode = network.nodes[node_id]
		node._pre_cook(delta)


# ═══════════════════════════════════════════════════════════════════════════════
# Input Resolution
# ═══════════════════════════════════════════════════════════════════════════════

## Gathers input data for a node from upstream nodes' cached outputs.
## Returns an array aligned to the node's input port indices.
func _gather_inputs(node: GNNode) -> Array[GNData]:
	var inputs: Array[GNData] = []
	inputs.resize(node.input_ports.size())

	for conn in network.get_input_connections(node.id):
		var upstream: GNNode = network.nodes.get(conn.from_node, null)
		if upstream and upstream.cached_output and conn.to_port < inputs.size():
			inputs[conn.to_port] = upstream.cached_output

	return inputs


# ═══════════════════════════════════════════════════════════════════════════════
# Parameter Resolution
# ═══════════════════════════════════════════════════════════════════════════════

## Resolves all parameters on a node before it cooks.
## Evaluates expressions, resolves binds, etc.
func _resolve_node_parameters(node: GNNode) -> void:
	for param_name in node.parameters:
		var param: GNParameter = node.parameters[param_name]
		match param.mode:
			GNParameter.Mode.CONSTANT:
				# Value already set — nothing to resolve
				pass
			GNParameter.Mode.EXPRESSION:
				_evaluate_expression(node, param)
			GNParameter.Mode.BIND:
				_resolve_bind(node, param)
			GNParameter.Mode.EXPORT:
				# Export values are pushed by _process_export_mappings — just read .value
				pass


## Evaluates an expression parameter and stores the resolved value.
func _evaluate_expression(node: GNNode, param: GNParameter) -> void:
	var expr: Expression = param.get_compiled_expression()
	if expr == null:
		# Expression failed to compile — use fallback
		param.resolved_value = param.fallback_value
		return

	# Build the context array matching the variable names declared during parse:
	# ["op", "chop", "top", "me", "time", "frame", "dt"]
	var context := [
		_op_func,       # op(name) callable
		_chop_func,     # chop(name) callable
		_top_func,      # top(name) callable
		node,           # me — the current node
		elapsed_time,   # time — seconds since start
		frame_count,    # frame — current frame number
		current_delta,  # dt — delta time this frame
	]

	var result = expr.execute(context, node)

	if expr.has_execute_failed():
		GNLogger.error("CookEngine", "Expression error on %s.%s — %s" % [
			node.id, param.param_name, expr.get_error_text()])
		param.resolved_value = param.fallback_value
		cook_error.emit(node.id, "Expression error: %s" % expr.get_error_text())
	else:
		param.resolved_value = result
		param.fallback_value = result  # Update fallback for next failure


## Resolves a bind-mode parameter by reading the source parameter's value.
func _resolve_bind(_node: GNNode, param: GNParameter) -> void:
	if param.bind_source_node.is_empty() or param.bind_source_param.is_empty():
		param.resolved_value = param.fallback_value
		return

	var source_node: GNNode = network.nodes.get(param.bind_source_node, null)
	if source_node == null:
		GNLogger.warn("CookEngine", "Bind source node '%s' not found" % param.bind_source_node)
		param.resolved_value = param.fallback_value
		return

	var source_param: GNParameter = source_node.parameters.get(param.bind_source_param, null)
	if source_param == null:
		GNLogger.warn("CookEngine", "Bind source param '%s.%s' not found" % [
			param.bind_source_node, param.bind_source_param])
		param.resolved_value = param.fallback_value
		return

	var value: Variant = source_param.get_resolved_value()
	if param.bind_transform.is_valid():
		value = param.bind_transform.call(value)
	param.resolved_value = value


# ═══════════════════════════════════════════════════════════════════════════════
# Export Mappings (Post-MVP stub)
# ═══════════════════════════════════════════════════════════════════════════════

## Processes CHOP export mappings — pushes channel values to target parameters.
func _process_export_mappings() -> void:
	for mapping in network.export_mappings:
		# Each mapping: { source_node, source_channel, target_node, target_param, scale, offset, ... }
		# Post-MVP implementation — stub for now
		pass


# ═══════════════════════════════════════════════════════════════════════════════
# Expression Helper Functions (op, chop, top)
# ═══════════════════════════════════════════════════════════════════════════════

## Builds the callables that are injected into expression evaluation.
func _build_expression_helpers() -> void:
	_op_func = _make_op_proxy
	_chop_func = _make_chop_proxy
	_top_func = _make_top_proxy


## Returns a proxy dictionary for the given node (used inside expressions as op("name")).
func _make_op_proxy(node_name: String) -> Dictionary:
	if network == null:
		return {}
	var node: GNNode = network.nodes.get(node_name, null)
	if node == null:
		GNLogger.warn("CookEngine", "op('%s') — node not found" % node_name)
		return {}
	# Build a proxy dictionary with commonly accessed properties
	var par_dict := {}
	for p_name in node.parameters:
		par_dict[p_name] = node.parameters[p_name].get_resolved_value()
	return {
		"par": par_dict,
		"family": node.family,
		"cook_time": node.cook_time_ms,
		"valid": node.cook_valid,
	}


## Returns a proxy dictionary for CHOP access (used inside expressions as chop("name")).
func _make_chop_proxy(node_name: String) -> Dictionary:
	if network == null:
		return {}
	var node: GNNode = network.nodes.get(node_name, null)
	if node == null:
		GNLogger.warn("CookEngine", "chop('%s') — node not found" % node_name)
		return {}
	var data: GNData = node.cached_output
	if data == null or not data is GNChannelData:
		return {"value": func(_ch: String, _idx: int = -1) -> float: return 0.0}
	var ch_data: GNChannelData = data as GNChannelData
	return {
		"value": func(channel: String, index: int = -1) -> float:
			return ch_data.get_value(channel, index),
		"channels": ch_data.get_channel_names(),
		"length": ch_data.length,
		"sample_rate": ch_data.sample_rate,
	}


## Returns a proxy dictionary for TOP access (used inside expressions as top("name")).
func _make_top_proxy(node_name: String) -> Dictionary:
	if network == null:
		return {}
	var node: GNNode = network.nodes.get(node_name, null)
	if node == null:
		GNLogger.warn("CookEngine", "top('%s') — node not found" % node_name)
		return {}
	var data: GNData = node.cached_output
	if data == null or not data is GNTextureData:
		return {"resolution": Vector2i.ZERO, "aspect": 1.0}
	var tex_data: GNTextureData = data as GNTextureData
	return {
		"resolution": tex_data.resolution,
		"aspect": tex_data.get_aspect(),
	}


# ═══════════════════════════════════════════════════════════════════════════════
# Utility
# ═══════════════════════════════════════════════════════════════════════════════

## Marks all nodes in the network as dirty (forces full re-cook next frame).
func invalidate_all() -> void:
	if network == null:
		return
	for node_id in network.nodes:
		network.nodes[node_id].mark_dirty()
	GNLogger.info("CookEngine", "Invalidated all %d node(s)" % network.nodes.size())


## Resets the engine state (frame counter, time, etc.).
func reset() -> void:
	frame_count = 0
	elapsed_time = 0.0
	current_delta = 0.0
	frame_cook_time_ms = 0.0
	GNLogger.info("CookEngine", "Engine reset")
	invalidate_all()
