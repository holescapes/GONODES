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
	TOGGLE_PREVIEW,
	NODE_HELP,
	TOGGLE_BYPASS,
	TOGGLE_LOCK,
	ALIGN_H,
	ALIGN_V,
	AUTO_LAYOUT,
	EXPORT_OUTPUT,
}

## Undo/redo history for graph operations.
var _undo_redo := UndoRedo.new()

## FileDialog used by Export Output… context menu action.
var _export_dialog: FileDialog = null

## The node whose output is being exported (set before dialog opens).
var _export_target_node: GNNode = null

## Snapshot of selected node positions before a drag move begins.
var _pre_move_positions: Dictionary = {}

## Whether expression reference lines are visible.
var expr_refs_visible: bool = true

## Shortcut reference overlay panel (toggled by ?).
var _shortcut_overlay: PanelContainer = null

## Node bookmarks: key 1-9 → node_id string.
var _bookmarks: Dictionary = {}

## Wire curvature mode: 0=curved, 1=straight, 2=right-angle.
var _wire_style: int = 0

## Pending connection info when user drops a wire on empty space.
## Stores { "from_node": String, "from_port": int, "family": GNFamily.Type, "direction": String }
## direction is "output" (dragged from output) or "input" (dragged from input backwards).
## Cleared after node creation + auto-connect, or when palette is cancelled.
var _pending_connection: Dictionary = {}

## Ghost wire drawn while the palette is open after a connection drop.
## Stores the release position in LOCAL (overlay) coordinates and the port info.
## Empty dict = no ghost wire.  Drawn on _expr_ref_overlay.
var _ghost_wire: Dictionary = {}  # { "node_id": String, "port": int, "release": Vector2, "direction": String, "color": Color }

## Cached expression references: { from_node_id: [to_node_id, ...] }
var _expr_refs: Dictionary = {}

## The overlay Control that draws expression reference lines.
var _expr_ref_overlay: Control = null

## Signal emitted when an operator node is selected (for external inspector/viewer hookup).
signal operator_selected(node_id: String)

## Signal emitted when selection is cleared.
signal operator_deselected()

## Signal emitted when "Open Viewer" is chosen from the context menu.
signal open_viewer_requested(node_id: String)

## Signal emitted when help is requested for a node (? button or context menu).
signal help_requested(node_id: String)


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

	# Wire dropped on empty space → open filtered palette for auto-connect
	self.connection_to_empty.connect(_on_connection_to_empty)
	self.connection_from_empty.connect(_on_connection_from_empty)

	# Create palette popup
	_palette = GNNodePalette.new()
	_palette.visible = false
	_palette.node_type_selected.connect(_on_palette_node_selected)
	_palette.popup_hide.connect(_on_palette_closed)
	add_child(_palette)

	# Create context menu
	_context_menu = PopupMenu.new()
	_context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	add_child(_context_menu)

	# Create expression reference overlay (draws dashed lines)
	_expr_ref_overlay = Control.new()
	_expr_ref_overlay.name = "ExprRefOverlay"
	_expr_ref_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expr_ref_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_expr_ref_overlay.draw.connect(_draw_expr_ref_lines)
	add_child(_expr_ref_overlay)

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
				KEY_L:
					auto_layout()
					get_viewport().set_input_as_handled()
				KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
					set_bookmark(event.keycode - KEY_0)
					get_viewport().set_input_as_handled()
		elif not event.ctrl_pressed and not event.alt_pressed:
			match event.keycode:
				KEY_B:
					_toggle_selected_bypass()
					get_viewport().set_input_as_handled()
				KEY_L:
					_toggle_selected_lock()
					get_viewport().set_input_as_handled()
				KEY_F:
					_fit_view_to_selection()
					get_viewport().set_input_as_handled()
				KEY_H:
					_align_selected_horizontal()
					get_viewport().set_input_as_handled()
				KEY_V:
					_align_selected_vertical()
					get_viewport().set_input_as_handled()
				KEY_M:
					minimap_enabled = not minimap_enabled
					GNLogger.info("GraphEditor", "Minimap %s" % ("ON" if minimap_enabled else "OFF"))
					get_viewport().set_input_as_handled()
				KEY_W:
					cycle_wire_style()
					get_viewport().set_input_as_handled()
				KEY_SLASH:
					if event.shift_pressed:
						toggle_shortcut_overlay()
						get_viewport().set_input_as_handled()
				KEY_ESCAPE:
					if _shortcut_overlay != null:
						_shortcut_overlay.queue_free()
						_shortcut_overlay = null
						get_viewport().set_input_as_handled()
				KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
					jump_to_bookmark(event.keycode - KEY_0)
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
	view.help_requested.connect(func(nid: String) -> void: help_requested.emit(nid))
	add_child(view)
	_node_views[node.id] = view

	# Respect per-node preview flag
	if not node.preview_enabled:
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


## User drags a wire FROM an output port and drops it on empty canvas.
## Opens a filtered palette showing only operators that accept this family as input.
func _on_connection_to_empty(from_node: StringName, from_port: int,
		release_position: Vector2) -> void:
	if network == null:
		return

	var source_node: GNNode = network.get_node_by_id(String(from_node))
	if source_node == null:
		return
	var out_port: GNPort = source_node.get_output_port(from_port)
	if out_port == null:
		return

	# Store pending connection for auto-connect after palette selection
	_pending_connection = {
		"from_node": String(from_node),
		"from_port": from_port,
		"family": out_port.family,
		"direction": "output",
	}

	# Convert release_position to graph coordinates for node placement
	_spawn_position = (release_position + scroll_offset) / zoom

	# Show ghost wire from port to release point while palette is open
	_ghost_wire = {
		"node_id": String(from_node),
		"port": from_port,
		"release": release_position,
		"direction": "output",
		"color": GNFamily.get_color(out_port.family),
	}
	_expr_ref_overlay.queue_redraw()

	# Get compatible operators and open filtered palette
	var registry := GNExtensionRegistry.instance()
	var compatible := registry.get_operators_accepting_family(out_port.family)
	var allowed := PackedStringArray()
	for op_name in compatible:
		allowed.append(op_name)

	_palette.popup_at_filtered(
		get_screen_position() + release_position, allowed)


