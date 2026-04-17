class_name GNNetwork
extends Resource
## The graph model for a GONODES node network.
## Manages nodes, connections, topological ordering, and cycle detection.
## This is a pure data model — no rendering or UI logic.

# ─── Data ──────────────────────────────────────────────────────────────────────

## The GNNode that owns this network as its inner network (e.g. SubNetworkNode).
## null for the root-level network.
var host_node: GNNode = null

## All nodes in this network, keyed by their unique ID.
var nodes: Dictionary = {}

## All wire connections between node ports.
var connections: Array[GNConnection] = []

## Canvas annotations — network boxes and sticky notes for organization.
## Each entry is a Dictionary with keys:
##   "id": String (unique), "type": "box"|"note",
##   "position": Vector2, "size": Vector2,
##   "text": String, "color": Color
var annotations: Array[Dictionary] = []

## Counter for generating unique annotation IDs.
var _annotation_counter: int = 0

## Cached topological order — invalidated when graph structure changes.
var _topo_cache: Array[GNNode] = []
var _topo_dirty: bool = true

## Cached adjacency maps — rebuilt when graph structure changes.
## _downstream_map: node_id → Array of downstream node_ids (for dirty propagation)
## _input_conn_map: node_id → Array[GNConnection] (for input gathering)
## _output_conn_map: node_id → Array[GNConnection] (for demand-based output cooking)
var _downstream_map: Dictionary = {}
var _input_conn_map: Dictionary = {}
var _output_conn_map: Dictionary = {}
var _adjacency_dirty: bool = true

# ─── Signals ───────────────────────────────────────────────────────────────────

## Emitted when a node is added to the network.
signal node_added(node_id: String)

## Emitted when a node is removed from the network.
signal node_removed(node_id: String)

## Emitted when a connection is created.
signal connection_added(connection: GNConnection)

## Emitted when a connection is removed.
signal connection_removed(connection: GNConnection)

## Emitted when serialized state changes (structure, connections, renames,
## parameter edits, widget interaction).  The editor listens to this for
## unsaved-changes tracking.  Prefer calling [method notify_state_changed]
## over emitting directly.
## [param undoable] is true when the change was recorded in the undo stack.
signal graph_changed(undoable: bool)

## Emitted when a node is renamed.
signal node_renamed(old_id: String, new_id: String)


## Central bottleneck for all serializable state changes.
## [param undoable] — true when this change is tracked by the undo stack
## (structural edits, parameter changes).  false for ephemeral user state
## (widget interaction) that bypasses undo.
func notify_state_changed(undoable: bool = true) -> void:
	graph_changed.emit(undoable)


# ═══════════════════════════════════════════════════════════════════════════════
# Node Management
# ═══════════════════════════════════════════════════════════════════════════════

## Adds a node to the network.  The node must already be initialized with a unique ID.
## Returns true on success, false if the ID is already taken.
func add_node(node: GNNode) -> bool:
	if node.id.is_empty():
		push_error("GNNetwork.add_node: node has no ID")
		return false
	if nodes.has(node.id):
		push_warning("GNNetwork.add_node: duplicate ID '%s'" % node.id)
		return false
	nodes[node.id] = node
	_invalidate_topo()
	GNLogger.info("Network", "Node added: '%s' (%s/%s)" % [node.id, GNFamily.get_family_name(node.family), node.node_type])
	node_added.emit(node.id)
	notify_state_changed()
	return true


## Removes a node and all its connections from the network.
## Since GNNode extends Node, this also removes it from the scene tree
## and queues it for deletion.
func remove_node(node_id: String) -> bool:
	if not nodes.has(node_id):
		push_warning("GNNetwork.remove_node: node '%s' not found" % node_id)
		return false

	var node: GNNode = nodes[node_id]

	# Remove all connections involving this node
	var to_remove: Array[GNConnection] = []
	for conn in connections:
		if conn.from_node == node_id or conn.to_node == node_id:
			to_remove.append(conn)
	for conn in to_remove:
		connections.erase(conn)
		connection_removed.emit(conn)

	nodes.erase(node_id)
	_invalidate_topo()
	GNLogger.info("Network", "Node removed: '%s' (removed %d connection(s))" % [node_id, to_remove.size()])
	node_removed.emit(node_id)
	notify_state_changed()

	# Clean up the Node from the scene tree (children like SubViewports are freed too)
	if node.is_inside_tree():
		node.get_parent().remove_child(node)
	node.queue_free()
	return true


## Returns the node with the given ID, or null if not found.
func get_node_by_id(node_id: String) -> GNNode:
	return nodes.get(node_id, null)


## Generates a unique node ID based on the type name (e.g., "noise1", "noise2", ...).
func generate_unique_id(base_type: String) -> String:
	var counter := 1
	var candidate := base_type + str(counter)
	while nodes.has(candidate):
		counter += 1
		candidate = base_type + str(counter)
	return candidate


## Renames a node, updating the nodes dictionary, all connections, and
## expression references across the entire network.
## Returns true on success, false if old_id not found or new_id already taken.
func rename_node(old_id: String, new_id: String) -> bool:
	if old_id == new_id:
		return true
	if not nodes.has(old_id):
		push_warning("GNNetwork.rename_node: node '%s' not found" % old_id)
		return false
	if new_id.is_empty():
		push_warning("GNNetwork.rename_node: new ID is empty")
		return false
	if nodes.has(new_id):
		push_warning("GNNetwork.rename_node: ID '%s' already taken" % new_id)
		return false

	# Validate: only allow alphanumeric + underscore
	var valid_regex := RegEx.new()
	valid_regex.compile("^[a-zA-Z_][a-zA-Z0-9_]*$")
	if not valid_regex.search(new_id):
		push_warning("GNNetwork.rename_node: invalid ID '%s' (must be alphanumeric/underscore, start with letter or _)" % new_id)
		return false

	var node: GNNode = nodes[old_id]

	# Update nodes dictionary
	nodes.erase(old_id)
	node.id = new_id
	node.name = new_id
	nodes[new_id] = node

	# Update all connections referencing this node
	for conn in connections:
		if conn.from_node == old_id:
			conn.from_node = new_id
		if conn.to_node == old_id:
			conn.to_node = new_id

	# Update expression references across all nodes in the network.
	# Regex-based: catches chop/op/top/sop/dat/mat/par/set_par references
	# and handles hierarchical paths containing the old ID as a segment.
	_update_expressions_for_rename(old_id, new_id)

	# Update wireless node-reference string parameters (Select operators,
	# ParameterCHOP, etc.) that store the old node ID by name.
	_update_wireless_refs_for_rename(old_id, new_id)

	_invalidate_topo()
	GNLogger.info("Network", "Node renamed: '%s' → '%s'" % [old_id, new_id])
	node_renamed.emit(old_id, new_id)
	notify_state_changed()
	return true


