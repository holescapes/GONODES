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

## Absolute path to the project folder for resolving project:// paths.
## Set by the editor via GNProjectManager whenever a patch is saved/opened.
## Injected into each GNNode.project_dir before cooking.
var project_dir: String = ""

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

## Non-realtime mode — when true, uses a fixed timestep instead of wall-clock
## delta.  Every cook frame advances by exactly 1.0 / non_realtime_fps seconds,
## regardless of actual elapsed time.  This guarantees deterministic, frame-
## perfect recording with zero dropped frames — heavy patches that can't keep up
## in real-time produce identical output to lightweight ones.
var non_realtime: bool = false

## Target FPS for non-realtime mode.  Each cook frame advances virtual time by
## 1.0 / non_realtime_fps.  Typical values: 24 (film), 30 (NTSC), 60 (game).
var non_realtime_fps: float = 30.0

## Maximum nodes to cook per frame (0 = unlimited).
## Can be used to throttle heavy patches on low-end hardware.
var max_cooks_per_frame: int = 0

# ─── Hierarchy ─────────────────────────────────────────────────────────────────

## Parent cook engine (set by SubNetworkNode for inner cook engines).
## Enables `../` path resolution in expressions like `op("../lfo1")`.
var parent_engine: GNCookEngine = null

# ─── Expression Context ───────────────────────────────────────────────────────

## Tracks whether network nodes have been adopted into the scene tree.
var _nodes_adopted: bool = false

## Per-node cached input arrays — avoids per-frame allocation.
## Keyed by node id, value is Array[GNData] sized to input port count.
var _input_cache: Dictionary = {}

## Per-key state for the smooth() expression function.
var _smooth_state: Dictionary = {}

## Per-key state for the lag() expression function.
var _lag_state: Dictionary = {}

## Per-key state for the trigger() expression function.
var _trigger_state: Dictionary = {}

## Cached map of node_id → number of downstream consumers.
## Rebuilt when topology changes (_active_set_dirty also triggers rebuild).
var _consumer_counts: Dictionary = {}

## When true, _consumer_counts needs recomputing.
var _consumer_counts_dirty: bool = true

# ─── Active Chain Cooking ──────────────────────────────────────────────────────

## IDs of nodes that are live sinks (viewers, WindowTOPs, etc.).
## Set by the editor via [method set_active_sinks] when viewer targets change.
var active_sinks: Array[String] = []

## Cached set of node IDs in the active chain (fed from active_sinks).
## Rebuilt only when topology or sinks change (event-driven, not per-frame).
var _active_set: Dictionary = {}

## When true, _active_set needs recomputing. Set by topology/sink changes.
var _active_set_dirty: bool = true

## Regex for extracting node references from expressions.
## Matches chop("id"), op("id"), top("id"), sop("id"), dat("id"), mat("id").
static var _expr_ref_regex: RegEx = null

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

	# Non-realtime: fixed timestep — deterministic, frame-perfect timing
	if non_realtime:
		current_delta = 1.0 / non_realtime_fps
		elapsed_time += current_delta
	else:
		current_delta = delta
		elapsed_time += delta

	cook_frame(current_delta)


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
		# Listen for expression changes so active set includes referenced nodes
		if not node.parameter_changed.is_connected(_on_node_param_changed):
			node.parameter_changed.connect(_on_node_param_changed)
	# Wire signals for future dynamic node additions
	if not network.node_added.is_connected(_on_network_node_added):
		network.node_added.connect(_on_network_node_added)
	# Wire topology signals for active set invalidation
	if not network.node_removed.is_connected(_on_topology_changed):
		network.node_removed.connect(_on_topology_changed)
	if not network.connection_added.is_connected(_on_connection_changed):
		network.connection_added.connect(_on_connection_changed)
	if not network.connection_removed.is_connected(_on_connection_changed):
		network.connection_removed.connect(_on_connection_changed)
	_nodes_adopted = true
	GNLogger.info("CookEngine", "Adopted %d node(s) into scene tree" % adopted_count)


## Called when a node is dynamically added to the network at runtime.
func _on_network_node_added(node_id: String) -> void:
	var node: GNNode = network.nodes.get(node_id, null)
	if node and node.get_parent() == null:
		add_child(node)
		GNLogger.debug("CookEngine", "Dynamically adopted node '%s' (%s)" % [node_id, node.node_type])
	if node and not node.parameter_changed.is_connected(_on_node_param_changed):
		node.parameter_changed.connect(_on_node_param_changed)
	_active_set_dirty = true