## User drags a wire FROM an input port backwards and drops on empty canvas.
## Opens a filtered palette showing only operators that produce this family as output.
func _on_connection_from_empty(to_node: StringName, to_port: int,
		release_position: Vector2) -> void:
	if network == null:
		return

	var target_node: GNNode = network.get_node_by_id(String(to_node))
	if target_node == null:
		return
	var in_port: GNPort = target_node.get_input_port(to_port)
	if in_port == null:
		return

	# Store pending connection for auto-connect after palette selection
	_pending_connection = {
		"to_node": String(to_node),
		"to_port": to_port,
		"family": in_port.family,
		"direction": "input",
	}

	# Convert release_position to graph coordinates for node placement
	_spawn_position = (release_position + scroll_offset) / zoom

	# Show ghost wire from port to release point while palette is open
	_ghost_wire = {
		"node_id": String(to_node),
		"port": to_port,
		"release": release_position,
		"direction": "input",
		"color": GNFamily.get_color(in_port.family),
	}
	_expr_ref_overlay.queue_redraw()

	# Get operators that produce this family type
	var registry := GNExtensionRegistry.instance()
	var compatible := registry.get_operators_producing_family(in_port.family)
	var allowed := PackedStringArray()
	for op_name in compatible:
		allowed.append(op_name)

	_palette.popup_at_filtered(
		get_screen_position() + release_position, allowed)


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

	# Auto-connect if this node was spawned from a dropped connection
	_try_auto_connect_pending(node)

	GNLogger.info("GraphEditor", "Spawned '%s' (%s) at %s" % [
		unique_id, operator_type, str(_spawn_position)])


## Called when the palette popup closes (user selected a node or cancelled).
## Clears any pending connection state so stale data doesn't affect future spawns.
func _on_palette_closed() -> void:
	_pending_connection = {}
	_ghost_wire = {}
	_expr_ref_overlay.queue_redraw()


## Factory that creates operator instances by type name.
## Delegates to GNExtensionRegistry for dynamic, data-driven instantiation.
## Returns null for unknown types.
static func _create_operator_instance(operator_type: String) -> GNNode:
	return GNExtensionRegistry.instance().create_instance(operator_type)


## Attempts to auto-connect a pending dropped wire to the newly created node.
## If the user dropped an output wire → connect to the new node's first compatible input.
## If the user dropped an input wire → connect from the new node's first compatible output.
func _try_auto_connect_pending(new_node: GNNode) -> void:
	if _pending_connection.is_empty():
		return

	# Read all pending info before clearing
	var family: GNFamily.Type = _pending_connection.get("family", -1)
	var direction: String = _pending_connection.get("direction", "")
	var from_node_id: String = _pending_connection.get("from_node", "")
	var from_port: int = _pending_connection.get("from_port", -1)
	var to_node_id: String = _pending_connection.get("to_node", "")
	var to_port: int = _pending_connection.get("to_port", -1)
	_pending_connection = {}

	if family < 0 or direction.is_empty():
		return

	if direction == "output":
		# Dragged from an output port → connect to new node's first matching input
		if from_node_id.is_empty() or from_port < 0:
			return
		for port: GNPort in new_node.input_ports:
			if port.family == family:
				var success := network.connect_nodes(from_node_id, from_port,
						new_node.id, port.index)
				if success:
					_undo_redo.create_action("Connect %s → %s" % [from_node_id, new_node.id])
					_undo_redo.add_do_method(_ur_connect.bind(
							from_node_id, from_port, new_node.id, port.index))
					_undo_redo.add_undo_method(_ur_disconnect.bind(
							from_node_id, from_port, new_node.id, port.index))
					_undo_redo.commit_action(false)
					GNLogger.info("GraphEditor", "Auto-connected %s:%d → %s:%d" % [
						from_node_id, from_port, new_node.id, port.index])
				return

	elif direction == "input":
		# Dragged from an input port backwards → connect new node's first matching output
		if to_node_id.is_empty() or to_port < 0:
			return
		for port: GNPort in new_node.output_ports:
			if port.family == family:
				var success := network.connect_nodes(new_node.id, port.index,
						to_node_id, to_port)
				if success:
					_undo_redo.create_action("Connect %s → %s" % [new_node.id, to_node_id])
					_undo_redo.add_do_method(_ur_connect.bind(
							new_node.id, port.index, to_node_id, to_port))
					_undo_redo.add_undo_method(_ur_disconnect.bind(
							new_node.id, port.index, to_node_id, to_port))
					_undo_redo.commit_action(false)
					GNLogger.info("GraphEditor", "Auto-connected %s:%d → %s:%d" % [
						new_node.id, port.index, to_node_id, to_port])
				return


## Returns a list of all available operator types grouped by family.
## Delegates to GNExtensionRegistry. Used by the palette to display options.
static func get_operator_registry() -> Dictionary:
	return GNExtensionRegistry.instance().get_operator_registry()


## Updates live preview on all node views.
## Called after each cook frame by the editor.
## Only updates nodes whose per-node preview_enabled flag is true.
func update_previews() -> void:
	for view_name in _node_views:
		var view: GNNodeView = _node_views[view_name]
		if view.gn_node != null and not view.gn_node.preview_enabled:
			continue
		view.update_preview()


## Bulk-toggles preview on all nodes by setting each node's preview_enabled flag.
## Acts as a master switch — sets every node's per-node flag to match.
func set_previews_visible(enabled: bool) -> void:
	previews_visible = enabled
	for view_name in _node_views:
		var view: GNNodeView = _node_views[view_name]
		if view.gn_node != null:
			view.gn_node.preview_enabled = enabled
		if enabled:
			view.show_preview()
		else:
			view.hide_preview()


## Toggles preview_enabled on all selected nodes and shows/hides accordingly.
func _toggle_selected_previews() -> void:
	var selected_ids := _get_selected_node_ids()
	if selected_ids.is_empty() or network == null:
		return
	# Determine toggle direction from first selected node
	var first_node: GNNode = network.get_node_by_id(selected_ids[0])
	if first_node == null:
		return
	var new_state := not first_node.preview_enabled
	for nid in selected_ids:
		var node: GNNode = network.get_node_by_id(nid)
		if node == null:
			continue
		node.preview_enabled = new_state
		var view: GNNodeView = _node_views.get(nid, null)
		if view != null:
			if new_state:
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
# Bypass / Lock
# ═══════════════════════════════════════════════════════════════════════════════