## Node types whose "code" parameter contains GDScript with node references.
## After the script consolidation, all GDScript scripting uses the unified
## "script" node_type (GDScriptSCRIPT).
var _SCRIPT_NODE_TYPES: PackedStringArray = PackedStringArray([
	"script",
])

## CallbackDAT code parameters (multiple script slots, not "code").
var _CALLBACK_CODE_PARAMS: PackedStringArray = PackedStringArray([
	"on_start", "on_cook", "on_value_change", "on_create",
])


## Updates all expression strings and script code bodies across the network
## when a node is renamed.  Uses regex to match the old ID inside quoted
## strings (first argument of node-reference functions and hierarchical paths).
func _update_expressions_for_rename(old_id: String, new_id: String) -> void:
	# Build a regex that matches the old_id inside quoted strings:
	#   1. As a standalone ID:   "old_id"
	#   2. As a path segment:    "something/old_id"  or  "old_id/something"
	var esc_old := old_id.replace(".", "\\.").replace("-", "\\-")
	var re := RegEx.new()
	# Match "old_id" as a complete ID or as a path segment within quotes.
	# We replace the ID portion while preserving surrounding path segments.
	# Approach: find all "...old_id..." in quoted strings and do targeted replacement.
	re.compile('\"([^\"]*)\"')

	for n_id in nodes:
		var n: GNNode = nodes[n_id]
		for param_name in n.parameters:
			var param: GNParameter = n.parameters[param_name]

			# Main expression
			if param.mode == GNParameter.Mode.EXPRESSION and not param.expression.is_empty():
				var updated := _replace_id_in_expr(param.expression, old_id, new_id)
				if updated != param.expression:
					param.set_expression(updated)

			# Per-component expressions (Vector2/3/4, Color)
			for i in range(param.component_expressions.size()):
				if param.component_modes.size() > i and \
						param.component_modes[i] == GNParameter.Mode.EXPRESSION:
					var comp_expr: String = param.component_expressions[i]
					if not comp_expr.is_empty():
						var updated := _replace_id_in_expr(comp_expr, old_id, new_id)
						if updated != comp_expr:
							param.component_expressions[i] = updated
							param._compile_component_expression(i)

		# Script operator code bodies — update node references in GDScript source
		if n.node_type in _SCRIPT_NODE_TYPES:
			var code_param: GNParameter = n.parameters.get("code", null)
			if code_param != null:
				var code_val: String = code_param.value if code_param.value is String else ""
				if not code_val.is_empty() and old_id in code_val:
					var updated := _replace_id_in_expr(code_val, old_id, new_id)
					if updated != code_val:
						n.set_param_value("code", updated)

		# CallbackDAT — multiple script slots
		if n.node_type == "callbackdat":
			for cb_param_name in _CALLBACK_CODE_PARAMS:
				var cb_param: GNParameter = n.parameters.get(cb_param_name, null)
				if cb_param != null:
					var cb_val: String = cb_param.value if cb_param.value is String else ""
					if not cb_val.is_empty() and old_id in cb_val:
						var updated := _replace_id_in_expr(cb_val, old_id, new_id)
						if updated != cb_val:
							n.set_param_value(cb_param_name, updated)


## Replaces a node ID within quoted strings in an expression or code body.
## Handles standalone IDs ("old_id") and path segments ("prefix/old_id",
## "old_id/suffix", "a/old_id/b").  Does NOT touch unquoted occurrences
## or IDs that are substrings of longer identifiers within the same segment.
func _replace_id_in_expr(text: String, old_id: String, new_id: String) -> String:
	var re := RegEx.new()
	# Match old_id as a complete path segment inside double-quoted strings.
	# (?<=")        — after opening quote (or after /)
	# (?:^|(?<=/))  — either start of string-content or after path separator
	# old_id        — the exact old node ID
	# (?:(?=/)|$)   — followed by path separator or before closing quote
	# We process each quoted string individually to be safe.
	re.compile('"([^"]*)"')
	var result := text
	var offset := 0
	for m in re.search_all(text):
		var full_match: String = m.get_string(0)
		var inner: String = m.get_string(1)
		var new_inner := _replace_path_segment(inner, old_id, new_id)
		if new_inner != inner:
			var new_full := '"%s"' % new_inner
			var start_pos: int = m.get_start(0) + offset
			result = result.substr(0, start_pos) + new_full + result.substr(start_pos + full_match.length())
			offset += new_full.length() - full_match.length()
	return result


## Replaces old_id as a complete path segment (split by "/") in a path string.
## "lfo1" → matches "lfo1", "subnet/lfo1", "lfo1/inner", "a/lfo1/b"
## Also handles "old_id:channel" channel-reference prefixes (e.g. "drag1:top_left_x").
## Does NOT match "lfo10" or "my_lfo1" (must be exact segment).
func _replace_path_segment(path: String, old_id: String, new_id: String) -> String:
	var segments := path.split("/")
	var changed := false
	for i in range(segments.size()):
		if segments[i] == old_id:
			segments[i] = new_id
			changed = true
		elif segments[i].begins_with(old_id + ":"):
			segments[i] = new_id + segments[i].substr(old_id.length())
			changed = true
	if changed:
		return "/".join(segments)
	return path


