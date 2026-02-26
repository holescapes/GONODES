class_name GNGraphEditor
extends GraphEdit
## The visual node graph editor for GONODES.
## Wraps Godot's GraphEdit to display and edit a GNNetwork.
## Handles node views, wire connections, deletion, and syncs
## UI actions back to the GNNetwork model.

## The network this editor visualizes and edits.
var network: GNNetwork = null

## Map of node ID → GNNodeView for quick lookup.
var _node_views: Dictionary = {}

## The node palette popup for adding new nodes.
var _palette: GNNodePalette = null

## Position where the next node should be spawned (right-click or Tab location).
var _spawn_position: Vector2 = Vector2.ZERO

## Clipboard dictionary for copy/paste: {"nodes": {id: dict}, "connections": [dict]}.
var _clipboard: Dictionary = {}

## Whether live previews are shown on node views.
var previews_visible: bool = true

## Whether the performance profiling overlay is shown on node views.
var perf_overlay_visible: bool = false

## Right-click context menu.
var _context_menu: PopupMenu = null

## Context menu item IDs.
enum _CtxID {
	ADD_NODE,
	COPY,
	CUT,
	PASTE,
	DUPLICATE,
	DELETE,
	SELECT_ALL,
	UNDO,
	REDO,
	OPEN_VIEWER,
}

## Undo/redo history for graph operations.
var _undo_redo := UndoRedo.new()

## Snapshot of selected node positions before a drag move begins.
var _pre_move_positions: Dictionary = {}

## Signal emitted when an operator node is selected (for external inspector/viewer hookup).
signal operator_selected(node_id: String)

## Signal emitted when selection is cleared.
signal operator_deselected()

## Signal emitted when "Open Viewer" is chosen from the context menu.
signal open_viewer_requested(node_id: String)


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Configure GraphEdit defaults
	right_disconnects = true
	snapping_enabled = true
	snapping_distance = 20
	minimap_enabled = true
	minimap_size = Vector2(200, 150)

	# Zoom settings
	zoom_min = 0.25
	zoom_max = 2.5
	zoom_step = 0.1
	zoom = 0.8

	# Wire signals
	connection_request.connect(_on_connection_request)
	disconnection_request.connect(_on_disconnection_request)
	delete_nodes_request.connect(_on_delete_nodes_request)
	# GraphEdit's built-in signals for node selection (Node parameter)
	self.node_selected.connect(_on_graphedit_node_selected)
	self.node_deselected.connect(_on_graphedit_node_deselected)

	# Move tracking for undo
	self.begin_node_move.connect(_on_begin_node_move)
	self.end_node_move.connect(_on_end_node_move)

	# GraphEdit intercepts Ctrl+C/V/X/D and emits these signals instead
	self.copy_nodes_request.connect(copy_selected)
	self.paste_nodes_request.connect(paste_clipboard)
	self.duplicate_nodes_request.connect(duplicate_selected)
	self.cut_nodes_request.connect(cut_selected)

	# Create palette popup
	_palette = GNNodePalette.new()
	_palette.visible = false
	_palette.node_type_selected.connect(_on_palette_node_selected)
	add_child(_palette)

	# Create context menu
	_context_menu = PopupMenu.new()
	_context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	add_child(_context_menu)

	GNLogger.info("GraphEditor", "Graph editor ready")


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_A and event.alt_pressed and not event.ctrl_pressed:
			# Open node palette at mouse position (Alt+A)
			_spawn_position = (get_local_mouse_position() + scroll_offset) / zoom
			_palette.popup_at(get_global_mouse_position())
			get_viewport().set_input_as_handled()
		elif event.ctrl_pressed:
			match event.keycode:
				KEY_Z:
					if event.shift_pressed:
						redo_action()
					else:
						undo_action()
					get_viewport().set_input_as_handled()
				KEY_Y:
					redo_action()
					get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_spawn_position = (get_local_mouse_position() + scroll_offset) / zoom
			_show_context_menu(get_screen_position() + get_local_mouse_position())
			accept_event()