## Toggles bypass on all selected nodes (B key).
## Bypassed nodes pass their first input through without cooking.
func _toggle_selected_bypass() -> void:
	var selected_ids := _get_selected_node_ids()
	if selected_ids.is_empty() or network == null:
		return
	var first_node: GNNode = network.get_node_by_id(selected_ids[0])
	if first_node == null:
		return
	var new_state := not first_node.bypass
	for nid in selected_ids:
		var node: GNNode = network.get_node_by_id(nid)
		if node == null:
			continue
		node.bypass = new_state
		node.mark_dirty()
		var view: GNNodeView = _node_views.get(nid, null)
		if view != null:
			view.update_bypass_lock_visuals()
	GNLogger.info("GraphEditor", "Bypass %s on %d node(s)" % [
		"ON" if new_state else "OFF", selected_ids.size()])


## Toggles lock on all selected nodes (L key).
## Locked nodes cannot have their parameters changed by the user.
func _toggle_selected_lock() -> void:
	var selected_ids := _get_selected_node_ids()
	if selected_ids.is_empty() or network == null:
		return
	var first_node: GNNode = network.get_node_by_id(selected_ids[0])
	if first_node == null:
		return
	var new_state := not first_node.locked
	for nid in selected_ids:
		var node: GNNode = network.get_node_by_id(nid)
		if node == null:
			continue
		node.locked = new_state
		var view: GNNodeView = _node_views.get(nid, null)
		if view != null:
			view.update_bypass_lock_visuals()
	# Re-emit selection so the inspector immediately refreshes lock state
	if selected_ids.size() == 1:
		operator_selected.emit(selected_ids[0])
	GNLogger.info("GraphEditor", "Lock %s on %d node(s)" % [
		"ON" if new_state else "OFF", selected_ids.size()])


# ═══════════════════════════════════════════════════════════════════════════════
# Fit-to-View
# ═══════════════════════════════════════════════════════════════════════════════

## Fits the graph view to the selected nodes, or all nodes if none selected (F key).
func _fit_view_to_selection() -> void:
	if network == null:
		return

	var target_ids := _get_selected_node_ids()
	if target_ids.is_empty():
		# No selection — fit all nodes
		target_ids = []
		for nid in _node_views:
			target_ids.append(nid)
	if target_ids.is_empty():
		return

	# Compute bounding rectangle of target nodes
	var first := true
	var min_pos := Vector2.ZERO
	var max_pos := Vector2.ZERO
	for nid in target_ids:
		var view: GNNodeView = _node_views.get(nid, null)
		if view == null:
			continue
		var pos: Vector2 = view.position_offset
		var node_size: Vector2 = view.size
		if first:
			min_pos = pos
			max_pos = pos + node_size
			first = true  # Will be overridden below
		min_pos.x = minf(min_pos.x, pos.x)
		min_pos.y = minf(min_pos.y, pos.y)
		max_pos.x = maxf(max_pos.x, pos.x + node_size.x)
		max_pos.y = maxf(max_pos.y, pos.y + node_size.y)
		first = false

	if first:
		return  # No valid views found

	var bounds_center: Vector2 = (min_pos + max_pos) / 2.0
	var bounds_size: Vector2 = max_pos - min_pos
	var view_size: Vector2 = size

	# Calculate zoom to fit with padding
	var padding := 100.0
	var fit_zoom_x: float = view_size.x / (bounds_size.x + padding * 2.0) if bounds_size.x > 0 else 1.0
	var fit_zoom_y: float = view_size.y / (bounds_size.y + padding * 2.0) if bounds_size.y > 0 else 1.0
	var fit_zoom: float = minf(fit_zoom_x, fit_zoom_y)
	fit_zoom = clampf(fit_zoom, 0.2, 2.0)  # Stay within sane zoom limits

	zoom = fit_zoom
	scroll_offset = bounds_center * zoom - view_size / 2.0


# ═══════════════════════════════════════════════════════════════════════════════
# Alignment & Distribution
# ═══════════════════════════════════════════════════════════════════════════════

## Aligns all selected nodes to the same horizontal center (H key).
## Nodes move to share the same Y as the average Y of the selection.
func _align_selected_horizontal() -> void:
	var selected_ids := _get_selected_node_ids()
	if selected_ids.size() < 2 or network == null:
		return

	# Compute average Y center
	var sum_y := 0.0
	var count := 0
	for nid in selected_ids:
		var view: GNNodeView = _node_views.get(nid, null)
		if view == null:
			continue
		sum_y += view.position_offset.y + view.size.y / 2.0
		count += 1
	if count == 0:
		return
	var avg_y := sum_y / float(count)

	for nid in selected_ids:
		var node: GNNode = network.get_node_by_id(nid)
		var view: GNNodeView = _node_views.get(nid, null)
		if node == null or view == null:
			continue
		var new_y := avg_y - view.size.y / 2.0
		node.graph_position.y = new_y
		view.position_offset = node.graph_position
	GNLogger.info("GraphEditor", "Aligned %d node(s) horizontally" % count)


## Aligns all selected nodes to the same vertical center (V key — only when no Ctrl).
## Nodes move to share the same X as the average X of the selection.
func _align_selected_vertical() -> void:
	var selected_ids := _get_selected_node_ids()
	if selected_ids.size() < 2 or network == null:
		return

	# Compute average X center
	var sum_x := 0.0
	var count := 0
	for nid in selected_ids:
		var view: GNNodeView = _node_views.get(nid, null)
		if view == null:
			continue
		sum_x += view.position_offset.x + view.size.x / 2.0
		count += 1
	if count == 0:
		return
	var avg_x := sum_x / float(count)

	for nid in selected_ids:
		var node: GNNode = network.get_node_by_id(nid)
		var view: GNNodeView = _node_views.get(nid, null)
		if node == null or view == null:
			continue
		var new_x := avg_x - view.size.x / 2.0
		node.graph_position.x = new_x
		view.position_offset = node.graph_position
	GNLogger.info("GraphEditor", "Aligned %d node(s) vertically" % count)