## Updates node-reference string parameters across the entire network when a
## node is renamed.  Covers Select operators (wireless "top"/"chop"/etc.),
## ParameterCHOP ("node_path"), ObjectMergeSOP ("sop_path"),
## ObjectCHOP/SkeletonCHOP ("comp_path"), RenderPickDAT ("render_comp"),
## PanelExecuteDAT ("panel_path"), and any future operator that overrides
## get_node_reference_params().
func _update_wireless_refs_for_rename(old_id: String, new_id: String) -> void:
	for n_id in nodes:
		var n: GNNode = nodes[n_id]
		var ref_params: Dictionary = n.get_node_reference_params()
		for param_name in ref_params:
			var param: GNParameter = n.parameters.get(param_name, null)
			if param == null:
				continue
			var val: String = str(param.value)
			if val == old_id:
				n.set_param_value(param_name, new_id)
			elif "/" in val:
				# Handle hierarchical paths: "subnet/old_id" → "subnet/new_id"
				var updated := _replace_path_segment(val, old_id, new_id)
				if updated != val:
					n.set_param_value(param_name, updated)


# ═══════════════════════════════════════════════════════════════════════════════
# Connection Management
# ═══════════════════════════════════════════════════════════════════════════════

## Creates a connection between two node ports.
## Returns true on success. Fails if: nodes don't exist, ports are incompatible,
## input already occupied (non-multi), or it would create a cycle.
func connect_nodes(from_id: String, from_port: int,
		to_id: String, to_port: int) -> bool:
	# Validate nodes exist
	var from_node: GNNode = nodes.get(from_id, null)
	var to_node: GNNode = nodes.get(to_id, null)
	if from_node == null:
		push_warning("GNNetwork.connect: source node '%s' not found" % from_id)
		return false
	if to_node == null:
		push_warning("GNNetwork.connect: target node '%s' not found" % to_id)
		return false

	# Validate ports exist
	var out_port: GNPort = from_node.get_output_port(from_port)
	var in_port: GNPort = to_node.get_input_port(to_port)
	if out_port == null:
		push_warning("GNNetwork.connect: output port %d not found on '%s'" % [from_port, from_id])
		return false
	if in_port == null:
		push_warning("GNNetwork.connect: input port %d not found on '%s'" % [to_port, to_id])
		return false

	# Type check
	if not in_port.can_connect_from(out_port):
		push_warning("GNNetwork.connect: port type mismatch (%s → %s)" % [
			GNFamily.get_family_name(out_port.family), GNFamily.get_family_name(in_port.family)])
		return false

	# Each input port accepts exactly one connection — auto-replace any existing wire
	var replaced_conn: GNConnection = null
	for conn in connections:
		if conn.to_node == to_id and conn.to_port == to_port:
			replaced_conn = conn
			break

	if replaced_conn != null:
		# Disconnect the old wire so the new one can take its place
		connections.erase(replaced_conn)
		_invalidate_topo()
		var old_to_node: GNNode = nodes.get(to_id, null)
		if old_to_node:
			old_to_node.mark_dirty()
		GNLogger.info("Network", "Auto-replaced connection %s:%d → %s:%d" % [
			replaced_conn.from_node, replaced_conn.from_port,
			replaced_conn.to_node, replaced_conn.to_port])
		connection_removed.emit(replaced_conn)

		# Auto-shrink dynamic inputs after removing the old wire
		if old_to_node and old_to_node._dynamic_input:
			_update_dynamic_node_inputs(to_id)

	# Check for duplicate connection
	for conn in connections:
		if conn.matches(from_id, from_port, to_id, to_port):
			push_warning("GNNetwork.connect: connection already exists")
			return false

	# Cycle check — temporarily add the edge and test
	var test_conn := GNConnection.create(from_id, from_port, to_id, to_port)
	connections.append(test_conn)
	if has_cycle():
		connections.erase(test_conn)
		GNLogger.warn("Network", "Connection %s:%d → %s:%d rejected — would create cycle" % [from_id, from_port, to_id, to_port])
		push_warning("GNNetwork.connect: would create a cycle")
		return false

	# Connection is valid and already added
	_invalidate_topo()
	to_node.mark_dirty()
	GNLogger.info("Network", "Connected %s:%d → %s:%d" % [from_id, from_port, to_id, to_port])
	connection_added.emit(test_conn)
	notify_state_changed()

	# Auto-grow dynamic input ports (adds a trailing empty slot)
	if to_node._dynamic_input:
		_update_dynamic_node_inputs(to_id)

	return true


## Removes a specific connection.
func disconnect_nodes(from_id: String, from_port: int,
		to_id: String, to_port: int) -> bool:
	for i in range(connections.size()):
		if connections[i].matches(from_id, from_port, to_id, to_port):
			var conn := connections[i]
			connections.remove_at(i)
			_invalidate_topo()
			# Mark the target node dirty since its input changed
			var to_node: GNNode = nodes.get(to_id, null)
			if to_node:
				to_node.mark_dirty()
			GNLogger.info("Network", "Disconnected %s:%d → %s:%d" % [from_id, from_port, to_id, to_port])
			connection_removed.emit(conn)
			notify_state_changed()

			# Auto-shrink dynamic input ports (collapse trailing empties)
			if to_node and to_node._dynamic_input:
				_update_dynamic_node_inputs(to_id)

			return true
	push_warning("GNNetwork.disconnect: connection not found")
	return false


## Returns all connections feeding into a specific node.
## Uses cached input-connection map for O(1) lookup.
func get_input_connections(node_id: String) -> Array:
	_rebuild_adjacency()
	return _input_conn_map.get(node_id, [])