# ═══════════════════════════════════════════════════════════════════════════════
# Network Binding
# ═══════════════════════════════════════════════════════════════════════════════

## Binds this editor to a GNNetwork and populates the graph from it.
func bind_network(net: GNNetwork) -> void:
	if network != null:
		_unbind_network()

	network = net

	# Wire network signals for dynamic updates
	network.node_added.connect(_on_network_node_added)
	network.node_removed.connect(_on_network_node_removed)
	network.connection_added.connect(_on_network_connection_added)
	network.connection_removed.connect(_on_network_connection_removed)
	network.node_renamed.connect(_on_network_node_renamed)

	# Build initial graph
	_populate_from_network()

	GNLogger.info("GraphEditor", "Bound to network with %d nodes, %d connections" % [
		network.get_node_count(), network.get_connection_count()])


## Disconnects from the current network and clears the graph.
func _unbind_network() -> void:
	if network == null:
		return

	if network.node_added.is_connected(_on_network_node_added):
		network.node_added.disconnect(_on_network_node_added)
	if network.node_removed.is_connected(_on_network_node_removed):
		network.node_removed.disconnect(_on_network_node_removed)
	if network.connection_added.is_connected(_on_network_connection_added):
		network.connection_added.disconnect(_on_network_connection_added)
	if network.connection_removed.is_connected(_on_network_connection_removed):
		network.connection_removed.disconnect(_on_network_connection_removed)
	if network.node_renamed.is_connected(_on_network_node_renamed):
		network.node_renamed.disconnect(_on_network_node_renamed)

	_clear_graph()
	network = null


# ═══════════════════════════════════════════════════════════════════════════════
# Graph Population
# ═══════════════════════════════════════════════════════════════════════════════

## Builds node views and wires from the bound network.
func _populate_from_network() -> void:
	_clear_graph()

	if network == null:
		return

	# Auto-layout: assign positions to nodes that don't have one
	var idx := 0
	for node_id in network.nodes:
		var node: GNNode = network.nodes[node_id]
		if node.graph_position == Vector2.ZERO:
			node.graph_position = Vector2(idx * 280, 0)
			idx += 1

	# Create node views
	for node_id in network.nodes:
		var node: GNNode = network.nodes[node_id]
		_create_node_view(node)

	# Create connections (must happen after all node views exist)
	for conn in network.connections:
		_add_visual_connection(conn)


## Removes all node views and connections from the graph.
func _clear_graph() -> void:
	clear_connections()
	for view_name in _node_views:
		var view: GNNodeView = _node_views[view_name]
		remove_child(view)
		view.queue_free()
	_node_views.clear()


# ═══════════════════════════════════════════════════════════════════════════════
# Node View Management
# ═══════════════════════════════════════════════════════════════════════════════

## Creates a GNNodeView for the given GNNode and adds it to the graph.
func _create_node_view(node: GNNode) -> GNNodeView:
	# Connect the graph editor's handler FIRST so stale wires are pruned
	# before GNNodeView rebuilds its slots (signal fires in connection order).
	if not node.ports_changed.is_connected(_on_node_ports_changed):
		node.ports_changed.connect(_on_node_ports_changed)

	var view := GNNodeView.new()
	view.setup(node)
	view.rename_requested.connect(_on_node_rename_requested)
	add_child(view)
	_node_views[node.id] = view

	# Respect current preview toggle state
	if not previews_visible:
		view.hide_preview()

	# Respect current perf overlay state
	if perf_overlay_visible:
		view.show_perf_overlay()

	return view


## Removes a node view by ID.
func _remove_node_view(node_id: String) -> void:
	if not _node_views.has(node_id):
		return
	var view: GNNodeView = _node_views[node_id]
	_node_views.erase(node_id)
	remove_child(view)
	view.queue_free()


## Adds a visual wire for a GNConnection.
func _add_visual_connection(conn: GNConnection) -> void:
	if _node_views.has(conn.from_node) and _node_views.has(conn.to_node):
		connect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)