# ═══════════════════════════════════════════════════════════════════════════════
# Expression Reference Lines
# ═══════════════════════════════════════════════════════════════════════════════

## Regex pattern for extracting node IDs from expression strings.
## Matches chop("id"), op("id"), top("id") — with optional whitespace.
static var _expr_ref_regex: RegEx = null


## Scans all nodes' parameters for expression references (chop/op/top calls)
## and caches them in [member _expr_refs] as `{ from_id: [to_id, ...] }`.
func _scan_expr_references() -> void:
	_expr_refs.clear()
	if network == null:
		return

	# Lazy-init regex
	if _expr_ref_regex == null:
		_expr_ref_regex = RegEx.new()
		_expr_ref_regex.compile("(?:chop|op|top|sop|dat|mat)\\s*\\(\\s*\"([^\"]+)\"")

	for node_id in network.nodes:
		var node: GNNode = network.nodes[node_id]
		var refs: Array[String] = []

		for param_name in node.parameters:
			var param: GNParameter = node.parameters[param_name]

			# Check main expression
			if param.mode == GNParameter.Mode.EXPRESSION and param.expression != "":
				_extract_refs_from(param.expression, refs)

			# Check per-component expressions
			for i in range(param.component_expressions.size()):
				if param.component_modes.size() > i and \
						param.component_modes[i] == GNParameter.Mode.EXPRESSION:
					var comp_expr: String = param.component_expressions[i]
					if comp_expr != "":
						_extract_refs_from(comp_expr, refs)

		if refs.size() > 0:
			_expr_refs[node_id] = refs


## Extracts referenced node IDs from an expression string and appends unique
## entries to [param out_refs].
func _extract_refs_from(expr_text: String, out_refs: Array[String]) -> void:
	var results := _expr_ref_regex.search_all(expr_text)
	for m in results:
		var ref_id: String = m.get_string(1)
		if not out_refs.has(ref_id):
			out_refs.append(ref_id)


## Rescans expression references and triggers a redraw of the overlay.
func update_expr_refs() -> void:
	_scan_expr_references()
	if _expr_ref_overlay != null:
		_expr_ref_overlay.queue_redraw()


## Draws dashed lines between nodes that reference each other via expressions,
## and the ghost wire when a connection is pending (dropped on empty canvas).
## Connected to [member _expr_ref_overlay]'s `draw` signal.
func _draw_expr_ref_lines() -> void:
	# --- Ghost wire (pending connection drop) ---
	_draw_ghost_wire()

	# --- Expression reference lines ---
	if not expr_refs_visible or _expr_refs.is_empty():
		return

	var line_color := Color(0.2, 0.85, 0.95, 0.55)  # Cyan, semi-transparent
	var line_width := 1.5
	var dash_length := 8.0
	var gap_length := 4.0

	for from_id in _expr_refs:
		var from_view: GNNodeView = _node_views.get(from_id, null)
		if from_view == null:
			continue

		var ref_ids: Array = _expr_refs[from_id]
		for to_id in ref_ids:
			var to_view: GNNodeView = _node_views.get(to_id, null)
			if to_view == null:
				continue

			# Compute center positions in graph space, then convert to overlay space
			var from_center := from_view.position_offset + from_view.size / 2.0
			var to_center := to_view.position_offset + to_view.size / 2.0

			# Convert from graph-content space to overlay (screen) space
			var p1 := (from_center - scroll_offset / zoom) * zoom
			var p2 := (to_center - scroll_offset / zoom) * zoom

			_draw_dashed_line_on(_expr_ref_overlay, p1, p2,
					line_color, line_width, dash_length, gap_length)


## Draws a dashed line on the given Control between two points.
func _draw_dashed_line_on(canvas: Control, from: Vector2, to: Vector2,
		color: Color, width: float, dash: float, gap: float) -> void:
	var direction := (to - from)
	var total_length := direction.length()
	if total_length < 1.0:
		return
	var dir_norm := direction / total_length
	var segment := dash + gap
	var pos := 0.0

	while pos < total_length:
		var seg_start := from + dir_norm * pos
		var seg_end_len := minf(pos + dash, total_length)
		var seg_end := from + dir_norm * seg_end_len
		canvas.draw_line(seg_start, seg_end, color, width, true)
		pos += segment

	# Draw a small arrow head at the destination
	var arrow_size := 6.0
	var perp := Vector2(-dir_norm.y, dir_norm.x)
	var arrow_tip := to
	var arrow_base := to - dir_norm * arrow_size
	var arrow_left := arrow_base + perp * arrow_size * 0.5
	var arrow_right := arrow_base - perp * arrow_size * 0.5
	canvas.draw_colored_polygon(
			PackedVector2Array([arrow_tip, arrow_left, arrow_right]), color)


## Draws a temporary "ghost" wire from a port to the drop point while the
## palette popup is open.  Gives visual continuity so the user sees where the
## wire will connect.
func _draw_ghost_wire() -> void:
	if _ghost_wire.is_empty():
		return

	var node_id: String = _ghost_wire.get("node_id", "")
	var port_idx: int = _ghost_wire.get("port", -1)
	var release_pos: Vector2 = _ghost_wire.get("release", Vector2.ZERO)
	var direction: String = _ghost_wire.get("direction", "")
	var wire_color: Color = _ghost_wire.get("color", Color.WHITE)

	var view: GNNodeView = _node_views.get(node_id, null)
	if view == null:
		return

	# Get port position in graph-content space (GraphNode local + offset)
	var port_local: Vector2
	if direction == "output":
		port_local = view.get_output_port_position(port_idx)
	else:
		port_local = view.get_input_port_position(port_idx)
	var port_graph := view.position_offset + port_local

	# Convert both positions from graph-content space to overlay (screen) space
	var p_port := (port_graph - scroll_offset / zoom) * zoom
	var p_release := release_pos  # Already in local overlay space (from the event)

	# Draw a semi-transparent solid line (not dashed — looks like a real wire)
	wire_color.a = 0.5
	_expr_ref_overlay.draw_line(p_port, p_release, wire_color, 2.0, true)

	# Small circle at the release end to indicate the "open" end
	_expr_ref_overlay.draw_circle(p_release, 4.0, wire_color)


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

		# Use original node ID + "_copy" as the base for the new name.
		# If that's taken, generate_unique_id will append a counter.
		var copy_base: String = old_id + "_copy"
		var new_id: String
		if not network.nodes.has(copy_base):
			new_id = copy_base
		else:
			new_id = network.generate_unique_id(copy_base)
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
# Auto-Layout
# ═══════════════════════════════════════════════════════════════════════════════