## Recalculates dynamic input port count for a node based on which ports
## currently have connections.  Ensures exactly one trailing empty slot.
func _update_dynamic_node_inputs(node_id: String) -> void:
	var node: GNNode = nodes.get(node_id, null)
	if node == null or not node._dynamic_input:
		return
	var connected: PackedInt32Array = []
	for conn in connections:
		if conn.to_node == node_id:
			connected.append(conn.to_port)
	node.update_dynamic_inputs(connected)


## Returns all connections going out from a specific node.
func get_output_connections(node_id: String) -> Array[GNConnection]:
	var result: Array[GNConnection] = []
	for conn in connections:
		if conn.from_node == node_id:
			result.append(conn)
	return result


## Returns the connection feeding a specific input port, or null.
func get_connection_at_input(node_id: String, port_index: int) -> GNConnection:
	for conn in connections:
		if conn.to_node == node_id and conn.to_port == port_index:
			return conn
	return null


## Removes any connections whose port index exceeds the node's current port count.
## Called after a node rebuilds its ports (dynamic port count change).
## Returns the number of pruned connections.
func prune_stale_connections(node_id: String) -> int:
	var node: GNNode = nodes.get(node_id, null)
	if node == null:
		return 0

	var in_count := node.input_ports.size()
	var out_count := node.output_ports.size()
	var stale: Array[GNConnection] = []

	for conn in connections:
		if conn.to_node == node_id and conn.to_port >= in_count:
			stale.append(conn)
		elif conn.from_node == node_id and conn.from_port >= out_count:
			stale.append(conn)

	for conn in stale:
		connections.erase(conn)
		connection_removed.emit(conn)

	if stale.size() > 0:
		_invalidate_topo()
		notify_state_changed()
		GNLogger.info("Network", "Pruned %d stale connection(s) on '%s'" % [stale.size(), node_id])
	return stale.size()


# ═══════════════════════════════════════════════════════════════════════════════
# Graph Queries
# ═══════════════════════════════════════════════════════════════════════════════

## Returns all nodes directly upstream of the given node (connected to its inputs).
func get_upstream_nodes(node_id: String) -> Array[GNNode]:
	var result: Array[GNNode] = []
	for conn in connections:
		if conn.to_node == node_id:
			var upstream: GNNode = nodes.get(conn.from_node, null)
			if upstream and upstream not in result:
				result.append(upstream)
	return result


## Returns all nodes directly downstream of the given node (it feeds into them).
func get_downstream_nodes(node_id: String) -> Array[GNNode]:
	var result: Array[GNNode] = []
	for conn in connections:
		if conn.from_node == node_id:
			var downstream: GNNode = nodes.get(conn.to_node, null)
			if downstream and downstream not in result:
				result.append(downstream)
	return result


## Returns all nodes that are dirty in the network.
func get_dirty_nodes() -> Array[GNNode]:
	var result: Array[GNNode] = []
	for node_id in nodes:
		var node: GNNode = nodes[node_id]
		if node.dirty:
			result.append(node)
	return result


# ═══════════════════════════════════════════════════════════════════════════════
# Topological Sort & Cycle Detection
# ═══════════════════════════════════════════════════════════════════════════════

## Returns all nodes in topological cook order (upstream first).
## Uses Kahn's algorithm (BFS-based). Result is cached until the graph changes.
func get_topological_order() -> Array[GNNode]:
	if not _topo_dirty:
		return _topo_cache
	_topo_cache = _compute_topological_order()
	_topo_dirty = false
	return _topo_cache


## Returns true if the graph contains a cycle.
## Uses DFS coloring (white/gray/black).
func has_cycle() -> bool:
	# WHITE=0 (unvisited), GRAY=1 (in progress), BLACK=2 (done)
	var color: Dictionary = {}
	for node_id in nodes:
		color[node_id] = 0

	for node_id in nodes:
		if color[node_id] == 0:
			if _dfs_has_cycle(node_id, color):
				return true
	return false


## Computes topological order using Kahn's algorithm.
func _compute_topological_order() -> Array[GNNode]:
	# Build adjacency and in-degree maps
	var in_degree: Dictionary = {}
	var adjacency: Dictionary = {}  # node_id -> Array of downstream node_ids
	for node_id in nodes:
		in_degree[node_id] = 0
		adjacency[node_id] = []

	for conn in connections:
		if nodes.has(conn.from_node) and nodes.has(conn.to_node):
			adjacency[conn.from_node].append(conn.to_node)
			in_degree[conn.to_node] += 1

	# Expression reference edges — if node B reads node A via chop()/par()/op(),
	# A must cook before B so B's expression sees fresh data.
	for expr_edge in _expression_edges:
		var from_id: String = expr_edge[0]
		var to_id: String = expr_edge[1]
		if nodes.has(from_id) and nodes.has(to_id):
			if to_id not in adjacency[from_id]:
				adjacency[from_id].append(to_id)
				in_degree[to_id] += 1

	# Remote (wireless) dependency edges — operators like SelectTOP and
	# ParameterCHOP declare dependencies on nodes they reference by name.
	# The referenced node must cook before the referencing node.
	for node_id in nodes:
		var node: GNNode = nodes[node_id]
		var remote_deps: Array[String] = node.get_remote_dependencies()
		for dep_id in remote_deps:
			if nodes.has(dep_id) and dep_id not in adjacency.get(dep_id, []):
				if node_id not in adjacency[dep_id]:
					adjacency[dep_id].append(node_id)
					in_degree[node_id] += 1

	# Seed the queue with zero-in-degree nodes
	var queue: Array[String] = []
	for node_id in in_degree:
		if in_degree[node_id] == 0:
			queue.append(node_id)

	var sorted: Array[GNNode] = []
	while not queue.is_empty():
		var current_id: String = queue.pop_front()
		var current_node: GNNode = nodes.get(current_id, null)
		if current_node:
			sorted.append(current_node)
		for downstream_id in adjacency.get(current_id, []):
			in_degree[downstream_id] -= 1
			if in_degree[downstream_id] == 0:
				queue.append(downstream_id)

	# If sorted.size() < nodes.size(), there's a cycle — return partial order
	if sorted.size() < nodes.size():
		GNLogger.error("Network", "Topological sort incomplete: %d/%d nodes — cycle detected" % [sorted.size(), nodes.size()])
		push_warning("GNNetwork: topological sort incomplete — possible cycle detected")
	else:
		GNLogger.debug("Network", "Topo sort computed: %d node(s)" % sorted.size())
	return sorted