## Removes a visual wire for a GNConnection.
func _remove_visual_connection(conn: GNConnection) -> void:
	disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)


# ═══════════════════════════════════════════════════════════════════════════════
# UI Event Handlers — User Actions → Model Updates
# ═══════════════════════════════════════════════════════════════════════════════

## User drags a wire from one port to another.
func _on_connection_request(from_node: StringName, from_port: int,
		to_node: StringName, to_port: int) -> void:
	if network == null:
		return

	var fn := String(from_node)
	var tn := String(to_node)

	# Let the network validate (type check, cycle check, etc.)
	var success := network.connect_nodes(fn, from_port, tn, to_port)

	if not success:
		GNLogger.warn("GraphEditor", "Connection rejected: %s:%d → %s:%d" % [
			fn, from_port, tn, to_port])
		return

	# Record for undo
	_undo_redo.create_action("Connect %s → %s" % [fn, tn])
	_undo_redo.add_do_method(_ur_connect.bind(fn, from_port, tn, to_port))
	_undo_redo.add_undo_method(_ur_disconnect.bind(fn, from_port, tn, to_port))
	_undo_redo.commit_action(false)


## User disconnects a wire (right-click drag or right_disconnects).
func _on_disconnection_request(from_node: StringName, from_port: int,
		to_node: StringName, to_port: int) -> void:
	if network == null:
		return

	var fn := String(from_node)
	var tn := String(to_node)
	network.disconnect_nodes(fn, from_port, tn, to_port)

	# Record for undo
	_undo_redo.create_action("Disconnect %s → %s" % [fn, tn])
	_undo_redo.add_do_method(_ur_disconnect.bind(fn, from_port, tn, to_port))
	_undo_redo.add_undo_method(_ur_connect.bind(fn, from_port, tn, to_port))
	_undo_redo.commit_action(false)


## User presses Delete with nodes selected.
func _on_delete_nodes_request(node_names: Array[StringName]) -> void:
	if network == null:
		return
	if node_names.is_empty():
		return

	# Snapshot nodes and connections for undo BEFORE deleting
	var nodes_snapshot: Array = []   # [[node_id, node_dict], ...]
	var conns_snapshot: Array = []   # [[from, from_port, to, to_port], ...]
	var node_ids: Array = []
	var seen_conns: Dictionary = {}  # Dedup connections shared between deleted nodes

	for node_name in node_names:
		var node_id := String(node_name)
		var node: GNNode = network.nodes.get(node_id, null)
		if node == null:
			continue
		node_ids.append(node_id)
		nodes_snapshot.append([node_id, node.to_dict()])

		for conn in network.connections:
			if conn.from_node == node_id or conn.to_node == node_id:
				var key := "%s:%d>%s:%d" % [conn.from_node, conn.from_port,
						conn.to_node, conn.to_port]
				if not seen_conns.has(key):
					seen_conns[key] = true
					conns_snapshot.append([conn.from_node, conn.from_port,
							conn.to_node, conn.to_port])

	# Perform the deletion
	for nid in node_ids:
		network.remove_node(nid)
		GNLogger.info("GraphEditor", "User deleted node '%s'" % nid)

	# Record for undo
	_undo_redo.create_action("Delete %d node(s)" % node_ids.size())
	_undo_redo.add_do_method(_ur_remove_nodes.bind(node_ids))
	_undo_redo.add_undo_method(_ur_restore_nodes.bind(nodes_snapshot, conns_snapshot))
	_undo_redo.commit_action(false)


## User clicks a node in the graph (GraphEdit built-in signal).
func _on_graphedit_node_selected(gn: Node) -> void:
	if gn is GNNodeView:
		var view: GNNodeView = gn as GNNodeView
		if view.gn_node:
			operator_selected.emit(view.gn_node.id)


## User deselects a node (GraphEdit built-in signal).
func _on_graphedit_node_deselected(gn: Node) -> void:
	operator_deselected.emit()