## Auto-layout spacing constants.
const _LAYOUT_H_SPACING := 280.0
const _LAYOUT_V_SPACING := 100.0

## Arranges all nodes using topological order with layered assignment.
## Nodes in the same layer (same max-depth from sources) are stacked vertically.
## Undoable via Ctrl+Z.
func auto_layout() -> void:
	if network == null or network.nodes.is_empty():
		return

	# Snapshot old positions for undo
	var old_positions: Dictionary = {}
	for node_id in _node_views:
		old_positions[node_id] = _node_views[node_id].position_offset

	# Build adjacency: from_id → [to_id, ...]
	var adjacency: Dictionary = {}
	var in_degree: Dictionary = {}
	for node_id in network.nodes:
		adjacency[node_id] = []
		in_degree[node_id] = 0
	for conn in network.connections:
		if network.nodes.has(conn.from_node) and network.nodes.has(conn.to_node):
			adjacency[conn.from_node].append(conn.to_node)
			in_degree[conn.to_node] += 1

	# Assign layers via BFS from sources (in_degree == 0)
	# Each node gets the maximum layer of all upstream nodes + 1
	var layer: Dictionary = {}  # node_id → int
	var queue: Array[String] = []
	for node_id in in_degree:
		if in_degree[node_id] == 0:
			queue.append(node_id)
			layer[node_id] = 0

	# Handle cycles / disconnected: if no sources, seed everything at layer 0
	if queue.is_empty():
		for node_id in network.nodes:
			layer[node_id] = 0
	else:
		# BFS — propagate max layer
		var visited_count := 0
		while not queue.is_empty():
			var current_id: String = queue.pop_front()
			visited_count += 1
			for downstream_id in adjacency.get(current_id, []):
				var new_layer: int = layer[current_id] + 1
				if not layer.has(downstream_id) or new_layer > layer[downstream_id]:
					layer[downstream_id] = new_layer
					queue.append(downstream_id)
		# Assign remaining unvisited nodes (cycles) to layer 0
		for node_id in network.nodes:
			if not layer.has(node_id):
				layer[node_id] = 0

	# Group nodes by layer
	var layers: Dictionary = {}  # int → Array[String]
	for node_id in layer:
		var l: int = layer[node_id]
		if not layers.has(l):
			layers[l] = []
		layers[l].append(node_id)

	# Sort layer keys
	var layer_keys: Array = layers.keys()
	layer_keys.sort()

	# Position nodes: X by layer, Y by index within layer
	var new_positions: Dictionary = {}
	for l_idx in layer_keys:
		var l_int: int = l_idx as int
		var node_ids: Array = layers[l_int]
		for row_idx in node_ids.size():
			var nid: String = node_ids[row_idx]
			new_positions[nid] = Vector2(l_int * _LAYOUT_H_SPACING, row_idx * _LAYOUT_V_SPACING)

	# Apply positions
	for node_id in new_positions:
		var pos: Vector2 = new_positions[node_id]
		var node: GNNode = network.get_node_by_id(node_id)
		if node:
			node.graph_position = pos
		if _node_views.has(node_id):
			_node_views[node_id].position_offset = pos

	# Record for undo/redo
	_undo_redo.create_action("Auto-layout %d node(s)" % network.nodes.size())
	_undo_redo.add_do_method(_ur_set_positions.bind(new_positions))
	_undo_redo.add_undo_method(_ur_set_positions.bind(old_positions))
	_undo_redo.commit_action(false)

	GNLogger.info("GraphEditor", "Auto-layout: %d nodes across %d layers" % [
		network.nodes.size(), layer_keys.size()])


# ═══════════════════════════════════════════════════════════════════════════════
# Shortcut Reference Overlay
# ═══════════════════════════════════════════════════════════════════════════════

## Toggles the shortcut reference overlay (? key).
func toggle_shortcut_overlay() -> void:
	if _shortcut_overlay != null:
		_shortcut_overlay.queue_free()
		_shortcut_overlay = null
		return

	_shortcut_overlay = PanelContainer.new()
	_shortcut_overlay.name = "ShortcutOverlay"
	_shortcut_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	# Semi-transparent dark background
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	_shortcut_overlay.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_shortcut_overlay.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Keyboard Shortcuts"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.55))
	vbox.add_child(title)

	var sep_top := HSeparator.new()
	vbox.add_child(sep_top)

	# Build shortcut table
	var shortcuts: Array[Array] = [
		["─── Navigation ───", ""],
		["Alt + A", "Open Node Palette"],
		["F", "Fit View to Selection"],
		["M", "Toggle Minimap"],
		["?", "Toggle This Overlay"],
		["1-9", "Jump to Bookmark"],
		["Ctrl + 1-9", "Set Bookmark"],
		["─── Editing ───", ""],
		["Ctrl + C", "Copy"],
		["Ctrl + X", "Cut"],
		["Ctrl + V", "Paste"],
		["Ctrl + D", "Duplicate"],
		["Delete", "Delete Selected"],
		["Ctrl + A", "Select All"],
		["Ctrl + Z", "Undo"],
		["Ctrl + Y", "Redo"],
		["─── Node Control ───", ""],
		["B", "Toggle Bypass"],
		["L", "Toggle Lock"],
		["H", "Align Horizontally"],
		["V", "Align Vertically"],
		["Ctrl + L", "Auto-Layout Graph"],
		["W", "Cycle Wire Style"],
		["─── File ───", ""],
		["Ctrl + N", "New Patch"],
		["Ctrl + O", "Open Patch"],
		["Ctrl + S", "Save Patch"],
		["Ctrl + Shift + S", "Save Patch As…"],
	]

	for entry in shortcuts:
		var key_str: String = entry[0]
		var desc: String = entry[1]

		if desc == "":
			# Section header
			var header := Label.new()
			header.text = key_str
			header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			header.add_theme_font_size_override("font_size", 13)
			header.add_theme_color_override("font_color", Color(0.6, 0.75, 1.0))
			vbox.add_child(header)
		else:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)

			var key_label := Label.new()
			key_label.text = key_str
			key_label.custom_minimum_size.x = 160
			key_label.add_theme_font_size_override("font_size", 13)
			key_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
			row.add_child(key_label)

			var desc_label := Label.new()
			desc_label.text = desc
			desc_label.add_theme_font_size_override("font_size", 13)
			desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
			row.add_child(desc_label)

			vbox.add_child(row)

	var hint := Label.new()
	hint.text = "Press ? or Escape to close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(hint)

	add_child(_shortcut_overlay)

	# Center the overlay
	await get_tree().process_frame
	if is_instance_valid(_shortcut_overlay):
		_shortcut_overlay.position = (size - _shortcut_overlay.size) / 2