## Called when any node's parameter changes (value or mode).
## Expression edits may change which nodes are referenced, so we
## invalidate the active set. This fires rarely (user interaction only).
func _on_node_param_changed(_node_id: String, _param_name: String) -> void:
	_active_set_dirty = true


## Called when a node is removed — invalidates the active set.
func _on_topology_changed(_arg: Variant = null) -> void:
	_active_set_dirty = true
	_consumer_counts_dirty = true


## Called when a connection is added or removed — invalidates the active set.
func _on_connection_changed(_arg: Variant = null) -> void:
	_active_set_dirty = true
	_consumer_counts_dirty = true


## Reorders this node's children so that GNNode instances appear in topological
## order.  Godot renders SubViewports in scene-tree (child-index) order, so
## upstream TOPs must be earlier children than downstream TOPs for their
## viewport textures to be available in the same render frame.
func _reorder_children_to_topo(topo_order: Array[GNNode]) -> void:
	var idx := 0
	for node in topo_order:
		if node.get_parent() != self:
			continue
		if node.get_index() != idx:
			move_child(node, idx)
		idx += 1


# ═══════════════════════════════════════════════════════════════════════════════
# Active Chain Cooking
# ═══════════════════════════════════════════════════════════════════════════════

## Sets the list of external sink node IDs (viewer targets, etc.)
## and marks the active set for recomputation.
func set_active_sinks(sinks: Array[String]) -> void:
	if sinks == active_sinks:
		return
	active_sinks = sinks
	_active_set_dirty = true


## Marks the active set for recomputation on the next cook frame.
## Called by the editor when viewer targets change, or internally
## when topology changes.
func invalidate_active_set() -> void:
	_active_set_dirty = true


## Computes the set of node IDs that feed into any active sink.
## Auto-detects structural sinks (nodes with [member GNNode.is_sink] = true)
## in addition to any UI sinks listed in [member active_sinks].
## Uses the network's cached adjacency map for O(N) traversal.
## Returns a Dictionary of { node_id: true } for O(1) lookup.
func _compute_active_set() -> Dictionary:
	var active: Dictionary = {}
	if network == null:
		return active

	# Seed the queue with externally-specified sinks (viewers, etc.)
	var queue: Array[String] = []
	for sink_id in active_sinks:
		if network.nodes.has(sink_id) and not active.has(sink_id):
			active[sink_id] = true
			queue.append(sink_id)

	# Auto-detect structural sinks inside the engine (editor-independent).
	# Any operator that sets is_sink = true in its _init() is included.
	# This covers WindowTOP, SpoutOut, MIDIOut, OSCOut, NDIOut, etc.
	for node_id in network.nodes:
		if active.has(node_id):
			continue
		var node: GNNode = network.nodes[node_id]
		if node.is_sink:
			active[node_id] = true
			queue.append(node_id)

	# If still no sinks at all, everything is active (safety fallback)
	if queue.is_empty():
		for node_id in network.nodes:
			active[node_id] = true
		return active

	# BFS upstream using cached adjacency (get_input_connections)
	# AND expression references (chop/op/top/sop/dat/mat calls).
	# Expression refs are implicit dependencies — if an active node reads
	# chop("lfo1", "out"), then lfo1 must also be active.
	while not queue.is_empty():
		var current_id: String = queue.pop_front()

		# Follow wire connections upstream
		var in_conns: Array = network.get_input_connections(current_id)
		for conn in in_conns:
			var upstream_id: String = conn.from_node
			if not active.has(upstream_id):
				active[upstream_id] = true
				queue.append(upstream_id)

		# Follow expression references (implicit dependencies)
		var expr_refs: Array[String] = _get_expression_refs(current_id)
		for ref_id in expr_refs:
			if network.nodes.has(ref_id) and not active.has(ref_id):
				active[ref_id] = true
				queue.append(ref_id)

	return active


## Extracts node IDs referenced in expressions of the given node.
## Scans all parameters for chop()/op()/top()/sop()/dat()/mat() calls.
func _get_expression_refs(node_id: String) -> Array[String]:
	var refs: Array[String] = []
	var node: GNNode = network.nodes.get(node_id, null)
	if node == null:
		return refs

	# Lazy-init regex (same pattern as GNGraphEditor's overlay scanner)
	if _expr_ref_regex == null:
		_expr_ref_regex = RegEx.new()
		_expr_ref_regex.compile("(?:chop|op|top|sop|dat|mat)\\s*\\(\\s*\"([^\"]+)\"")

	for param_name in node.parameters:
		var param: GNParameter = node.parameters[param_name]

		# Main expression
		if param.mode == GNParameter.Mode.EXPRESSION and param.expression != "":
			var results := _expr_ref_regex.search_all(param.expression)
			for m in results:
				var ref_id: String = m.get_string(1)
				if ref_id != node_id and not refs.has(ref_id):
					refs.append(ref_id)

		# Per-component expressions (Vector2/3/4, Color)
		for i in range(param.component_expressions.size()):
			if param.component_modes.size() > i and \
					param.component_modes[i] == GNParameter.Mode.EXPRESSION:
				var comp_expr: String = param.component_expressions[i]
				if comp_expr != "":
					var results := _expr_ref_regex.search_all(comp_expr)
					for m in results:
						var ref_id: String = m.get_string(1)
						if ref_id != node_id and not refs.has(ref_id):
							refs.append(ref_id)

	return refs