# ═══════════════════════════════════════════════════════════════════════════════
# Network Signal Handlers — Model Updates → UI Updates
# ═══════════════════════════════════════════════════════════════════════════════

## A node was added to the network (possibly from code or palette).
func _on_network_node_added(node_id: String) -> void:
	if _node_views.has(node_id):
		return  # Already have a view (e.g., we created it ourselves)

	var node: GNNode = network.nodes.get(node_id, null)
	if node:
		_create_node_view(node)


## A node was removed from the network.
func _on_network_node_removed(node_id: String) -> void:
	_remove_node_view(node_id)


## A connection was added to the network.
func _on_network_connection_added(conn: GNConnection) -> void:
	_add_visual_connection(conn)


## A connection was removed from the network.
func _on_network_connection_removed(conn: GNConnection) -> void:
	_remove_visual_connection(conn)


## A node's port count changed at runtime.  Prune any wires that reference
## ports that no longer exist, then let the GNNodeView rebuild its slots.
## The view's own ports_changed handler fires AFTER this because GDScript
## signal connections are called in registration order (GNGraphEditor connects
## before GNNodeView.setup).
func _on_node_ports_changed(node_id: String) -> void:
	if network:
		network.prune_stale_connections(node_id)


## User requested a rename from a GNNodeView's inline edit.
func _on_node_rename_requested(old_id: String, new_id: String) -> void:
	if network == null:
		return
	if not network.rename_node(old_id, new_id):
		GNLogger.warn("GraphEditor", "Rename '%s' → '%s' failed" % [old_id, new_id])
		return

	# Record for undo
	_undo_redo.create_action("Rename %s → %s" % [old_id, new_id])
	_undo_redo.add_do_method(_ur_rename.bind(old_id, new_id))
	_undo_redo.add_undo_method(_ur_rename.bind(new_id, old_id))
	_undo_redo.commit_action(false)


## Network confirmed a node was renamed — update visual wires and view registry.
func _on_network_node_renamed(old_id: String, new_id: String) -> void:
	if not _node_views.has(old_id):
		return

	var view: GNNodeView = _node_views[old_id]

	# Disconnect and reconnect all visual wires involving this node.
	# GraphEdit identifies nodes by GraphNode.name, so we must remove wires
	# under the old name, update the view, then re-add wires under the new name.
	var affected_conns: Array[GNConnection] = []
	for conn in network.connections:
		if conn.from_node == new_id or conn.to_node == new_id:
			affected_conns.append(conn)

	# Remove visual wires under old name
	for conn in affected_conns:
		var vis_from := old_id if conn.from_node == new_id else conn.from_node
		var vis_to := old_id if conn.to_node == new_id else conn.to_node
		disconnect_node(vis_from, conn.from_port, vis_to, conn.to_port)

	# Update the view identity
	_node_views.erase(old_id)
	view.apply_rename(old_id, new_id)
	_node_views[new_id] = view

	# Re-add visual wires under new name
	for conn in affected_conns:
		_add_visual_connection(conn)

	# Re-emit selection with new ID so inspector/viewer update
	operator_selected.emit(new_id)


# ═══════════════════════════════════════════════════════════════════════════════
# Node Spawning (from palette)
# ═══════════════════════════════════════════════════════════════════════════════

## Called when the user selects a node type from the palette popup.
func _on_palette_node_selected(operator_type: String) -> void:
	if network == null:
		return

	var node: GNNode = _create_operator_instance(operator_type)
	if node == null:
		GNLogger.warn("GraphEditor", "Unknown operator type: '%s'" % operator_type)
		return

	# Generate unique ID and initialize
	var unique_id := network.generate_unique_id(node.node_type)
	node.initialize(unique_id)
	node.graph_position = _spawn_position

	# Add to network — this triggers _on_network_node_added which creates the view
	network.add_node(node)

	# Record for undo
	var node_dict := node.to_dict()
	_undo_redo.create_action("Add %s" % unique_id)
	_undo_redo.add_do_method(_ur_add_node.bind(unique_id, node_dict))
	_undo_redo.add_undo_method(_ur_remove_node.bind(unique_id))
	_undo_redo.commit_action(false)

	GNLogger.info("GraphEditor", "Spawned '%s' (%s) at %s" % [
		unique_id, operator_type, str(_spawn_position)])