## Returns nodes grouped by topological level (depth from sources).
## Level 0 = nodes with no upstream dependencies.  Nodes within the same level
## are independent and can safely cook in parallel if they share no mutable data.
## Cached alongside _topo_cache — rebuilt when _topo_dirty.
var _topo_levels_cache: Array = []  # Array[Array[GNNode]]
var _topo_levels_dirty: bool = true

## Expression-derived dependency edges: Array of [from_id, to_id] pairs.
## Set by the cook engine after scanning parameter expressions.
## Injected into _compute_topological_levels() as additional adjacency.
var _expression_edges: Array = []

func get_topological_levels() -> Array:
	if not _topo_levels_dirty and not _topo_dirty:
		return _topo_levels_cache
	_topo_levels_cache = _compute_topological_levels()
	_topo_levels_dirty = false
	return _topo_levels_cache


func _compute_topological_levels() -> Array:
	var in_degree: Dictionary = {}
	var adjacency: Dictionary = {}
	var depth: Dictionary = {}
	for node_id in nodes:
		in_degree[node_id] = 0
		adjacency[node_id] = []
		depth[node_id] = 0

	# Wire connections
	for conn in connections:
		if nodes.has(conn.from_node) and nodes.has(conn.to_node):
			adjacency[conn.from_node].append(conn.to_node)
			in_degree[conn.to_node] += 1

	# Expression reference edges — if node B reads node A via chop()/par()/op(),
	# A must cook at an earlier level than B for thread-safe parallel cooking.
	for expr_edge in _expression_edges:
		var from_id: String = expr_edge[0]
		var to_id: String = expr_edge[1]
		if nodes.has(from_id) and nodes.has(to_id):
			if to_id not in adjacency[from_id]:
				adjacency[from_id].append(to_id)
				in_degree[to_id] += 1

	# Remote (wireless) dependency edges — same as in _compute_topological_order.
	for node_id in nodes:
		var node: GNNode = nodes[node_id]
		var remote_deps: Array[String] = node.get_remote_dependencies()
		for dep_id in remote_deps:
			if nodes.has(dep_id):
				if node_id not in adjacency[dep_id]:
					adjacency[dep_id].append(node_id)
					in_degree[node_id] += 1

	# Kahn's with level tracking
	var queue: Array[String] = []
	for node_id in in_degree:
		if in_degree[node_id] == 0:
			queue.append(node_id)
			depth[node_id] = 0

	var max_depth: int = 0
	while not queue.is_empty():
		var current_id: String = queue.pop_front()
		var d: int = depth[current_id]
		for ds_id in adjacency.get(current_id, []):
			depth[ds_id] = maxi(depth[ds_id], d + 1)
			max_depth = maxi(max_depth, depth[ds_id])
			in_degree[ds_id] -= 1
			if in_degree[ds_id] == 0:
				queue.append(ds_id)

	# Bucket nodes into levels
	var levels: Array = []
	levels.resize(max_depth + 1)
	for i in range(levels.size()):
		levels[i] = []
	for node_id in depth:
		var node: GNNode = nodes.get(node_id, null)
		if node:
			levels[depth[node_id]].append(node)
	return levels


func _mark_topo_dirty() -> void:
	_topo_dirty = true
	_topo_levels_dirty = true


## DFS cycle detection helper.
func _dfs_has_cycle(node_id: String, color: Dictionary) -> bool:
	color[node_id] = 1  # GRAY — visiting
	for conn in connections:
		if conn.from_node == node_id:
			var next_id: String = conn.to_node
			if not color.has(next_id):
				continue
			if color[next_id] == 1:
				return true  # Back edge → cycle
			if color[next_id] == 0:
				if _dfs_has_cycle(next_id, color):
					return true
	color[node_id] = 2  # BLACK — done
	return false


## Invalidates the cached topological order.
func _invalidate_topo() -> void:
	_topo_dirty = true
	_topo_levels_dirty = true
	_topo_cache.clear()
	_adjacency_dirty = true


## Rebuilds the cached adjacency maps from the connection list.
## Called lazily when the graph structure changes.
func _rebuild_adjacency() -> void:
	if not _adjacency_dirty:
		return
	_downstream_map.clear()
	_input_conn_map.clear()
	_output_conn_map.clear()
	for node_id in nodes:
		_downstream_map[node_id] = []
		_input_conn_map[node_id] = []
		_output_conn_map[node_id] = []
	for conn in connections:
		if nodes.has(conn.from_node) and nodes.has(conn.to_node):
			var ds_list: Array = _downstream_map[conn.from_node]
			if conn.to_node not in ds_list:
				ds_list.append(conn.to_node)
			_input_conn_map[conn.to_node].append(conn)
			_output_conn_map[conn.from_node].append(conn)
	_adjacency_dirty = false


# ═══════════════════════════════════════════════════════════════════════════════
# Dirty Propagation
# ═══════════════════════════════════════════════════════════════════════════════

