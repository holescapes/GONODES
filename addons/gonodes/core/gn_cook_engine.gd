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

## Tracks whether network nodes have been adopted into the scene tree.
var _nodes_adopted: bool = false

## Per-node cached input arrays — avoids per-frame allocation.
## Keyed by node id, value is Array[GNData] sized to input port count.
var _input_cache: Dictionary = {}

# ─── Signals ───────────────────────────────────────────────────────────────────

## Emitted after all nodes in a frame have been cooked.
signal frame_cooked(frame: int, cook_time_ms: float)

## Emitted when a cook error occurs on a specific node.
signal cook_error(node_id: String, error_message: String)


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
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

	# Step 3: Propagate dirty flags downstream BEFORE cooking.
	# This ensures all affected nodes are marked dirty in one pass,
	# eliminating redundant BFS calls during the cook loop.
	for node in topo_order:
		if node.dirty:
			network.propagate_dirty(node.id)

	# Step 4: Cook dirty nodes in topo order
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

		# Bypass: pass first input through without cooking
		if node.bypass:
			var passthrough: GNData = null
			for inp in inputs:
				if inp != null:
					passthrough = inp
					break
			node.cached_output = passthrough
			node.cook_valid = passthrough != null
			node.cook_time_ms = 0.0
			node.clear_dirty()
			node.node_cooked.emit(node.id)
			cooked_count += 1
			if max_cooks_per_frame > 0 and cooked_count >= max_cooks_per_frame:
				break
			continue

		# Cook the node
		var result := node.execute_cook(inputs, frame_count)

		if result == null and node.output_ports.size() > 0 and node.family != GNFamily.Type.COMP:
			# Only warn for non-COMP nodes with output ports.
			# Sink nodes (e.g., WindowTOP) legitimately return null.
			# COMPs (Camera, Light) return null — their outputs are scene graph nodes, not data.
			GNLogger.warn("CookEngine", "Node '%s' (%s) cook returned null" % [node.id, node.node_type])
			cook_error.emit(node.id, "cook returned null")
		else:
			GNLogger.debug("CookEngine", "Cooked '%s' (%s) in %.3fms" % [node.id, node.node_type, node.cook_time_ms])

		cooked_count += 1
		if max_cooks_per_frame > 0 and cooked_count >= max_cooks_per_frame:
			break

	# Step 5: Process export mappings (post-MVP, CHOP exports push values)
	_process_export_mappings()

	# Step 6: Frame bookkeeping
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
## For single-input ports, returns a flat array aligned by port index.
## For multi-input ports, collects all connections into an array at that slot.
func _gather_inputs(node: GNNode) -> Array[GNData]:
	# Check if any port is multi-input
	var has_multi: bool = false
	for port in node.input_ports:
		if port.multi_input:
			has_multi = true
			break

	if not has_multi:
		# Fast path: simple single-input ports (most operators)
		var inputs: Array[GNData]
		if _input_cache.has(node.id):
			inputs = _input_cache[node.id]
			for i in range(inputs.size()):
				inputs[i] = null
		else:
			inputs = []
			inputs.resize(node.input_ports.size())
			_input_cache[node.id] = inputs

		for conn in network.get_input_connections(node.id):
			var upstream: GNNode = network.nodes.get(conn.from_node, null)
			if upstream and upstream.cached_output and conn.to_port < inputs.size():
				inputs[conn.to_port] = upstream.cached_output
		return inputs

	# Multi-input path: collect all upstream data per multi-input port into a flat array
	# E.g., MergeSOP with 5 connections on port 0 → inputs array has 5 elements
	var multi_data: Array[GNData] = []
	for conn in network.get_input_connections(node.id):
		var upstream: GNNode = network.nodes.get(conn.from_node, null)
		if upstream and upstream.cached_output:
			multi_data.append(upstream.cached_output)
	return multi_data


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
				if param.is_multi_component() and param.has_any_component_expression():
					_evaluate_component_expressions(node, param)
				else:
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

	# Build the context array matching the input variable names:
	# ["me", "time", "frame", "dt"]
	# chop(), op(), top() are called as methods on the base_instance (self).
	var context := [
		node,           # me — the current node
		elapsed_time,   # time — seconds since start
		frame_count,    # frame — current frame number
		current_delta,  # dt — delta time this frame
	]

	# Pass self (CookEngine) as base_instance so Expression can call
	# our chop(), op(), top() methods directly.
	var result = expr.execute(context, self)

	if expr.has_execute_failed():
		GNLogger.error("CookEngine", "Expression error on %s.%s — %s" % [
			node.id, param.param_name, expr.get_error_text()])
		param.resolved_value = param.fallback_value
		cook_error.emit(node.id, "Expression error: %s" % expr.get_error_text())
	else:
		param.resolved_value = result
		param.fallback_value = result  # Update fallback for next failure