## Factory that creates operator instances by type name.
## Delegates to GNExtensionRegistry for dynamic, data-driven instantiation.
## Returns null for unknown types.
static func _create_operator_instance(operator_type: String) -> GNNode:
	return GNExtensionRegistry.instance().create_instance(operator_type)


## Returns a list of all available operator types grouped by family.
## Delegates to GNExtensionRegistry. Used by the palette to display options.
static func get_operator_registry() -> Dictionary:
	return GNExtensionRegistry.instance().get_operator_registry()


## Updates live preview on all node views.
## Called after each cook frame by the editor.
func update_previews() -> void:
	if not previews_visible:
		return
	for view_name in _node_views:
		var view: GNNodeView = _node_views[view_name]
		view.update_preview()


## Toggles preview visibility on all node views.
func set_previews_visible(enabled: bool) -> void:
	previews_visible = enabled
	for view_name in _node_views:
		var view: GNNodeView = _node_views[view_name]
		if enabled:
			view.show_preview()
		else:
			view.hide_preview()


## Updates performance overlay on all node views.
## Called after each cook frame by the editor.
func update_perf_overlays() -> void:
	if not perf_overlay_visible:
		return
	for view_name in _node_views:
		var view: GNNodeView = _node_views[view_name]
		view.update_perf_overlay()


## Toggles performance overlay visibility on all node views.
func set_perf_overlay_visible(enabled: bool) -> void:
	perf_overlay_visible = enabled
	for view_name in _node_views:
		var view: GNNodeView = _node_views[view_name]
		if enabled:
			view.show_perf_overlay()
		else:
			view.hide_perf_overlay()


# ═══════════════════════════════════════════════════════════════════════════════
# Copy / Paste
# ═══════════════════════════════════════════════════════════════════════════════

## Returns the IDs of all currently selected nodes in the graph.
func _get_selected_node_ids() -> Array[String]:
	var ids: Array[String] = []
	for view_name in _node_views:
		var view: GNNodeView = _node_views[view_name]
		if view.selected:
			ids.append(view_name)
	return ids


## Deselects all node views in the graph.
func _deselect_all() -> void:
	for view_name in _node_views:
		var view: GNNodeView = _node_views[view_name]
		if view.selected:
			view.selected = false


## Copies selected nodes and their internal connections to the clipboard.
func copy_selected() -> void:
	if network == null:
		return

	var selected_ids: Array[String] = _get_selected_node_ids()
	if selected_ids.is_empty():
		return

	# Serialize each selected node
	var nodes_data: Dictionary = {}
	for node_id in selected_ids:
		var node: GNNode = network.nodes.get(node_id, null)
		if node:
			nodes_data[node_id] = node.to_dict()

	# Collect connections where BOTH endpoints are in the selected set
	var conns_data: Array = []
	for conn in network.connections:
		if selected_ids.has(conn.from_node) and selected_ids.has(conn.to_node):
			conns_data.append({
				"from_node": conn.from_node,
				"from_port": conn.from_port,
				"to_node": conn.to_node,
				"to_port": conn.to_port,
			})

	_clipboard = {"nodes": nodes_data, "connections": conns_data}
	GNLogger.info("GraphEditor", "Copied %d node(s), %d connection(s)" % [
		nodes_data.size(), conns_data.size()])