# ═══════════════════════════════════════════════════════════════════════════════
# Wire Style
# ═══════════════════════════════════════════════════════════════════════════════

const _WIRE_CURVATURES: Array[float] = [0.5, 0.0, 1.5]
const _WIRE_STYLE_NAMES: Array[String] = ["Curved", "Straight", "Right-Angle"]

## Cycles through wire styles: curved → straight → right-angle.
func cycle_wire_style() -> void:
	_wire_style = (_wire_style + 1) % _WIRE_CURVATURES.size()
	connection_lines_curvature = _WIRE_CURVATURES[_wire_style]
	queue_redraw()
	GNLogger.info("GraphEditor", "Wire style: %s" % _WIRE_STYLE_NAMES[_wire_style])

## Sets the wire style by index (0=curved, 1=straight, 2=right-angle).
func set_wire_style(idx: int) -> void:
	_wire_style = clampi(idx, 0, _WIRE_CURVATURES.size() - 1)
	connection_lines_curvature = _WIRE_CURVATURES[_wire_style]
	queue_redraw()


# ═══════════════════════════════════════════════════════════════════════════════
# Node Bookmarks
# ═══════════════════════════════════════════════════════════════════════════════

## Sets a bookmark (Ctrl+1-9) for the currently selected single node.
func set_bookmark(slot: int) -> void:
	var selected := _get_selected_node_ids()
	if selected.size() != 1:
		GNLogger.warn("GraphEditor", "Select exactly one node to set a bookmark")
		return
	var node_id: String = selected[0]
	_bookmarks[slot] = node_id
	# Update visual badge on the node view
	if _node_views.has(node_id):
		_update_bookmark_badge(node_id, slot)
	GNLogger.info("GraphEditor", "Bookmark %d → %s" % [slot, node_id])


## Jumps to a bookmarked node (key 1-9).
func jump_to_bookmark(slot: int) -> void:
	if not _bookmarks.has(slot):
		GNLogger.info("GraphEditor", "No bookmark set for %d" % slot)
		return
	var node_id: String = _bookmarks[slot]
	if not _node_views.has(node_id):
		GNLogger.warn("GraphEditor", "Bookmark %d: node '%s' no longer exists" % [slot, node_id])
		_bookmarks.erase(slot)
		return
	var view: GNNodeView = _node_views[node_id]
	# Deselect all, select the bookmarked node
	for vn in _node_views:
		_node_views[vn].selected = false
	view.selected = true
	# Center view on the node
	scroll_offset = view.position_offset * zoom - size / 2 + view.size * zoom / 2
	GNLogger.info("GraphEditor", "Jumped to bookmark %d → %s" % [slot, node_id])


## Draws or removes a small numbered badge on a bookmarked node view.
func _update_bookmark_badge(node_id: String, slot: int) -> void:
	if not _node_views.has(node_id):
		return
	var view: GNNodeView = _node_views[node_id]
	# Remove existing badge if any
	var existing: Node = view.find_child("BookmarkBadge", false, false)
	if existing:
		existing.queue_free()
	# Add new badge
	var badge := Label.new()
	badge.name = "BookmarkBadge"
	badge.text = str(slot)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.custom_minimum_size = Vector2(18, 18)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.2, 0.55, 1.0, 0.85)
	bg.corner_radius_top_left = 9
	bg.corner_radius_top_right = 9
	bg.corner_radius_bottom_left = 9
	bg.corner_radius_bottom_right = 9
	badge.add_theme_stylebox_override("normal", bg)

	view.add_child(badge)
	badge.position = Vector2(view.size.x - 22, 2)