## Propagates dirty flags downstream from a given node (BFS).
## Called by the cook engine when a node's output changes.
## Uses cached adjacency map for O(1) lookups per node.
## Inactive nodes are still marked dirty (so they pick it up when reactivated)
## but their downstream is NOT traversed — saving BFS walks through frozen
## subgraphs.  When an inactive node later becomes active, the cook engine
## recomputes the active set and those already-dirty nodes will cook.
func propagate_dirty(from_node_id: String) -> void:
	_rebuild_adjacency()
	var queue: Array[String] = []
	# Seed with direct downstream of the source (not the source itself)
	for ds_id in _downstream_map.get(from_node_id, []):
		var ds_node: GNNode = nodes.get(ds_id, null)
		if ds_node and not ds_node.dirty:
			ds_node.mark_dirty()
			# Only continue BFS through active nodes — inactive branches
			# are frozen and don't need further propagation.
			if ds_node.is_active:
				queue.append(ds_id)

	# BFS through further downstream
	while not queue.is_empty():
		var current_id: String = queue.pop_front()
		for ds_id in _downstream_map.get(current_id, []):
			var ds_node: GNNode = nodes.get(ds_id, null)
			if ds_node and not ds_node.dirty:
				ds_node.mark_dirty()
				if ds_node.is_active:
					queue.append(ds_id)


## Returns the IDs of nodes immediately downstream of the given node.
## Uses the cached adjacency map — O(1) lookup after rebuild.
func get_immediate_downstream(node_id: String) -> Array:
	_rebuild_adjacency()
	return _downstream_map.get(node_id, [])


# ═══════════════════════════════════════════════════════════════════════════════
# Annotation Management (Network Boxes & Sticky Notes)
# ═══════════════════════════════════════════════════════════════════════════════

## Signal emitted when an annotation is added, removed, or changed.
signal annotations_changed()

## Creates a new annotation and returns its unique ID.
## [param ann_type] is "box" or "note".
func add_annotation(ann_type: String, position: Vector2,
		size: Vector2 = Vector2(300, 200), text: String = "",
		color: Color = Color(0.15, 0.35, 0.65, 0.7)) -> String:
	_annotation_counter += 1
	var ann_id := "ann_%d" % _annotation_counter
	var ann := {
		"id": ann_id,
		"type": ann_type,
		"position": position,
		"size": size,
		"text": text,
		"color": color,
	}
	annotations.append(ann)
	GNLogger.info("Network", "Added %s annotation '%s'" % [ann_type, ann_id])
	annotations_changed.emit()
	return ann_id


## Returns the annotation Dictionary with the given ID, or null.
func get_annotation(ann_id: String) -> Variant:
	for ann in annotations:
		if ann.get("id", "") == ann_id:
			return ann
	return null


## Updates an annotation's properties. Pass only the keys you want to change.
func update_annotation(ann_id: String, changes: Dictionary) -> void:
	for ann in annotations:
		if ann.get("id", "") == ann_id:
			for key in changes:
				ann[key] = changes[key]
			annotations_changed.emit()
			return


## Removes an annotation by ID.
func remove_annotation(ann_id: String) -> bool:
	for i in range(annotations.size()):
		if annotations[i].get("id", "") == ann_id:
			annotations.remove_at(i)
			GNLogger.info("Network", "Removed annotation '%s'" % ann_id)
			annotations_changed.emit()
			return true
	return false


# ═══════════════════════════════════════════════════════════════════════════════
# Serialization Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Returns the total number of nodes.
func get_node_count() -> int:
	return nodes.size()


## Returns the total number of connections.
func get_connection_count() -> int:
	return connections.size()


## Serializes the entire network (nodes + connections) to a Dictionary.
## This is the canonical save format — can be written to JSON.
## Patch-level setting: enable multi-threaded parallel cooking.
## Off by default (experimental).  User can opt in per patch.
var multithreading_enabled: bool = false

## Graph viewport state — scroll offset and zoom level.
## Serialized as the top-level "viewport" key in .gnpatch files.
## Written by the editor before save, read after load.
var viewport_state: Dictionary = {}

## Host I/O manifest — declares the patch's interface for embedded host apps.
## Serialized as the top-level "host_io" key in .gnpatch files.
## Structure: { "inputs": [...], "outputs": [...], "parameters": [...] }
## See dev_docs/INTEGRATION.md for the full specification.
var host_io: Dictionary = {}


func to_dict() -> Dictionary:
	var d: Dictionary = {
		"version": "1.0.0",
		"generator": "GONODES",
	}

	# Serialize nodes
	var nodes_dict: Dictionary = {}
	for node_id in nodes:
		var node: GNNode = nodes[node_id]
		nodes_dict[node_id] = node.to_dict()
	d["nodes"] = nodes_dict

	# Serialize connections
	var conns_array: Array = []
	for conn in connections:
		conns_array.append({
			"from": conn.from_node,
			"from_port": conn.from_port,
			"to": conn.to_node,
			"to_port": conn.to_port,
		})
	d["connections"] = conns_array

	# Serialize annotations (network boxes & sticky notes)
	if not annotations.is_empty():
		var ann_array: Array = []
		for ann in annotations:
			var ann_d: Dictionary = {
				"id": ann.get("id", ""),
				"type": ann.get("type", ""),
				"text": ann.get("text", ""),
			}
			var pos: Variant = ann.get("position", Vector2.ZERO)
			if pos is Vector2:
				ann_d["position"] = [pos.x, pos.y]
			else:
				ann_d["position"] = [0.0, 0.0]
			var sz: Variant = ann.get("size", Vector2(200, 150))
			if sz is Vector2:
				ann_d["size"] = [sz.x, sz.y]
			else:
				ann_d["size"] = [200.0, 150.0]
			var col: Variant = ann.get("color", Color.WHITE)
			if col is Color:
				ann_d["color"] = [col.r, col.g, col.b, col.a]
			else:
				ann_d["color"] = [1.0, 1.0, 1.0, 1.0]
			ann_array.append(ann_d)
		d["annotations"] = ann_array

	# Patch-level settings
	if multithreading_enabled:
		d["multithreading_enabled"] = true

	# Graph viewport state
	if not viewport_state.is_empty():
		d["viewport"] = viewport_state

	# Host I/O manifest
	if not host_io.is_empty():
		d["host_io"] = host_io

	return d