## Pastes clipboard contents with new IDs and offset positions.
func paste_clipboard() -> void:
	if _clipboard.is_empty() or not _clipboard.has("nodes"):
		return
	if network == null:
		return

	var nodes_data: Dictionary = _clipboard["nodes"]
	var conns_data: Array = _clipboard.get("connections", [])

	# Build ID remap: old_id → new_id
	var id_remap: Dictionary = {}
	var new_nodes: Array[GNNode] = []

	for old_id in nodes_data:
		var nd: Dictionary = nodes_data[old_id]
		var op_type: String = nd.get("type", "")

		var node: GNNode = _create_operator_instance(op_type)
		if node == null:
			GNLogger.warn("GraphEditor", "Paste: unknown type '%s', skipping" % op_type)
			continue

		var new_id := network.generate_unique_id(op_type)
		node.initialize(new_id)
		node.from_dict(nd)

		# Offset position so pasted nodes are visually distinct
		node.graph_position += Vector2(50, 50)

		id_remap[old_id] = new_id
		new_nodes.append(node)

	# Add nodes to network (triggers view creation via signal)
	for node in new_nodes:
		network.add_node(node)

	# Restore internal connections with remapped IDs
	for cd in conns_data:
		var from_id: String = id_remap.get(cd["from_node"], "")
		var to_id: String = id_remap.get(cd["to_node"], "")
		if not from_id.is_empty() and not to_id.is_empty():
			network.connect_nodes(from_id, int(cd["from_port"]),
					to_id, int(cd["to_port"]))

	# Select only the newly pasted nodes
	_deselect_all()
	var pasted_ids: Array = []
	for old_id in id_remap:
		var new_id: String = id_remap[old_id]
		pasted_ids.append(new_id)
		if _node_views.has(new_id):
			_node_views[new_id].selected = true

	# Record for undo — snapshot pasted nodes for redo, remove for undo
	var pasted_snapshot: Array = []
	var pasted_conns: Array = []
	for pid in pasted_ids:
		var pn: GNNode = network.nodes.get(pid, null)
		if pn:
			pasted_snapshot.append([pid, pn.to_dict()])
	for conn in network.connections:
		if pasted_ids.has(conn.from_node) and pasted_ids.has(conn.to_node):
			pasted_conns.append([conn.from_node, conn.from_port,
					conn.to_node, conn.to_port])

	_undo_redo.create_action("Paste %d node(s)" % pasted_ids.size())
	_undo_redo.add_do_method(_ur_restore_nodes.bind(pasted_snapshot, pasted_conns))
	_undo_redo.add_undo_method(_ur_remove_nodes.bind(pasted_ids))
	_undo_redo.commit_action(false)

	GNLogger.info("GraphEditor", "Pasted %d node(s)" % new_nodes.size())


## Cuts selected nodes: copies to clipboard, then deletes them.
func cut_selected() -> void:
	copy_selected()
	var selected: Array[StringName] = []
	for view_name in _node_views:
		var view: GNNodeView = _node_views[view_name]
		if view.selected:
			selected.append(StringName(view_name))
	if not selected.is_empty():
		_on_delete_nodes_request(selected)


## Duplicates selected nodes in place (copy + paste).
func duplicate_selected() -> void:
	copy_selected()
	paste_clipboard()


# ═══════════════════════════════════════════════════════════════════════════════
# Context Menu
# ═══════════════════════════════════════════════════════════════════════════════