# ═══════════════════════════════════════════════════════════════════════════════
# Cook Loop
# ═══════════════════════════════════════════════════════════════════════════════

## Executes one full cook cycle for the current frame.
func cook_frame(delta: float) -> void:
	var frame_start := Time.get_ticks_usec()

	# Ensure all network nodes are adopted into the scene tree.
	# This is critical for sub-network inner cook engines where _process()
	# is disabled (cooking_enabled = false) and cook_frame() is called directly.
	if not _nodes_adopted:
		_adopt_network_nodes()

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

	# Step 3b: Recompute active chain only when topology or sinks changed.
	if _active_set_dirty:
		_active_set = _compute_active_set()
		for node in topo_order:
			node.is_active = _active_set.has(node.id)
		# Reorder scene-tree children to match topological order so that
		# upstream TOPs' SubViewports render before downstream ones within
		# the same frame.  Without this, viewports read stale/blank textures
		# when the creation order doesn't match the dependency order.
		_reorder_children_to_topo(topo_order)
		_active_set_dirty = false

	# Step 3c: Rebuild consumer counts when topology changed.
	if _consumer_counts_dirty:
		_rebuild_consumer_counts()

	# Step 4: Cook dirty + active nodes in topo order
	var cooked_count := 0
	var skipped_count := 0
	for node in topo_order:
		if not node.dirty:
			continue

		# Skip inactive nodes — they keep cached_output frozen
		if not node.is_active:
			skipped_count += 1
			continue

		# Inject timing context (so operators can use self.current_delta, etc.)
		node.current_delta = current_delta
		node.elapsed_time = elapsed_time
		node.current_frame = frame_count
		node.project_dir = project_dir

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
			if passthrough != null:
				passthrough._shared = _consumer_counts.get(node.id, 0) > 1
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

		# Tag the output as shared if this node feeds multiple downstream consumers.
		# Operators use _mutable_input() to check this flag before mutating data.
		if result != null:
			result._shared = _consumer_counts.get(node.id, 0) > 1

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
	GNLogger.debug("CookEngine", "Frame %d: cooked %d, skipped %d inactive in %.2fms" % [frame_count, cooked_count, skipped_count, frame_cook_time_ms])
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

## Rebuilds the per-node downstream consumer count from the connection topology.
## O(connections) — only runs when wires change, not every frame.
func _rebuild_consumer_counts() -> void:
	_consumer_counts.clear()
	if network == null:
		_consumer_counts_dirty = false
		return
	for conn in network.connections:
		var from_id: String = conn.from_node
		_consumer_counts[from_id] = _consumer_counts.get(from_id, 0) + 1
	_consumer_counts_dirty = false


## Gathers input data for a node from upstream nodes' cached outputs.
## Returns a flat array aligned by port index — each slot holds the upstream
## node's [code]cached_output[/code] or null if that port is disconnected.
## Dynamic-input nodes may have trailing null slots for empty auto-grow ports.
func _gather_inputs(node: GNNode) -> Array[GNData]:
	var inputs: Array[GNData]
	if _input_cache.has(node.id):
		inputs = _input_cache[node.id]
		# Resize if port count changed (dynamic inputs)
		if inputs.size() != node.input_ports.size():
			inputs.resize(node.input_ports.size())
		for i in range(inputs.size()):
			inputs[i] = null
	else:
		inputs = []
		inputs.resize(node.input_ports.size())
		_input_cache[node.id] = inputs

	for conn in network.get_input_connections(node.id):
		var upstream: GNNode = network.nodes.get(conn.from_node, null)
		if upstream and conn.to_port < inputs.size():
			var data: GNData = upstream.get_output_data(conn.from_port)
			if data != null:
				inputs[conn.to_port] = data
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
	var _t0 := Time.get_ticks_usec()
	var result = expr.execute(context, self)
	var _t1 := Time.get_ticks_usec()
	var eval_usec := float(_t1 - _t0)
	param.expression_eval_usec = eval_usec
	param.expression_eval_avg_usec = lerpf(param.expression_eval_avg_usec, eval_usec,
		GNParameter._PROFILE_ALPHA) if param.expression_eval_avg_usec > 0.0 else eval_usec

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

	# Ensure per-component timing array is sized
	if param.component_expression_eval_usec.size() != count:
		param.component_expression_eval_usec.resize(count)
		for ci in range(count):
			param.component_expression_eval_usec[ci] = 0.0

	for i in range(count):
		if param.component_modes[i] == GNParameter.Mode.EXPRESSION:
			var expr: Expression = param.get_compiled_component_expression(i)
			if expr == null:
				components[i] = param.get_component_value(i)
				continue
			var ct0 := Time.get_ticks_usec()
			var result = expr.execute(context, self)
			var ct1 := Time.get_ticks_usec()
			param.component_expression_eval_usec[i] = float(ct1 - ct0)
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
# Hierarchical Node Resolution
# ═══════════════════════════════════════════════════════════════════════════════