## Clears bookmark badge from a node when the bookmark is reassigned.
func _clear_bookmark_badge(node_id: String) -> void:
	if not _node_views.has(node_id):
		return
	var existing: Node = _node_views[node_id].find_child("BookmarkBadge", false, false)
	if existing:
		existing.queue_free()


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

	# Per-node preview toggle — label reflects current state of first selected node
	var preview_label := "Toggle Preview"
	if selected_ids.size() >= 1 and network != null:
		var first_node: GNNode = network.get_node_by_id(selected_ids[0])
		if first_node != null:
			preview_label = "Preview: ON" if first_node.preview_enabled else "Preview: OFF"
	_context_menu.add_item(preview_label, _CtxID.TOGGLE_PREVIEW)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.TOGGLE_PREVIEW), not has_selection)

	# Bypass toggle — shows current state of first selected node
	var bypass_label := "Bypass"
	if selected_ids.size() >= 1 and network != null:
		var bn: GNNode = network.get_node_by_id(selected_ids[0])
		if bn != null:
			bypass_label = "Bypass: ON" if bn.bypass else "Bypass: OFF"
	_context_menu.add_item(bypass_label, _CtxID.TOGGLE_BYPASS)
	_context_menu.set_item_shortcut(_context_menu.get_item_index(_CtxID.TOGGLE_BYPASS), _shortcut(KEY_B), true)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.TOGGLE_BYPASS), not has_selection)

	# Lock toggle
	var lock_label := "Lock"
	if selected_ids.size() >= 1 and network != null:
		var ln: GNNode = network.get_node_by_id(selected_ids[0])
		if ln != null:
			lock_label = "Lock: ON" if ln.locked else "Lock: OFF"
	_context_menu.add_item(lock_label, _CtxID.TOGGLE_LOCK)
	_context_menu.set_item_shortcut(_context_menu.get_item_index(_CtxID.TOGGLE_LOCK), _shortcut(KEY_L), true)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.TOGGLE_LOCK), not has_selection)

	_context_menu.add_separator()

	# Alignment tools (need 2+ selected)
	var multi_selected := selected_ids.size() >= 2
	_context_menu.add_item("Align Horizontal", _CtxID.ALIGN_H)
	_context_menu.set_item_shortcut(_context_menu.get_item_index(_CtxID.ALIGN_H), _shortcut(KEY_H), true)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.ALIGN_H), not multi_selected)

	_context_menu.add_item("Align Vertical", _CtxID.ALIGN_V)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.ALIGN_V), not multi_selected)

	_context_menu.add_item("Auto-Layout All", _CtxID.AUTO_LAYOUT)
	_context_menu.set_item_shortcut(_context_menu.get_item_index(_CtxID.AUTO_LAYOUT), _shortcut(KEY_L, true), true)

	_context_menu.add_separator()
	_context_menu.add_item("Node Help", _CtxID.NODE_HELP)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.NODE_HELP), selected_ids.size() != 1)

	# Export Output — enabled when exactly one node selected with exportable output
	var can_export := false
	if selected_ids.size() == 1 and network != null:
		var export_node: GNNode = network.get_node_by_id(selected_ids[0])
		if export_node != null:
			if export_node.cached_output != null and export_node.cached_output.valid:
				can_export = true
			elif export_node is GNCompBase and (export_node as GNCompBase).get_scene_node() != null:
				# COMP nodes like LightCOMP/CameraCOMP return null data but have a scene node
				can_export = true
	_context_menu.add_item("Export Output…", _CtxID.EXPORT_OUTPUT)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.EXPORT_OUTPUT), not can_export)

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
		_CtxID.TOGGLE_PREVIEW:
			_toggle_selected_previews()
		_CtxID.TOGGLE_BYPASS:
			_toggle_selected_bypass()
		_CtxID.TOGGLE_LOCK:
			_toggle_selected_lock()
		_CtxID.ALIGN_H:
			_align_selected_horizontal()
		_CtxID.ALIGN_V:
			_align_selected_vertical()
		_CtxID.AUTO_LAYOUT:
			auto_layout()
		_CtxID.NODE_HELP:
			var selected := _get_selected_node_ids()
			if selected.size() == 1:
				help_requested.emit(selected[0])
		_CtxID.EXPORT_OUTPUT:
			_begin_export_output()


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
# Export Output
# ═══════════════════════════════════════════════════════════════════════════════

## Begins the export workflow: identifies the selected node, configures the
## FileDialog with family-appropriate filters, and shows it.
func _begin_export_output() -> void:
	var selected := _get_selected_node_ids()
	if selected.size() != 1 or network == null:
		return
	var node: GNNode = network.get_node_by_id(selected[0])
	if node == null:
		return
	# COMP nodes may have a scene node even when cached_output is null (Light, Camera)
	var has_data := node.cached_output != null and node.cached_output.valid
	var has_scene := node is GNCompBase and (node as GNCompBase).get_scene_node() != null
	if not has_data and not has_scene:
		return
	_export_target_node = node

	# Lazy-init the FileDialog
	if _export_dialog == null:
		_export_dialog = FileDialog.new()
		_export_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		_export_dialog.title = "Export Output"
		_export_dialog.size = Vector2i(800, 500)
		_export_dialog.file_selected.connect(_on_export_file_selected)
		add_child(_export_dialog)

	# Clear previous filters and set family-specific ones
	_export_dialog.clear_filters()
	var data: GNData = node.cached_output
	var is_comp := node is GNCompBase

	# COMP check first — COMPs may have null cached_output (Light, Camera)
	if is_comp:
		_export_dialog.add_filter("*.glb", "glTF Binary (scene graph — meshes, lights, cameras)")
	elif data is GNTextureData or data is GNImageData:
		_export_dialog.add_filter("*.png", "PNG Image")
		_export_dialog.add_filter("*.webp", "WebP Image")
		_export_dialog.add_filter("*.exr", "EXR Image (HDR)")
	elif data is GNGeoData:
		_export_dialog.add_filter("*.glb", "glTF Binary (mesh only)")
	elif data is GNChannelData:
		_export_dialog.add_filter("*.csv", "CSV (channels as columns)")
		_export_dialog.add_filter("*.json", "JSON")
	elif data is GNTableData:
		_export_dialog.add_filter("*.csv", "CSV")
		_export_dialog.add_filter("*.json", "JSON")
		_export_dialog.add_filter("*.txt", "Plain Text")
	elif data is GNMaterialData:
		_export_dialog.add_filter("*.tres", "Godot Resource")
	else:
		_export_dialog.add_filter("*.tres", "Godot Resource")

	_export_dialog.current_file = node.id
	_export_dialog.popup_centered()


## Called when the user confirms a file path in the export dialog.
func _on_export_file_selected(path: String) -> void:
	if _export_target_node == null:
		return
	var data: GNData = _export_target_node.cached_output
	if data == null or not data.valid:
		GNLogger.warn("Export", "No valid output to export from '%s'" % _export_target_node.id)
		return

	var is_comp := _export_target_node is GNCompBase
	var err: Error = OK

	if is_comp:
		err = _export_comp_glb(path, _export_target_node)
	elif data is GNTextureData:
		err = _export_texture(path, data as GNTextureData)
	elif data is GNImageData:
		err = _export_image(path, data as GNImageData)
	elif data is GNGeoData:
		err = _export_geo_glb(path, data as GNGeoData)
	elif data is GNChannelData:
		err = _export_channel(path, data as GNChannelData)
	elif data is GNTableData:
		err = _export_table(path, data as GNTableData)
	elif data is GNMaterialData:
		err = _export_material(path, data as GNMaterialData)
	else:
		GNLogger.warn("Export", "Unsupported data type for export: %s" % data.get_class())
		return

	if err == OK:
		GNLogger.info("Export", "Exported '%s' → %s" % [_export_target_node.id, path])
	else:
		GNLogger.error("Export", "Failed to export '%s' → %s (error %d)" % [_export_target_node.id, path, err])
	_export_target_node = null