## Builds and shows the right-click context menu at the given screen position.
func _show_context_menu(screen_pos: Vector2) -> void:
	_context_menu.clear()

	var has_selection := not _get_selected_node_ids().is_empty()
	var has_clipboard := not _clipboard.is_empty()

	# Always available
	_context_menu.add_item("Add Node…", _CtxID.ADD_NODE)
	_context_menu.set_item_shortcut(_context_menu.get_item_index(_CtxID.ADD_NODE), _shortcut(KEY_A, false, true), true)
	_context_menu.add_separator()

	# Selection-dependent items
	_context_menu.add_item("Copy", _CtxID.COPY)
	_context_menu.set_item_shortcut(_context_menu.get_item_index(_CtxID.COPY), _shortcut(KEY_C, true), true)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.COPY), not has_selection)

	_context_menu.add_item("Cut", _CtxID.CUT)
	_context_menu.set_item_shortcut(_context_menu.get_item_index(_CtxID.CUT), _shortcut(KEY_X, true), true)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.CUT), not has_selection)

	_context_menu.add_item("Paste", _CtxID.PASTE)
	_context_menu.set_item_shortcut(_context_menu.get_item_index(_CtxID.PASTE), _shortcut(KEY_V, true), true)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.PASTE), not has_clipboard)

	_context_menu.add_item("Duplicate", _CtxID.DUPLICATE)
	_context_menu.set_item_shortcut(_context_menu.get_item_index(_CtxID.DUPLICATE), _shortcut(KEY_D, true), true)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.DUPLICATE), not has_selection)

	_context_menu.add_separator()

	_context_menu.add_item("Delete", _CtxID.DELETE)
	_context_menu.set_item_shortcut(_context_menu.get_item_index(_CtxID.DELETE), _shortcut(KEY_DELETE), true)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.DELETE), not has_selection)

	_context_menu.add_separator()

	_context_menu.add_item("Select All", _CtxID.SELECT_ALL)
	_context_menu.set_item_shortcut(_context_menu.get_item_index(_CtxID.SELECT_ALL), _shortcut(KEY_A, true), true)

	_context_menu.add_separator()

	_context_menu.add_item("Undo", _CtxID.UNDO)
	_context_menu.set_item_shortcut(_context_menu.get_item_index(_CtxID.UNDO), _shortcut(KEY_Z, true), true)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.UNDO), not _undo_redo.has_undo())

	_context_menu.add_item("Redo", _CtxID.REDO)
	_context_menu.set_item_shortcut(_context_menu.get_item_index(_CtxID.REDO), _shortcut(KEY_Y, true), true)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.REDO), not _undo_redo.has_redo())

	# Viewer window — enabled when exactly one TOP node is selected
	var selected_ids := _get_selected_node_ids()
	var single_top_selected := false
	if selected_ids.size() == 1 and network != null:
		var sel_node: GNNode = network.get_node_by_id(selected_ids[0])
		if sel_node != null and sel_node.family == GNFamily.Type.TOP:
			single_top_selected = true
	_context_menu.add_separator()
	_context_menu.add_item("Open Viewer", _CtxID.OPEN_VIEWER)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.OPEN_VIEWER), not single_top_selected)

	_context_menu.position = Vector2i(screen_pos)
	_context_menu.reset_size()
	_context_menu.popup()


## Handles a context menu item being pressed.
func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		_CtxID.ADD_NODE:
			_palette.popup_at(Vector2(_context_menu.position))
		_CtxID.COPY:
			copy_selected()
		_CtxID.CUT:
			cut_selected()
		_CtxID.PASTE:
			paste_clipboard()
		_CtxID.DUPLICATE:
			duplicate_selected()
		_CtxID.DELETE:
			var selected: Array[StringName] = []
			for view_name in _node_views:
				var view: GNNodeView = _node_views[view_name]
				if view.selected:
					selected.append(StringName(view_name))
			if not selected.is_empty():
				_on_delete_nodes_request(selected)
		_CtxID.SELECT_ALL:
			for view_name in _node_views:
				_node_views[view_name].selected = true
		_CtxID.UNDO:
			undo_action()
		_CtxID.REDO:
			redo_action()
		_CtxID.OPEN_VIEWER:
			var selected := _get_selected_node_ids()
			if selected.size() == 1:
				open_viewer_requested.emit(selected[0])


## Helper: creates a Shortcut with a single InputEventKey for menu display.
func _shortcut(keycode: Key, ctrl: bool = false, alt: bool = false) -> Shortcut:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.ctrl_pressed = ctrl
	ev.alt_pressed = alt
	var sc := Shortcut.new()
	sc.events = [ev]
	return sc


# ═══════════════════════════════════════════════════════════════════════════════
# Undo / Redo
# ═══════════════════════════════════════════════════════════════════════════════