## Resolves a node path that may be hierarchical.
##
## Supported path forms:
##   "lfo1"                  → flat lookup in current network
##   "subnet1/noise1"        → dive into subnet1's inner network → noise1
##   "../lfo1"               → parent network → lfo1
##   "../../foo/bar"         → two levels up → into foo → bar
##   "/lfo1"                 → absolute path from root network
##
## Returns null if any segment cannot be resolved.
func resolve_node(path: String) -> GNNode:
	if path.is_empty() or network == null:
		return null

	# ── Absolute path: start from root engine ───────────────────────────
	if path.begins_with("/"):
		var root_engine := _get_root_engine()
		return root_engine.resolve_node(path.substr(1))

	var segments := path.split("/")
	var current_net: GNNetwork = network
	var current_eng: GNCookEngine = self

	for i in range(segments.size()):
		var seg: String = segments[i]
		if seg == "..":
			# Go up to parent
			if current_eng.parent_engine == null:
				GNLogger.warn("CookEngine", "resolve_node('%s') — no parent at segment %d" % [path, i])
				return null
			current_eng = current_eng.parent_engine
			current_net = current_eng.network
		elif seg == "." or seg == "":
			# Current level — skip
			continue
		else:
			var node: GNNode = current_net.nodes.get(seg, null)
			if node == null:
				GNLogger.warn("CookEngine", "resolve_node('%s') — '%s' not found at segment %d" % [path, seg, i])
				return null
			# If this is the last segment, return the node
			if i == segments.size() - 1:
				return node
# Otherwise, the node must own an inner_network to continue traversal.
			# Use duck typing to avoid cyclic class dependency with SubNetworkNode.
			if "inner_network" in node and "_inner_cook_engine" in node:
				var inner_net: GNNetwork = node.get("inner_network")
				var inner_eng: GNCookEngine = node.get("_inner_cook_engine")
				if inner_net == null or inner_eng == null:
					GNLogger.warn("CookEngine", "resolve_node('%s') — '%s' has no inner network" % [path, seg])
					return null
				current_net = inner_net
				current_eng = inner_eng
			else:
				GNLogger.warn("CookEngine", "resolve_node('%s') — '%s' is not a sub-network" % [path, seg])
				return null

	return null  # Should not reach here unless path is empty after parsing


## Walks the parent_engine chain to find the root cook engine.
func _get_root_engine() -> GNCookEngine:
	var eng: GNCookEngine = self
	while eng.parent_engine != null:
		eng = eng.parent_engine
	return eng


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
## Supports hierarchical paths: op("subnet1/noise1"), op("../lfo1"), op("/root_node").
func _make_op_proxy(node_name: String, param_name: String = "") -> Variant:
	if network == null:
		if not param_name.is_empty():
			return 0.0
		return {}
	var node: GNNode = resolve_node(node_name)
	if node == null:
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
	var node: GNNode = resolve_node(node_name)
	if node == null:
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
	var node: GNNode = resolve_node(node_name)
	if node == null:
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
# Built-in Expression Utility Functions
# ═══════════════════════════════════════════════════════════════════════════════
# These are callable directly in expressions: fit(v, 0, 1, -1, 1)

## Linearly remaps [param value] from [in_min..in_max] to [out_min..out_max].
## TouchDesigner-style fit(). Returns out_min if in_min == in_max.
func fit(value: float, in_min: float, in_max: float,
		out_min: float, out_max: float) -> float:
	if is_equal_approx(in_max, in_min):
		return out_min
	return out_min + (value - in_min) / (in_max - in_min) * (out_max - out_min)