## Evaluates per-component expressions for multi-dimensional parameters.
## Each component is resolved independently: CONSTANT components keep their
## stored value, EXPRESSION components are evaluated (must return float/int).
## The final resolved_value is assembled from all components.
func _evaluate_component_expressions(node: GNNode, param: GNParameter) -> void:
	var count := param.get_component_count()
	var components: Array[float] = []
	components.resize(count)

	var context := [
		node,           # me
		elapsed_time,   # time
		frame_count,    # frame
		current_delta,  # dt
	]

	for i in range(count):
		if param.component_modes[i] == GNParameter.Mode.EXPRESSION:
			var expr: Expression = param.get_compiled_component_expression(i)
			if expr == null:
				components[i] = param.get_component_value(i)
				continue
			var result = expr.execute(context, self)
			if expr.has_execute_failed():
				var labels := param.get_component_labels()
				var label_str: String = labels[i] if i < labels.size() else str(i)
				GNLogger.error("CookEngine", "Expression error on %s.%s[%s] — %s" % [
					node.id, param.param_name, label_str, expr.get_error_text()])
				components[i] = param.get_component_value(i)
			else:
				components[i] = float(result)
		else:
			# CONSTANT — use stored component value
			components[i] = param.get_component_value(i)

	# Assemble the final value from components
	match param.value_type:
		GNParameter.ValueType.VECTOR2:
			param.resolved_value = Vector2(components[0], components[1])
		GNParameter.ValueType.VECTOR2I:
			param.resolved_value = Vector2i(int(components[0]), int(components[1]))
		GNParameter.ValueType.VECTOR3:
			param.resolved_value = Vector3(components[0], components[1], components[2])
		GNParameter.ValueType.VECTOR4:
			param.resolved_value = Vector4(components[0], components[1], components[2], components[3])
		GNParameter.ValueType.COLOR:
			param.resolved_value = Color(components[0], components[1], components[2], components[3])
	param.fallback_value = param.resolved_value


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
# Expression Helper Methods — called by Expression base_instance
# These are real methods so Godot's Expression class can call them
# directly: chop("lfo1", "out"), op("noise1", "scale"), etc.
# ═════════════════════════════════════════════════════════════════════════════

## Read a CHOP channel value. Called by Expression as chop("lfo1", "out").
func chop(node_name: String, channel: String = "", index: int = -1) -> Variant:
	return _make_chop_proxy(node_name, channel, index)


## Read a node's parameter. Called by Expression as op("noise1", "scale").
func op(node_name: String, param_name: String = "") -> Variant:
	return _make_op_proxy(node_name, param_name)


## Read TOP info. Called by Expression as top("noise1", "resolution").
func top(node_name: String, property: String = "") -> Variant:
	return _make_top_proxy(node_name, property)


# ─── Internal proxy implementations ─────────────────────────────────────────────


## Returns a proxy dictionary for the given node (used inside expressions as op("name")).
## Can also be called as op("name", "param") to get a parameter value directly.
func _make_op_proxy(node_name: String, param_name: String = "") -> Variant:
	if network == null:
		if not param_name.is_empty():
			return 0.0
		return {}
	var node: GNNode = network.nodes.get(node_name, null)
	if node == null:
		GNLogger.warn("CookEngine", "op('%s') — node not found" % node_name)
		if not param_name.is_empty():
			return 0.0
		return {}
	# If a param name was given, return its value directly
	if not param_name.is_empty():
		var param: GNParameter = node.parameters.get(param_name, null)
		if param:
			return param.get_resolved_value()
		return 0.0
	# Otherwise return a proxy dict
	var par_dict := {}
	for p_name in node.parameters:
		par_dict[p_name] = node.parameters[p_name].get_resolved_value()
	return {
		"par": par_dict,
		"family": node.family,
		"cook_time": node.cook_time_ms,
		"valid": node.cook_valid,
	}


## Returns a CHOP channel value. Usage in expressions:
##   chop("lfo1", "out")           → float (latest sample)
##   chop("lfo1", "out", 0)        → float (sample at index 0)
##   chop("lfo1")                  → Dictionary with channel info (advanced)
func _make_chop_proxy(node_name: String, channel: String = "", index: int = -1) -> Variant:
	if network == null:
		if not channel.is_empty():
			return 0.0
		return {}
	var node: GNNode = network.nodes.get(node_name, null)
	if node == null:
		GNLogger.warn("CookEngine", "chop('%s') — node not found" % node_name)
		if not channel.is_empty():
			return 0.0
		return {}
	var data: GNData = node.cached_output
	if data == null or not data is GNChannelData:
		if not channel.is_empty():
			return 0.0
		return {}
	var ch_data: GNChannelData = data as GNChannelData
	# If a channel name was given, return the value directly
	if not channel.is_empty():
		return ch_data.get_value(channel, index)
	# Otherwise return a dict with channel info
	return {
		"channels": ch_data.get_channel_names(),
		"length": ch_data.length,
		"sample_rate": ch_data.sample_rate,
	}


## Returns TOP info. Usage in expressions:
##   top("noise1", "resolution")   → Vector2i
##   top("noise1", "aspect")       → float
##   top("noise1")                 → Dictionary with all info
func _make_top_proxy(node_name: String, property: String = "") -> Variant:
	if network == null:
		if not property.is_empty():
			return 0.0
		return {}
	var node: GNNode = network.nodes.get(node_name, null)
	if node == null:
		GNLogger.warn("CookEngine", "top('%s') — node not found" % node_name)
		if not property.is_empty():
			return 0.0
		return {}
	var data: GNData = node.cached_output
	if data == null or not data is GNTextureData:
		if not property.is_empty():
			return 0.0
		return {"resolution": Vector2i.ZERO, "aspect": 1.0}
	var tex_data: GNTextureData = data as GNTextureData
	var info := {
		"resolution": tex_data.resolution,
		"aspect": tex_data.get_aspect(),
	}
	if not property.is_empty():
		return info.get(property, 0.0)
	return info


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