## Undoes the last graph action.
func undo_action() -> void:
	if _undo_redo.has_undo():
		_undo_redo.undo()
		GNLogger.info("GraphEditor", "Undo: %s" % _undo_redo.get_current_action_name())


## Redoes the last undone graph action.
func redo_action() -> void:
	if _undo_redo.has_redo():
		_undo_redo.redo()
		GNLogger.info("GraphEditor", "Redo")


## Clears all undo/redo history (call on New/Load).
func clear_undo_history() -> void:
	_undo_redo.clear_history()


# ── Move tracking ────────────────────────────────────────────────────────────

## Snapshot selected node positions when a drag begins.
func _on_begin_node_move() -> void:
	_pre_move_positions.clear()
	for view_name in _node_views:
		var view: GNNodeView = _node_views[view_name]
		if view.selected:
			_pre_move_positions[view_name] = view.position_offset


## Compare positions after drag ends and record for undo if changed.
func _on_end_node_move() -> void:
	if _pre_move_positions.is_empty():
		return

	var old_positions: Dictionary = _pre_move_positions.duplicate()
	var new_positions: Dictionary = {}
	var changed := false

	for node_id in old_positions:
		if _node_views.has(node_id):
			var new_pos: Vector2 = _node_views[node_id].position_offset
			new_positions[node_id] = new_pos
			if new_pos != old_positions[node_id]:
				changed = true

	if changed:
		_undo_redo.create_action("Move %d node(s)" % old_positions.size())
		_undo_redo.add_do_method(_ur_set_positions.bind(new_positions))
		_undo_redo.add_undo_method(_ur_set_positions.bind(old_positions))
		_undo_redo.commit_action(false)

	_pre_move_positions.clear()


# ── Undo/redo helper methods ─────────────────────────────────────────────────
# These are called by UndoRedo.undo()/redo() to replay or reverse actions.
# They operate on the network model; network signals update the views.

## Adds a node from serialized data (for redo of add, or undo of delete).
func _ur_add_node(node_id: String, node_dict: Dictionary) -> void:
	if network == null or network.nodes.has(node_id):
		return
	var registry := GNExtensionRegistry.instance()
	var op_type: String = node_dict.get("type", "")
	var node: GNNode = registry.create_instance(op_type)
	if node == null:
		return
	node.initialize(node_id)
	node.from_dict(node_dict)
	network.add_node(node)


## Removes a node (for undo of add, or redo of delete).
func _ur_remove_node(node_id: String) -> void:
	if network and network.nodes.has(node_id):
		network.remove_node(node_id)


## Restores multiple nodes and their connections from snapshots.
func _ur_restore_nodes(nodes_snapshot: Array, conns_snapshot: Array) -> void:
	# First recreate all nodes
	for nd in nodes_snapshot:
		_ur_add_node(nd[0], nd[1])
	# Then restore connections (nodes must exist first)
	for cd in conns_snapshot:
		_ur_connect(cd[0], cd[1], cd[2], cd[3])


## Removes multiple nodes.
func _ur_remove_nodes(node_ids: Array) -> void:
	for node_id in node_ids:
		_ur_remove_node(node_id)


## Creates a connection.
func _ur_connect(from_id: String, from_port: int,
		to_id: String, to_port: int) -> void:
	if network:
		network.connect_nodes(from_id, from_port, to_id, to_port)


## Removes a connection.
func _ur_disconnect(from_id: String, from_port: int,
		to_id: String, to_port: int) -> void:
	if network:
		network.disconnect_nodes(from_id, from_port, to_id, to_port)


## Sets positions for one or more nodes and updates their views.
func _ur_set_positions(positions: Dictionary) -> void:
	for node_id in positions:
		var pos: Vector2 = positions[node_id]
		var node: GNNode = network.get_node_by_id(node_id) if network else null
		if node:
			node.graph_position = pos
			if _node_views.has(node_id):
				_node_views[node_id].position_offset = pos


## Renames a node.
func _ur_rename(old_id: String, new_id: String) -> void:
	if network:
		network.rename_node(old_id, new_id)