## Exports a GNTextureData (TOP) by reading back from GPU to CPU Image.
func _export_texture(path: String, tex_data: GNTextureData) -> Error:
	if tex_data.texture == null:
		return ERR_INVALID_DATA
	var img: Image = tex_data.texture.get_image()
	if img == null:
		return ERR_INVALID_DATA
	return _save_image_to_path(img, path)


## Exports a GNImageData (IMG) directly as an image file.
func _export_image(path: String, img_data: GNImageData) -> Error:
	if img_data.image == null:
		return ERR_INVALID_DATA
	return _save_image_to_path(img_data.image, path)


## Saves a CPU Image to disk based on file extension.
func _save_image_to_path(img: Image, path: String) -> Error:
	var ext := path.get_extension().to_lower()
	match ext:
		"png":
			return img.save_png(path)
		"webp":
			return img.save_webp(path)
		"exr":
			return img.save_exr(path)
		_:
			# Default to PNG if unrecognised
			return img.save_png(path)


## Exports a GNGeoData (SOP) as a bare-mesh glTF binary (.glb).
func _export_geo_glb(path: String, geo_data: GNGeoData) -> Error:
	if geo_data.mesh == null:
		return ERR_INVALID_DATA
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = geo_data.mesh
	mesh_inst.transform = geo_data.transform
	var err := _write_gltf_scene(path, mesh_inst)
	mesh_inst.free()
	return err


## Exports any COMP node as a glTF binary (.glb).
## Deep-clones the full scene subtree from get_scene_node() — handles:
##   • GeometryCOMP (MeshInstance3D + material_override)
##   • LightCOMP (DirectionalLight3D / OmniLight3D / SpotLight3D)
##   • CameraCOMP (Camera3D)
##   • MergeCOMP (Node3D group with all of the above as children)
func _export_comp_glb(path: String, node: GNNode) -> Error:
	var comp := node as GNCompBase
	if comp == null:
		return ERR_INVALID_DATA
	var scene_node: Node3D = comp.get_scene_node()
	if scene_node == null:
		# Fallback: try bare mesh from cached_output
		var geo: GNGeoData = node.cached_output as GNGeoData
		if geo != null:
			return _export_geo_glb(path, geo)
		return ERR_INVALID_DATA
	# Deep-clone the live subtree so GLTFDocument can own a temporary copy
	var clone: Node3D = scene_node.duplicate()
	var err := _write_gltf_scene(path, clone)
	clone.queue_free()
	return err


## Writes a Node3D subtree to a .glb file using Godot's GLTFDocument.
func _write_gltf_scene(path: String, root: Node3D) -> Error:
	# GLTFDocument needs the root in a temporary scene tree
	var tmp_root := Node3D.new()
	tmp_root.name = "ExportRoot"
	tmp_root.add_child(root)
	# Set owner on the entire subtree so GLTFDocument can traverse all nodes
	# (lights, cameras, meshes inside MergeCOMP groups, etc.)
	_set_owner_recursive(root, tmp_root)

	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(tmp_root, state)
	if err != OK:
		tmp_root.remove_child(root)
		tmp_root.free()
		return err
	err = doc.write_to_filesystem(state, path)
	tmp_root.remove_child(root)
	tmp_root.free()
	return err


## Recursively sets owner on all descendants so GLTFDocument traverses them.
func _set_owner_recursive(node: Node, owner: Node) -> void:
	node.owner = owner
	for child in node.get_children():
		_set_owner_recursive(child, owner)


## Exports GNChannelData (CHOP) as CSV or JSON.
func _export_channel(path: String, ch_data: GNChannelData) -> Error:
	var ext := path.get_extension().to_lower()
	match ext:
		"json":
			var dict := {}
			for ch_name in ch_data.channels:
				var arr: PackedFloat32Array = ch_data.channels[ch_name]
				var float_arr: Array = []
				for v in arr:
					float_arr.append(v)
				dict[ch_name] = float_arr
			var json_str := JSON.stringify(dict, "\t")
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f == null:
				return FileAccess.get_open_error()
			f.store_string(json_str)
			f.close()
			return OK
		_:
			# CSV: channels as columns, header row = channel names
			var names: Array = ch_data.channels.keys()
			if names.is_empty():
				return ERR_INVALID_DATA
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f == null:
				return FileAccess.get_open_error()
			f.store_csv_line(PackedStringArray(names))
			var length: int = ch_data.length
			for i in range(length):
				var row := PackedStringArray()
				for ch_name in names:
					var arr: PackedFloat32Array = ch_data.channels[ch_name]
					row.append(str(arr[i]) if i < arr.size() else "")
				f.store_csv_line(row)
			f.close()
			return OK


## Exports GNTableData (DAT) as CSV, JSON, or plain text.
func _export_table(path: String, tbl_data: GNTableData) -> Error:
	var ext := path.get_extension().to_lower()
	match ext:
		"json":
			var result: Array = []
			if tbl_data.is_table:
				var headers: PackedStringArray = tbl_data.table[0] if tbl_data.has_header and not tbl_data.table.is_empty() else PackedStringArray()
				var start_row := 1 if tbl_data.has_header else 0
				for r in range(start_row, tbl_data.table.size()):
					var row_dict := {}
					for c in range(tbl_data.table[r].size()):
						var key: String = headers[c] if c < headers.size() else ("col%d" % c)
						row_dict[key] = tbl_data.table[r][c]
					result.append(row_dict)
			var json_str := JSON.stringify(result, "\t")
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f == null:
				return FileAccess.get_open_error()
			f.store_string(json_str if tbl_data.is_table else tbl_data.text)
			f.close()
			return OK
		"txt":
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f == null:
				return FileAccess.get_open_error()
			if tbl_data.is_table:
				for row in tbl_data.table:
					f.store_line("\t".join(row))
			else:
				f.store_string(tbl_data.text)
			f.close()
			return OK
		_:
			# CSV
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f == null:
				return FileAccess.get_open_error()
			for row in tbl_data.table:
				f.store_csv_line(row)
			f.close()
			return OK


## Exports GNMaterialData (MAT) as a Godot .tres resource.
func _export_material(path: String, mat_data: GNMaterialData) -> Error:
	if mat_data.material == null:
		return ERR_INVALID_DATA
	return ResourceSaver.save(mat_data.material, path)


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