## Reconstructs the network from a serialized Dictionary.
## Clears any existing state first. Uses GNExtensionRegistry to create operator
## instances by type name.
## Returns true on success, false if the data is malformed.
func from_dict(d: Dictionary) -> bool:
	if not d.has("nodes") or not d.has("connections"):
		GNLogger.error("Network", "Patch file missing 'nodes' or 'connections' key")
		return false

	# Clear current state (without emitting signals for each removal)
	_clear_all()

	var registry := GNExtensionRegistry.instance()

	# ── Reconstruct nodes ──
	var nodes_dict: Dictionary = d["nodes"]
	for node_id in nodes_dict:
		var nd: Dictionary = nodes_dict[node_id]
		var op_type: String = nd.get("type", "")
		if op_type.is_empty():
			GNLogger.warn("Network", "Skipping node '%s': missing 'type'" % node_id)
			continue

		var node: GNNode = registry.create_instance(op_type)
		if node == null:
			# Create a placeholder so the node is preserved in the network
			# and connections to/from it survive.  The original serialized data
			# is stored for lossless re-save.
			node = GNNode.new()
			node._placeholder_data = nd.duplicate(true)
			node.node_type = op_type
			node.family = _infer_family_from_type(op_type)
			node.node_error = "Missing operator: %s" % op_type
			node.initialize(node_id)
			# Restore position from the saved dict
			node.from_dict(nd)
			nodes[node_id] = node
			GNLogger.warn("Network",
				"Node '%s': unknown type '%s' — loaded as placeholder" % [node_id, op_type])
			continue

		node.initialize(node_id)
		node.from_dict(nd)

		nodes[node_id] = node
		GNLogger.debug("Network", "Loaded node '%s' (%s)" % [node_id, op_type])

	# ── Reconstruct connections ──
	# First pass: ensure placeholder nodes have enough ports for all connections.
	var conns_array: Array = d["connections"]
	for cd in conns_array:
		var from_id: String = cd.get("from", "")
		var to_id: String = cd.get("to", "")
		var from_port: int = int(cd.get("from_port", 0))
		var to_port: int = int(cd.get("to_port", 0))
		# Grow placeholder output ports
		var from_node: GNNode = nodes.get(from_id, null)
		if from_node != null and from_node.is_placeholder():
			while from_node.output_ports.size() <= from_port:
				from_node.add_output("out%d" % from_node.output_ports.size(),
					from_node.family, "Placeholder output")
		# Grow placeholder input ports
		var to_node_p: GNNode = nodes.get(to_id, null)
		if to_node_p != null and to_node_p.is_placeholder():
			while to_node_p.input_ports.size() <= to_port:
				to_node_p.add_input("in%d" % to_node_p.input_ports.size(),
					to_node_p.family, false, "Placeholder input")

	# Second pass: create connections.
	for cd in conns_array:
		var from_id: String = cd.get("from", "")
		var to_id: String = cd.get("to", "")
		var from_port: int = int(cd.get("from_port", 0))
		var to_port: int = int(cd.get("to_port", 0))

		if not nodes.has(from_id) or not nodes.has(to_id):
			GNLogger.warn("Network", "Skipping connection %s:%d → %s:%d (missing node)" % [
				from_id, from_port, to_id, to_port])
			continue

		var conn := GNConnection.create(from_id, from_port, to_id, to_port)
		connections.append(conn)

		# Mark target dirty
		var to_node: GNNode = nodes.get(to_id, null)
		if to_node:
			to_node.mark_dirty()

	_invalidate_topo()

	# ── Post-load: sync dynamic input port counts ──
	# The saved dynamic_input_count was restored in from_dict(), but run the
	# canonical update as a safety net so trailing empty slots are correct.
	for node_id2 in nodes:
		var n: GNNode = nodes[node_id2]
		if n._dynamic_input:
			_update_dynamic_node_inputs(node_id2)

	GNLogger.info("Network", "Loaded patch: %d nodes, %d connections" % [
		nodes.size(), connections.size()])

	# ── Reconstruct annotations (network boxes & sticky notes) ──
	annotations.clear()
	_annotation_counter = 0
	if d.has("annotations"):
		var ann_array: Array = d["annotations"]
		for ad in ann_array:
			var ann_id: String = ad.get("id", "")
			var ann_type: String = ad.get("type", "")
			var ann_text: String = ad.get("text", "")
			var pos_arr: Variant = ad.get("position", [0.0, 0.0])
			var sz_arr: Variant = ad.get("size", [200.0, 150.0])
			var col_arr: Variant = ad.get("color", [1.0, 1.0, 1.0, 1.0])
			var pos := Vector2.ZERO
			var sz := Vector2(200, 150)
			var col := Color.WHITE
			if pos_arr is Array and pos_arr.size() >= 2:
				pos = Vector2(float(pos_arr[0]), float(pos_arr[1]))
			if sz_arr is Array and sz_arr.size() >= 2:
				sz = Vector2(float(sz_arr[0]), float(sz_arr[1]))
			if col_arr is Array and col_arr.size() >= 4:
				col = Color(float(col_arr[0]), float(col_arr[1]), float(col_arr[2]), float(col_arr[3]))
			elif col_arr is Array and col_arr.size() >= 3:
				col = Color(float(col_arr[0]), float(col_arr[1]), float(col_arr[2]))
			var ann := {
				"id": ann_id,
				"type": ann_type,
				"position": pos,
				"size": sz,
				"text": ann_text,
				"color": col,
			}
			annotations.append(ann)
			# Track counter to ensure unique IDs for new annotations
			if ann_id.begins_with("ann_"):
				var num_part := ann_id.substr(4)
				if num_part.is_valid_int():
					_annotation_counter = maxi(_annotation_counter, int(num_part))
		GNLogger.info("Network", "Loaded %d annotation(s)" % annotations.size())

	# Patch-level settings
	multithreading_enabled = d.get("multithreading_enabled", false)

	# Graph viewport state
	viewport_state = d.get("viewport", {})

	# Host I/O manifest
	host_io = d.get("host_io", {})

	return true


