class_name GNNetwork
extends Resource
## The graph model for a GONODES node network.
## Manages nodes, connections, topological ordering, and cycle detection.
## This is a pure data model — no rendering or UI logic.

# ─── Data ──────────────────────────────────────────────────────────────────────

## All nodes in this network, keyed by their unique ID.
var nodes: Dictionary = {}

## All wire connections between node ports.
var connections: Array[GNConnection] = []

## Export mappings (CHOP export mode, post-MVP).
var export_mappings: Array = []  # Array[GNExportMapping] — defined in cook engine for now

## Cached topological order — invalidated when graph structure changes.
var _topo_cache: Array[GNNode] = []
var _topo_dirty: bool = true

## Cached adjacency maps — rebuilt when graph structure changes.
## _downstream_map: node_id → Array of downstream node_ids (for dirty propagation)
## _input_conn_map: node_id → Array[GNConnection] (for input gathering)
var _downstream_map: Dictionary = {}
var _input_conn_map: Dictionary = {}
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

## Emitted when the graph structure changes (any add/remove of nodes or connections).
signal graph_changed()


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
	graph_changed.emit()
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
	graph_changed.emit()

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

	# Check if input already has a connection (unless multi_input)
	if not in_port.multi_input:
		for conn in connections:
			if conn.to_node == to_id and conn.to_port == to_port:
				push_warning("GNNetwork.connect: input port %d on '%s' already connected" % [to_port, to_id])
				return false

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
	graph_changed.emit()
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
			graph_changed.emit()
			return true
	push_warning("GNNetwork.disconnect: connection not found")
	return false


## Returns all connections feeding into a specific node.
## Uses cached input-connection map for O(1) lookup.
func get_input_connections(node_id: String) -> Array:
	_rebuild_adjacency()
	return _input_conn_map.get(node_id, [])


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
	_topo_cache.clear()
	_adjacency_dirty = true


## Rebuilds the cached adjacency maps from the connection list.
## Called lazily when the graph structure changes.
func _rebuild_adjacency() -> void:
	if not _adjacency_dirty:
		return
	_downstream_map.clear()
	_input_conn_map.clear()
	for node_id in nodes:
		_downstream_map[node_id] = []
		_input_conn_map[node_id] = []
	for conn in connections:
		if nodes.has(conn.from_node) and nodes.has(conn.to_node):
			var ds_list: Array = _downstream_map[conn.from_node]
			if conn.to_node not in ds_list:
				ds_list.append(conn.to_node)
			_input_conn_map[conn.to_node].append(conn)
	_adjacency_dirty = false


# ═══════════════════════════════════════════════════════════════════════════════
# Dirty Propagation
# ═══════════════════════════════════════════════════════════════════════════════

## Propagates dirty flags downstream from a given node (BFS).
## Called by the cook engine when a node's output changes.
## Uses cached adjacency map for O(1) lookups per node.
func propagate_dirty(from_node_id: String) -> void:
	_rebuild_adjacency()
	var queue: Array[String] = []
	# Seed with direct downstream of the source (not the source itself)
	for ds_id in _downstream_map.get(from_node_id, []):
		var ds_node: GNNode = nodes.get(ds_id, null)
		if ds_node and not ds_node.dirty:
			ds_node.mark_dirty()
			queue.append(ds_id)

	# BFS through further downstream
	while not queue.is_empty():
		var current_id: String = queue.pop_front()
		for ds_id in _downstream_map.get(current_id, []):
			var ds_node: GNNode = nodes.get(ds_id, null)
			if ds_node and not ds_node.dirty:
				ds_node.mark_dirty()
				queue.append(ds_id)


# ═══════════════════════════════════════════════════════════════════════════════
# Serialization Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Returns the total number of nodes.
func get_node_count() -> int:
	return nodes.size()


## Returns the total number of connections.
func get_connection_count() -> int:
	return connections.size()


func _to_string() -> String:
	return "[GNNetwork: %d nodes, %d connections]" % [nodes.size(), connections.size()]