## Remaps [param value] from [in_min..in_max] to [0..1].
func fit01(value: float, in_min: float, in_max: float) -> float:
	return fit(value, in_min, in_max, 0.0, 1.0)


## Exponential smoothing with per-key state.
## Returns a value that smoothly tracks [param target] over time.
## [param key] identifies the smoothing instance (use a unique string per usage).
## [param speed] controls convergence rate (higher = faster).
func smooth(key: String, target: float, speed: float = 5.0) -> float:
	if not _smooth_state.has(key):
		_smooth_state[key] = target
		return target
	var factor := clampf(speed * current_delta, 0.0, 1.0)
	_smooth_state[key] = lerpf(_smooth_state[key], target, factor)
	return _smooth_state[key]


## Asymmetric lag filter. [param up_speed] when target > current,
## [param down_speed] when target < current.
func lag(key: String, target: float,
		up_speed: float = 5.0, down_speed: float = 5.0) -> float:
	if not _lag_state.has(key):
		_lag_state[key] = target
		return target
	var current_val: float = _lag_state[key]
	var spd := up_speed if target > current_val else down_speed
	var factor := clampf(spd * current_delta, 0.0, 1.0)
	_lag_state[key] = lerpf(current_val, target, factor)
	return _lag_state[key]


## Pulse wave: returns 1.0 when fmod(phase, 1.0) < duty, else 0.0.
func pulse(phase: float, duty: float = 0.5) -> float:
	return 1.0 if fmod(absf(phase), 1.0) < duty else 0.0


## Step function: returns 1.0 if val >= edge, else 0.0.
func step(edge: float, val: float) -> float:
	return 1.0 if val >= edge else 0.0


## Hermite smoothstep interpolation between edge0 and edge1.
func smoothstep(edge0: float, edge1: float, x: float) -> float:
	if is_equal_approx(edge1, edge0):
		return 0.0 if x < edge0 else 1.0
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Cyclic 0→1 ramp with the given period (seconds).
func cycle(period: float) -> float:
	if period <= 0.0:
		return 0.0
	return fmod(elapsed_time, period) / period


## Bounce easing: abs(sin(t * PI)).
func bounce(t: float) -> float:
	return absf(sin(t * PI))


## Simple 1D value noise using sin-based hash. Returns ~[-1, 1].
func noise1(x: float) -> float:
	var ix := floorf(x)
	var fx := x - ix
	# Smooth interpolation
	fx = fx * fx * (3.0 - 2.0 * fx)
	var a := _hash1(ix)
	var b := _hash1(ix + 1.0)
	return lerpf(a, b, fx)


## Simple 2D value noise. Returns ~[-1, 1].
func noise2(x: float, y: float) -> float:
	var ix := floorf(x)
	var iy := floorf(y)
	var fx := x - ix
	var fy := y - iy
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := lerpf(_hash2(ix, iy), _hash2(ix + 1.0, iy), fx)
	var b := lerpf(_hash2(ix, iy + 1.0), _hash2(ix + 1.0, iy + 1.0), fx)
	return lerpf(a, b, fy)


## Trigger detection: returns 1.0 on the frame [param value] crosses above
## [param threshold], 0.0 otherwise. Uses per-key state.
func trigger(key: String, value: float, threshold: float = 0.5) -> float:
	var prev: float = _trigger_state.get(key, 0.0)
	_trigger_state[key] = value
	return 1.0 if prev < threshold and value >= threshold else 0.0


## Dispatch to a user-defined custom function registered via GNExpressionFunctions.
## Usage: fn("my_func", arg1, arg2, ...)
func fn(func_name: String, a = null, b = null, c = null,
		d = null, e = null, f = null) -> Variant:
	var args: Array = []
	for arg in [a, b, c, d, e, f]:
		if arg == null:
			break
		args.append(arg)
	return GNExpressionFunctions.call_func(func_name, args)


# ─── Noise Helpers (internal) ────────────────────────────────────────────────

func _hash1(n: float) -> float:
	return fmod(sin(n * 127.1) * 43758.5453, 1.0) * 2.0 - 1.0


func _hash2(x: float, y: float) -> float:
	return fmod(sin(x * 127.1 + y * 311.7) * 43758.5453, 1.0) * 2.0 - 1.0


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
	_smooth_state.clear()
	_lag_state.clear()
	_trigger_state.clear()
	_active_set.clear()
	_active_set_dirty = true
	_consumer_counts.clear()
	_consumer_counts_dirty = true
	GNLogger.info("CookEngine", "Engine reset")
	invalidate_all()