## Saves the network to a `.gnpatch` JSON file at the given path.
## Returns OK on success or an error code.
func save_to_file(file_path: String) -> Error:
	var d := to_dict()
	var json_string := JSON.stringify(d, "\t")  # Pretty-printed

	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		var err := FileAccess.get_open_error()
		GNLogger.error("Network", "Failed to open '%s' for writing (error %d)" % [file_path, err])
		return err

	file.store_string(json_string)
	file.close()
	GNLogger.info("Network", "Saved patch to '%s' (%d nodes, %d connections)" % [
		file_path, nodes.size(), connections.size()])
	return OK


## Loads the network from a `.gnpatch` JSON file at the given path.
## Clears and replaces current state.
## Returns OK on success or an error code.
func load_from_file(file_path: String) -> Error:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		var err := FileAccess.get_open_error()
		GNLogger.error("Network", "Failed to open '%s' for reading (error %d)" % [file_path, err])
		return err

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_err := json.parse(json_string)
	if parse_err != OK:
		GNLogger.error("Network", "JSON parse error in '%s': %s (line %d)" % [
			file_path, json.get_error_message(), json.get_error_line()])
		return parse_err

	var d: Dictionary = json.data
	if not d is Dictionary:
		GNLogger.error("Network", "Patch file '%s' does not contain a JSON object" % file_path)
		return ERR_INVALID_DATA

	if not from_dict(d):
		return ERR_INVALID_DATA

	GNLogger.info("Network", "Loaded patch from '%s'" % file_path)
	return OK


## Clears all nodes and connections without emitting individual signals.
## Used internally by from_dict() — emits graph_changed once at the end.
func _clear_all() -> void:
	connections.clear()
	annotations.clear()
	_annotation_counter = 0
	for node_id in nodes:
		var node: GNNode = nodes[node_id]
		if node.is_inside_tree():
			node.get_parent().remove_child(node)
		node.queue_free()
	nodes.clear()
	_invalidate_topo()


## Infers the GNFamily.Type from an operator type name by matching the trailing
## family suffix (e.g. "WebRenderTOP" → TOP, "RtMidiInCHOP" → CHOP).
## Returns COMP as fallback for unrecognizable names.
static func _infer_family_from_type(op_type: String) -> int:
	var upper := op_type.to_upper()
	# Check suffixes longest-first to avoid false matches (e.g. SCRIPT before SOP)
	for suffix in ["SCRIPT", "CHOP", "COMP", "TOP", "SOP", "DAT", "MAT", "IMG", "POP", "VOL", "OUT", "SDF", "UI"]:
		if upper.ends_with(suffix):
			return GNFamily.string_to_type(suffix)
	return GNFamily.Type.COMP


func _to_string() -> String:
	return "[GNNetwork: %d nodes, %d connections]" % [nodes.size(), connections.size()]


# ═══════════════════════════════════════════════════════════════════════════════
# Host I/O Manifest
# ═══════════════════════════════════════════════════════════════════════════════

## Auto-generates a host_io manifest by scanning the network for HostIn*/HostOut*
## bridge operators and collecting their labels. Overwrites the current host_io.
## Call this from the editor's "Generate Host I/O" action.
func generate_host_io() -> Dictionary:
	var inputs: Array = []
	var outputs: Array = []

	for node_id in nodes:
		var node: GNNode = nodes[node_id]
		var label_val: String = ""
		var label_param: GNParameter = node.get_parameter("label")
		if label_param != null:
			label_val = str(label_param.value)

		match node.node_type:
			"host_in":
				inputs.append({
					"label": label_val if not label_val.is_empty() else node_id,
					"family": "TOP",
					"node": node_id,
					"required": true,
				})
			"host_in_chop":
				inputs.append({
					"label": label_val if not label_val.is_empty() else node_id,
					"family": "CHOP",
					"node": node_id,
					"required": true,
				})
			"host_in_dat":
				inputs.append({
					"label": label_val if not label_val.is_empty() else node_id,
					"family": "DAT",
					"node": node_id,
					"required": false,
				})
			"host_in_vol":
				inputs.append({
					"label": label_val if not label_val.is_empty() else node_id,
					"family": "VOL",
					"node": node_id,
					"required": false,
				})
			"host_in_pop":
				inputs.append({
					"label": label_val if not label_val.is_empty() else node_id,
					"family": "POP",
					"node": node_id,
					"required": false,
				})
			"host_in_sop":
				inputs.append({
					"label": label_val if not label_val.is_empty() else node_id,
					"family": "SOP",
					"node": node_id,
					"required": false,
				})
			"host_out":
				outputs.append({
					"label": label_val if not label_val.is_empty() else node_id,
					"family": "TOP",
					"node": node_id,
				})
			"host_out_chop":
				outputs.append({
					"label": label_val if not label_val.is_empty() else node_id,
					"family": "CHOP",
					"node": node_id,
				})
			"host_out_dat":
				outputs.append({
					"label": label_val if not label_val.is_empty() else node_id,
					"family": "DAT",
					"node": node_id,
				})
			"host_out_vol":
				outputs.append({
					"label": label_val if not label_val.is_empty() else node_id,
					"family": "VOL",
					"node": node_id,
				})
			"host_out_pop":
				outputs.append({
					"label": label_val if not label_val.is_empty() else node_id,
					"family": "POP",
					"node": node_id,
				})
			"host_out_sop":
				outputs.append({
					"label": label_val if not label_val.is_empty() else node_id,
					"family": "SOP",
					"node": node_id,
				})

	var manifest: Dictionary = {}
	if not inputs.is_empty():
		manifest["inputs"] = inputs
	if not outputs.is_empty():
		manifest["outputs"] = outputs

	host_io = manifest
	return manifest


## Returns the host_io manifest as a JSON string. If no manifest was authored,
## auto-generates one from bridge operators in the network.
func get_host_io_json() -> String:
	if host_io.is_empty():
		generate_host_io()
	if host_io.is_empty():
		return "{}"
	return JSON.stringify(host_io)
