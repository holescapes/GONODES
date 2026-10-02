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

## Graph-space position captured at right-click time for context-menu paste.
var _context_graph_pos := Vector2.ZERO

## Whether live previews are shown on node views.
var previews_visible: bool = true

## Whether the performance profiling overlay is shown on node views.
var perf_overlay_visible: bool = false

## When true, the graph is in read-only mode (viewing a locked custom asset).
## No edits allowed — drag, delete, connect, etc. are suppressed.
var read_only: bool = false

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
	GROUP_SELECTED,
	COPY_NODE_PATH,
	COPY_OUTPUT_REF,
	COPY_PARAMS,
	PASTE_PARAMS,
	RESET_PARAMS,
	SAVE_PARAM_PRESET,
	ADD_CHOP_EXPORT,  # Legacy — now "Insert CHOP Reference"
	INSERT_CHOP_REF,
	ADD_NETWORK_BOX,
	ADD_STICKY_NOTE,
	PROMOTE_TO_ASSET,
	EDIT_ASSET,
	MAKE_EDITABLE,
	REPROMOTE_ASSET,
	EXPORT_SUBNET_PATCH,
	IMPORT_SUBNET_PATCH,
	ADD_SPARE_PARAM,
	COPY_AS_JSON,
	PASTE_FROM_JSON,
	COPY_DEBUG_INFO,
	COPY_NETWORK_JSON,
	DELETE_WIRES,
	INSERT_NODE_ON_WIRE,
	SEARCH_NODES,
	## Dynamic IDs for preset loading start here (100+).
	LOAD_PARAM_PRESET_BASE = 100,
}

## Undo/redo history for graph operations.
var _undo_redo := UndoRedo.new()

## FileDialog used by Export Output… context menu action.
var _export_dialog: FileDialog = null

## The node whose output is being exported (set before dialog opens).
var _export_target_node: GNNode = null

## Cached preset list for the "Load Param Preset" submenu (populated on context open).
var _param_preset_list: Array = []

## Submenu for loading parameter presets.
var _param_preset_submenu: PopupMenu = null

## Save-preset dialog (name input).
var _save_preset_dialog: AcceptDialog = null
var _save_preset_line_edit: LineEdit = null
var _save_preset_target_node: GNNode = null

## Insert CHOP Reference dialog.
var _chop_ref_dialog: AcceptDialog = null
var _chop_ref_source_node: GNNode = null

## Promote-to-asset dialog.
var _promote_asset_dialog: GNAssetPromotionDialog = null

## Spare parameter dialog.
var _spare_param_dialog: AcceptDialog = null

## Snapshot of selected node positions before a drag move begins.
var _pre_move_positions: Dictionary = {}

## Whether expression reference lines are visible.
var expr_refs_visible: bool = true

## Debug overlay for cook order, active chain dimming, reference arrows, sink labels.
var debug_overlay: GNDebugOverlay = null

## Dirty flag for expression reference scanning — set true when expressions
## may have changed (node add/remove, cook). Avoids a full regex rescan
## every frame when nothing has changed.
var _expr_refs_dirty: bool = true

## Shortcut reference overlay panel (toggled by ?).
## Built once on first toggle, then shown/hidden on subsequent toggles.
var _shortcut_overlay: PanelContainer = null

## Node bookmarks: key 1-9 → node_id string.
var _bookmarks: Dictionary = {}

## Wire curvature mode: 0=curved, 1=straight, 2=right-angle.
var _wire_style: int = 0

## When true, show a confirmation dialog before deleting nodes.
var confirm_on_delete: bool = false

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

## Wireless node-reference hover state.
## _wireless_refs: { consumer_id: [{"param_name": String, "target_id": String}, ...] }
## Populated only while a node is hovered; cleared on mouse-out.
var _wireless_refs: Dictionary = {}
var _hovered_node_id: String = ""

## Per-edge expression detail text: { "consumer_id→source_id": [call_text, ...] }
## Used by the hover tooltip to show which references a dashed line represents.
var _expr_ref_details: Dictionary = {}

## The overlay Control that draws expression reference lines.
var _expr_ref_overlay: Control = null

## Tooltip popup shown when hovering over an expression reference line.
var _expr_ref_tooltip: PanelContainer = null

## Hover timer state for expression ref tooltip (3s delay).
var _expr_ref_hover_edge: String = ""   ## Edge key currently being hovered
var _expr_ref_hover_time: float = 0.0   ## Accumulated hover time on that edge
var _expr_ref_hover_mouse: Vector2 = Vector2.ZERO  ## Last mouse pos on the edge
var _expr_ref_hover_consumer: String = ""  ## Consumer node ID for tooltip text
var _expr_ref_hover_source: String = ""    ## Source node ID for tooltip text
const _EXPR_REF_HOVER_DELAY := 2.0      ## Seconds before tooltip appears

## Annotation manager (network boxes, sticky notes).
var _annotations: GNAnnotationManager = null

## Last-known zoom/scroll for detecting changes (used by expr_ref_overlay redraw).
var _last_zoom: float = 0.8
var _last_scroll: Vector2 = Vector2.ZERO

## Currently selected wires.  Each entry is a connection dict:
## { "from_node": String, "from_port": int, "to_node": String, "to_port": int }
var _selected_wires: Array[Dictionary] = []

## When non-empty, a wire drag-to-insert is in progress.  The user clicked a
## wire and dragged it — on release we open the palette filtered to operators
## that can sit between the two connected nodes.
## Keys: "from_node", "from_port", "to_node", "to_port", "family"
var _wire_insert_pending: Dictionary = {}

## Distance threshold (in local/screen pixels) for wire click hit-testing.
const _WIRE_HIT_DISTANCE := 10.0

## ── Drop-on-wire state ──────────────────────────────────────────────────────
## When a single node is being dragged over a compatible wire, this dict holds
## the wire info ({ from_node, from_port, to_node, to_port }).  Empty = no wire
## under drag.  Reset on drag-end or when the node moves away.
var _drag_over_wire: Dictionary = {}

## Cached compatible port indices on the dragged node for the current
## _drag_over_wire.  -1 means no compatible port found.
var _drag_wire_in_port: int = -1
var _drag_wire_out_port: int = -1

## Hit-test distance (in local pixels) used during node drag for wire snapping.
## Slightly wider than click to make the drop target forgiving.
const _DRAG_WIRE_HIT_DISTANCE := 14.0

## ── Wire-drag edge-scroll state ──────────────────────────────────────────────
## True while the user is dragging a wire from a port (between
## connection_drag_started and connection_drag_ended / connection_to_empty /
## connection_from_empty).
var _wire_dragging: bool = false

## Edge-scroll tuning constants.
const _EDGE_SCROLL_MARGIN := 50.0   ## Pixels from edge to trigger scroll.
const _EDGE_SCROLL_SPEED  := 800.0  ## Pixels per second at full speed.

## ── Toast notification container ─────────────────────────────────────────────
var _toast_container: VBoxContainer = null
const _TOAST_TOP_MARGIN := 16.0

## ── Node search overlay (Ctrl+F) ─────────────────────────────────────────────
var _search: GNGraphSearch = null

## ── Shake-to-disconnect state ────────────────────────────────────────────────
## Tracks a shake on one axis during a single-node drag. The first strong
## move locks horizontal or vertical for the rest of the drag. A reversal
## counts only after that swing has traveled a real distance.
var _shake_axis: int = -1
var _shake_sign: float = 0.0
var _shake_leg: float = 0.0
var _shake_reversals: int = 0
var _shake_timer: float = 0.0
var _shake_triggered: bool = false
const _SHAKE_REVERSAL_THRESHOLD := 3
const _SHAKE_TIME_WINDOW := 0.7
const _SHAKE_MIN_SPEED := 200.0
const _SHAKE_MIN_LEG := 40.0
const _SHAKE_AXIS_RATIO := 2.0

## Origin of the current box-select drag (local/screen coords).  Set on left
## mouse-down over empty canvas so we can build the actual selection rect on
## mouse-up and use it for wire intersection testing.
var _box_select_origin: Vector2 = Vector2(-1, -1)

## Signal emitted when an operator node is selected (for external inspector/viewer hookup).
signal operator_selected(node_id: String)

## Signal emitted when selection is cleared.
signal operator_deselected()

## Signal emitted when "Open Viewer" is chosen from the context menu.
signal open_viewer_requested(node_id: String)

## Signal emitted when help is requested for a node (? button or context menu).
signal help_requested(node_id: String)

## Signal emitted when the user wants to dive into a SubNetworkNode
## (Enter key or double-click on the node body).
signal dive_into_requested(node_id: String)

## Signal emitted when the user requests editing a custom asset in-place.
signal edit_asset_requested(node_id: String)

## Signal emitted when the user wants to detach an asset instance (Make Unique).
signal make_editable_requested(node_id: String)

## Signal emitted when the user wants to re-promote parameters on a custom asset.
signal repromote_asset_requested(node_id: String)

## Signal emitted when the user wants to export a SubNetwork as a .gnpatch file.
signal export_subnet_requested(node_id: String)

## Signal emitted when the user wants to import a .gnpatch from disk.
signal import_patch_requested(graph_pos: Vector2)

## Signal emitted when the user clicks the eye (viewer pin) button on a node.
signal viewer_pin_requested(node_id: String)

## Signal emitted when the user cycles wire style via keyboard shortcut.
signal wire_style_changed(idx: int)


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
	zoom_min = 0.05
	zoom_max = 2.5
	zoom_step = 1.1
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

	# Wire-drag tracking for edge-scroll
	self.connection_drag_started.connect(_on_connection_drag_started)
	self.connection_drag_ended.connect(_on_connection_drag_ended)

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

	# Create expression reference hover tooltip
	_expr_ref_tooltip = PanelContainer.new()
	_expr_ref_tooltip.name = "ExprRefTooltip"
	_expr_ref_tooltip.visible = false
	_expr_ref_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tip_label := RichTextLabel.new()
	tip_label.name = "Label"
	tip_label.bbcode_enabled = true
	tip_label.fit_content = true
	tip_label.scroll_active = false
	tip_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_label.custom_minimum_size = Vector2(180, 0)
	_expr_ref_tooltip.add_child(tip_label)
	var sbx := StyleBoxFlat.new()
	sbx.bg_color = Color(0.1, 0.12, 0.16, 0.92)
	sbx.border_color = Color(0.2, 0.85, 0.95, 0.6)
	sbx.set_border_width_all(1)
	sbx.set_corner_radius_all(4)
	sbx.set_content_margin_all(6)
	_expr_ref_tooltip.add_theme_stylebox_override("panel", sbx)
	_expr_ref_tooltip.z_index = 100
	add_child(_expr_ref_tooltip)

	# Create debug overlay (cook order badges, active dimming, ref arrows, sink labels)
	debug_overlay = GNDebugOverlay.new()
	debug_overlay.graph_editor = self
	add_child(debug_overlay)

	# Create toast notification container (top-center of visible viewport).
	# top_level keeps it out of GraphEdit's panned/zoomed graph space.
	_toast_container = VBoxContainer.new()
	_toast_container.name = "ToastContainer"
	_toast_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_container.top_level = true
	_toast_container.custom_minimum_size = Vector2(400, 0)
	_toast_container.add_theme_constant_override("separation", 6)
	_toast_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_toast_container.z_index = 4096
	_toast_container.z_as_relative = false
	add_child(_toast_container)
	_toast_container.resized.connect(_update_toast_position)
	resized.connect(_update_toast_position)
	call_deferred("_update_toast_position")

	# Hook logger warnings/errors to toast notifications
	GNLogger.toast_sink = Callable(self, "_on_logger_toast")

	# Build the node search bar (hidden by default)
	_search = GNGraphSearch.new()
	_search.setup(self, _node_views, _deselect_all, scroll_to_node)

	# Build the annotation manager
	_annotations = GNAnnotationManager.new()
	_annotations.setup(self, _node_views, network, _undo_redo, _ur_set_positions)

	GNLogger.info("GraphEditor", "Graph editor ready")


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _handle_key_input(event):
			get_viewport().set_input_as_handled()


## Routes a key press to the appropriate action.
## Returns true if the key was handled, false if not consumed.
func _handle_key_input(event: InputEventKey) -> bool:
	if event.keycode == KEY_A and event.alt_pressed and not event.ctrl_pressed:
		# Open node palette at mouse position (Alt+A)
		_spawn_position = (get_local_mouse_position() + scroll_offset) / zoom
		_palette.popup_at(get_screen_position() + get_local_mouse_position())
		return true
	if event.ctrl_pressed:
		match event.keycode:
			KEY_F:
				if _search.is_search_open():
					_search.close_search()
				else:
					_search.open_search()
			KEY_Z:
				if event.shift_pressed:
					redo_action()
				else:
					undo_action()
			KEY_Y:
				redo_action()
			KEY_L:
				auto_layout()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				set_bookmark(event.keycode - KEY_0)
			_:
				return false
		return true
	if not event.alt_pressed:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				_try_dive_into_selected()
			KEY_B:
				_toggle_selected_bypass()
			KEY_L:
				_toggle_selected_lock()
			KEY_F:
				_fit_view_to_selection()
			KEY_H:
				_align_selected_horizontal()
			KEY_V:
				_align_selected_vertical()
			KEY_M:
				minimap_enabled = not minimap_enabled
				GNLogger.info("GraphEditor", "Minimap %s" % ("ON" if minimap_enabled else "OFF"))
			KEY_W:
				cycle_wire_style()
			KEY_SLASH:
				if not event.shift_pressed:
					return false
				toggle_shortcut_overlay()
			KEY_ESCAPE:
				if _search != null and _search._search_bar != null and _search._search_bar.visible:
					_search.close_search()
				elif _shortcut_overlay != null:
					_shortcut_overlay.queue_free()
					_shortcut_overlay = null
				else:
					return false
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				jump_to_bookmark(event.keycode - KEY_0)
			_:
				return false
		return true
	return false


func _gui_input(event: InputEvent) -> void:
	# Skip mouse events that land on the search bar overlay.
	# Must accept_event() to prevent GraphEdit's base class from consuming it.
	if event is InputEventMouse and _search != null and _search._search_bar != null and _search._search_bar.visible:
		var local: Vector2 = (event as InputEventMouse).position
		if _search._search_bar.get_global_rect().has_point(get_global_transform() * local):
			accept_event()
			return

	# Delete key — delete selected wires (runs before GraphEdit consumes the
	# key for node deletion, so both wires and nodes are removed together).
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_DELETE and not event.ctrl_pressed:
			if not _selected_wires.is_empty():
				_delete_selected_wires()
				# Don't accept — let GraphEdit also process node deletion.

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_spawn_position = (get_local_mouse_position() + scroll_offset) / zoom

			# Select the node under the cursor so the context menu targets it.
			_select_node_under_cursor(_spawn_position)

			# If right-clicking on a wire (not on a node), auto-select it
			# so "Delete Wire(s)" / "Insert Node on Wire" are enabled.
			if _get_node_id_at(_spawn_position).is_empty():
				var wire_rc := get_closest_connection_at_point(
						get_local_mouse_position(), _WIRE_HIT_DISTANCE)
				if not wire_rc.is_empty():
					var w := _wire_dict_from_graphedit(wire_rc)
					if _find_wire_index(w) < 0:
						_selected_wires = [w]
						_expr_ref_overlay.queue_redraw()

			_context_graph_pos = (get_local_mouse_position() + scroll_offset) / zoom
			_show_context_menu(get_screen_position() + get_local_mouse_position())
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			# Double left-click — check wire first, then empty space
			if not _is_node_at_position(get_local_mouse_position()):
				var wire_hit := get_closest_connection_at_point(get_local_mouse_position(), _WIRE_HIT_DISTANCE)
				if not wire_hit.is_empty():
					# Double-click on wire → insert node into this wire
					var w := _wire_dict_from_graphedit(wire_hit)
					_selected_wires = [w]
					_begin_wire_insert(w)
					_expr_ref_overlay.queue_redraw()
					accept_event()
				else:
					# Double left-click on empty space → open add node palette
					var graph_pos: Vector2 = (get_local_mouse_position() + scroll_offset) / zoom
					_spawn_position = graph_pos
					_palette.popup_at(get_screen_position() + get_local_mouse_position())
					accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.double_click:
			# Single left-click — check if user clicked a wire
			if not _is_node_at_position(get_local_mouse_position()):
				var hit := get_closest_connection_at_point(get_local_mouse_position(), _WIRE_HIT_DISTANCE)
				if not hit.is_empty():
					if not event.shift_pressed:
						_selected_wires.clear()
						_deselect_all()
					# Toggle: if already selected, remove; else add
					var already := _find_wire_index(hit)
					if already >= 0:
						_selected_wires.remove_at(already)
					else:
						_selected_wires.append(_wire_dict_from_graphedit(hit))
					_expr_ref_overlay.queue_redraw()
					accept_event()
				else:
					# Clicked empty space (not wire, not node) → clear wire selection
					if not event.shift_pressed:
						_selected_wires.clear()
						_expr_ref_overlay.queue_redraw()
					# Record origin for box-select wire detection on release
					_box_select_origin = get_local_mouse_position()

	# Mouse release after dragging — check for box-select wire inclusion
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_update_wire_box_selection()
			_box_select_origin = Vector2(-1, -1)

	# Hover detection for expression reference lines
	if event is InputEventMouseMotion and expr_refs_visible and not _expr_refs.is_empty():
		_update_expr_ref_hover(get_local_mouse_position())

	# Wireless node-ref hover detection (always active, independent of expr_refs_visible)
	if event is InputEventMouseMotion:
		_update_wireless_hover(get_local_mouse_position())


# ═══════════════════════════════════════════════════════════════════════════════
# Network Binding
# ═══════════════════════════════════════════════════════════════════════════════

## Returns the annotation manager (network boxes and sticky notes).
func get_annotations() -> GNAnnotationManager:
	return _annotations


## Binds this editor to a GNNetwork and populates the graph from it.
func bind_network(net: GNNetwork) -> void:
	if network != null:
		_unbind_network()

	network = net
	if _annotations != null:
		_annotations.set_network(net)

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
	_hovered_node_id = ""
	_wireless_refs.clear()
	if _annotations != null:
		_annotations.set_network(null)


# ═══════════════════════════════════════════════════════════════════════════════
# Graph Population
# ═══════════════════════════════════════════════════════════════════════════════

## Builds node views and wires from the bound network.
func _populate_from_network() -> void:
	_clear_graph()

	if network == null:
		return

	_expr_refs_dirty = true

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

	# Defer connection creation by one frame so GraphNode's internal
	# left_port_cache / right_port_cache are populated after _resort().
	_deferred_restore_connections.call_deferred()

	# Create annotation views (network boxes & sticky notes)
	_annotations.rebuild_views()


## Removes all node views and connections from the graph.
func _clear_graph() -> void:
	clear_connections()
	for view_name in _node_views:
		var view: GNNodeView = _node_views[view_name]
		remove_child(view)
		view.queue_free()
	_node_views.clear()
	# Also remove annotation views
	_annotations.clear_views()


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
	view.dive_into_requested.connect(func(nid: String) -> void: dive_into_requested.emit(nid))
	view.viewer_pin_requested.connect(func(nid: String) -> void: viewer_pin_requested.emit(nid))
	view.bypass_toggled.connect(_on_node_bypass_toggled)
	view.lock_toggled.connect(_on_node_lock_toggled)
	view.preview_toggled.connect(_on_node_preview_toggled)
	node.parameters_changed.connect(func(_nid: String) -> void:
		_expr_refs_dirty = true
		if _nid == _hovered_node_id:
			_rebuild_wireless_refs()
			_expr_ref_overlay.queue_redraw())
	node.parameter_changed.connect(func(_nid: String, _pname: String) -> void:
		_expr_refs_dirty = true
		if _nid == _hovered_node_id:
			_rebuild_wireless_refs()
			_expr_ref_overlay.queue_redraw())
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


## Called one frame after _populate_from_network() so GraphNode port caches
## are built (they require a layout pass after set_slot() / add_child()).
func _deferred_restore_connections() -> void:
	if network == null:
		return
	for conn in network.connections:
		_add_visual_connection(conn)


## Removes a visual wire for a GNConnection.
func _remove_visual_connection(conn: GNConnection) -> void:
	disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)


# ═══════════════════════════════════════════════════════════════════════════════
# UI Event Handlers — User Actions → Model Updates
# ═══════════════════════════════════════════════════════════════════════════════

## User drags a wire from one port to another.
func _on_connection_request(from_node: StringName, from_port: int,
		to_node: StringName, to_port: int) -> void:
	if network == null or read_only:
		return

	var fn := String(from_node)
	var tn := String(to_node)

	# Snapshot any existing connection on the target input (for undo)
	var old_conn: GNConnection = network.get_connection_at_input(tn, to_port)
	var had_old := old_conn != null
	var old_from_id := old_conn.from_node if had_old else ""
	var old_from_port := old_conn.from_port if had_old else 0

	# Let the network validate (type check, cycle check, etc.)
	# If the input is occupied the network auto-disconnects the old wire first.
	var success := network.connect_nodes(fn, from_port, tn, to_port)

	if not success:
		GNLogger.warn("GraphEditor", "Connection rejected: %s:%d → %s:%d (cycle or type mismatch)" % [
			fn, from_port, tn, to_port])
		return

	# Record for undo — if we replaced a wire, undo must restore the old one
	if had_old:
		_undo_redo.create_action("Replace connection → %s:%d" % [tn, to_port])
		_undo_redo.add_do_method(_ur_disconnect.bind(old_from_id, old_from_port, tn, to_port))
		_undo_redo.add_do_method(_ur_connect.bind(fn, from_port, tn, to_port))
		_undo_redo.add_undo_method(_ur_disconnect.bind(fn, from_port, tn, to_port))
		_undo_redo.add_undo_method(_ur_connect.bind(old_from_id, old_from_port, tn, to_port))
	else:
		_undo_redo.create_action("Connect %s → %s" % [fn, tn])
		_undo_redo.add_do_method(_ur_connect.bind(fn, from_port, tn, to_port))
		_undo_redo.add_undo_method(_ur_disconnect.bind(fn, from_port, tn, to_port))
	_undo_redo.commit_action(false)

	# Clear wire selection — making a connection is an atomic action.
	if not _selected_wires.is_empty():
		_selected_wires.clear()
		_expr_ref_overlay.queue_redraw()


## User disconnects a wire (right-click drag or right_disconnects).
## We guard with a proximity check — only allow if the mouse is close to the
## input port, preventing accidental disconnects from clicking mid-wire.
const _DISCONNECT_PORT_THRESHOLD := 6.0  # pixels in local space

func _on_disconnection_request(from_node: StringName, from_port: int,
		to_node: StringName, to_port: int) -> void:
	if network == null or read_only:
		return

	# Check that the click was near the input port, not mid-wire.
	var to_view: GNNodeView = _node_views.get(String(to_node), null)
	if to_view != null:
		var port_local: Vector2 = to_view.get_input_port_position(to_port)
		var port_screen: Vector2 = (to_view.position_offset + port_local - scroll_offset / zoom) * zoom
		var mouse_pos := get_local_mouse_position()
		if mouse_pos.distance_to(port_screen) > _DISCONNECT_PORT_THRESHOLD:
			return  # Too far from the port — ignore the disconnect.

	var fn := String(from_node)
	var tn := String(to_node)
	network.disconnect_nodes(fn, from_port, tn, to_port)

	# Record for undo
	_undo_redo.create_action("Disconnect %s → %s" % [fn, tn])
	_undo_redo.add_do_method(_ur_disconnect.bind(fn, from_port, tn, to_port))
	_undo_redo.add_undo_method(_ur_connect.bind(fn, from_port, tn, to_port))
	_undo_redo.commit_action(false)


## Wire drag started — enable edge-scroll and zoom behavior.
func _on_connection_drag_started(_from_node: StringName, _from_port: int,
		_is_output: bool) -> void:
	_wire_dragging = true
	# Clear stale box-select origin so the upcoming mouse-release doesn't
	# accidentally box-select wires near the new connection endpoint.
	_box_select_origin = Vector2(-1, -1)
	# Clear wire selection — the click that starts a drag can sporadically
	# hit-test as a wire click when the port extends beyond the node rect.
	if not _selected_wires.is_empty():
		_selected_wires.clear()
		_expr_ref_overlay.queue_redraw()


## Wire drag ended (connected to a port or cancelled by pressing Escape / RMB).
func _on_connection_drag_ended() -> void:
	_wire_dragging = false


## User drags a wire FROM an output port and drops it on empty canvas.
## Opens a filtered palette showing only operators that accept this family as input.
func _on_connection_to_empty(from_node: StringName, from_port: int,
		release_position: Vector2) -> void:
	_wire_dragging = false
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
	_wire_dragging = false
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
	if network == null or read_only:
		return
	if node_names.is_empty():
		return

	if confirm_on_delete:
		var dlg := ConfirmationDialog.new()
		dlg.title = "Delete Nodes"
		dlg.dialog_text = "Delete %d node(s)?" % node_names.size()
		dlg.confirmed.connect(func():
			_do_delete_nodes(node_names)
			dlg.queue_free())
		dlg.canceled.connect(dlg.queue_free)
		add_child(dlg)
		dlg.popup_centered()
		return

	_do_delete_nodes(node_names)


## Actually removes nodes and records undo. Called directly or after confirmation.
func _do_delete_nodes(node_names: Array[StringName]) -> void:
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
	_expr_refs_dirty = true
	if _node_views.has(node_id):
		return  # Already have a view (e.g., we created it ourselves)

	var node: GNNode = network.nodes.get(node_id, null)
	if node:
		_create_node_view(node)


## A node was removed from the network.
func _on_network_node_removed(node_id: String) -> void:
	_expr_refs_dirty = true
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
	_expr_refs_dirty = true
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
	if network == null or read_only:
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

	# Splice into wire if this was a wire drag-to-insert
	_try_wire_insert_splice(node)

	GNLogger.info("GraphEditor", "Spawned '%s' (%s) at %s" % [
		unique_id, operator_type, str(_spawn_position)])


## Called when the palette popup closes (user selected a node or cancelled).
## Clears any pending connection state so stale data doesn't affect future spawns.
func _on_palette_closed() -> void:
	_pending_connection = {}
	_ghost_wire = {}
	_wire_insert_pending = {}
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
	var family: int = _pending_connection.get("family", -1)
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


## Updates the viewer pin (eye) highlight on all node views.
## [param active_id] is the node currently pinned to the docked viewer.
func update_viewer_pin_highlights(active_id: String) -> void:
	for view_name in _node_views:
		var view: GNNodeView = _node_views[view_name]
		view.set_viewer_active(view_name == active_id)


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


## Updates warning/error status badges on all node views.
## Called after each cook frame by the editor.
func update_status_badges() -> void:
	for view_name in _node_views:
		var view: GNNodeView = _node_views[view_name]
		view.update_status_badge()


## Selects one node and centers the graph on it. The camera moves before the
## selection signal, so the inspector rebuild does not delay the jump.
func select_and_center_node(node_id: String) -> void:
	var view: GNNodeView = _node_views.get(node_id, null)
	if view == null:
		return
	scroll_to_node(node_id)
	var changed := false
	for vn in _node_views:
		var other: GNNodeView = _node_views[vn]
		var should_select := other == view
		if other.selected != should_select:
			other.selected = should_select
			changed = true
	if not changed and view.gn_node != null:
		operator_selected.emit(view.gn_node.id)


## Scrolls the graph view to center on the given node.
func scroll_to_node(node_id: String) -> void:
	var view: GNNodeView = _node_views.get(node_id, null)
	if view == null:
		return
	var center := view.position_offset + view.size / 2.0
	var viewport_center := size / 2.0 / zoom
	_snap_scroll((center - viewport_center) * zoom)


## GraphEdit stores the offset immediately, then moves every node and the wire
## layer on a deferred call. A bookmark jump was sitting behind that deferral,
## and behind an inspector rebuild, so the view arrived a few frames late.
func _snap_scroll(target: Vector2) -> void:
	scroll_offset = target
	var applied := scroll_offset
	for child in get_children():
		if child is GraphElement:
			var element := child as GraphElement
			element.position = element.position_offset * zoom - applied
	var wires := get_node_or_null("_connection_layer") as Control
	if wires != null:
		wires.position = -applied
	if _annotations != null:
		_annotations.sync_if_needed(zoom, applied)
	_last_zoom = zoom
	_last_scroll = applied


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


## Handles bypass toggle from a node view's title bar button.
func _on_node_bypass_toggled(node_id: String) -> void:
	if network == null:
		return
	var node: GNNode = network.get_node_by_id(node_id)
	if node == null:
		return
	node.bypass = not node.bypass
	node.mark_dirty()
	var view: GNNodeView = _node_views.get(node_id, null)
	if view != null:
		view.update_bypass_lock_visuals()


## Handles lock toggle from a node view's title bar button.
func _on_node_lock_toggled(node_id: String) -> void:
	if network == null:
		return
	var node: GNNode = network.get_node_by_id(node_id)
	if node == null:
		return
	node.locked = not node.locked
	var view: GNNodeView = _node_views.get(node_id, null)
	if view != null:
		view.update_bypass_lock_visuals()
	operator_selected.emit(node_id)


## Handles preview toggle from a node view's title bar button.
func _on_node_preview_toggled(node_id: String) -> void:
	if network == null:
		return
	var node: GNNode = network.get_node_by_id(node_id)
	if node == null:
		return
	node.preview_enabled = not node.preview_enabled
	var view: GNNodeView = _node_views.get(node_id, null)
	if view != null:
		if node.preview_enabled:
			view.show_preview()
		else:
			view.hide_preview()
		view.update_bypass_lock_visuals()


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
	fit_zoom = clampf(fit_zoom, zoom_min, 2.0)  # Stay within sane zoom limits

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
## Also populates [member _expr_ref_details] with the full call text per edge.
func _scan_expr_references() -> void:
	_expr_refs.clear()
	_expr_ref_details.clear()
	if network == null:
		return

	# Lazy-init regex — captures full call and first argument (node ID)
	if _expr_ref_regex == null:
		_expr_ref_regex = RegEx.new()
		_expr_ref_regex.compile("((?:lookupf?|chop[sfi]?|op|top|sop|dat|mat|vol|img|output|par[sfi]?|set_par|cellf?_by_name|cellf?)\\s*\\([^)]*\\))")

	# Secondary regex to pull just the first string argument (node ID)
	var _id_regex := RegEx.new()
	_id_regex.compile("(?:lookupf?|chop[sfi]?|op|top|sop|dat|mat|vol|img|output|par[sfi]?|set_par|cellf?_by_name|cellf?)\\s*\\(\\s*\"([^\"]+)\"")

	for node_id in network.nodes:
		var node: GNNode = network.nodes[node_id]
		var refs: Array[String] = []

		for param_name in node.parameters:
			var param: GNParameter = node.parameters[param_name]

			# Check main expression
			if param.mode == GNParameter.Mode.EXPRESSION and param.expression != "":
				_extract_refs_from_with_details(param.expression, node_id, refs, _id_regex)

			# Check per-component expressions
			for i in range(param.component_expressions.size()):
				if param.component_modes.size() > i and \
						param.component_modes[i] == GNParameter.Mode.EXPRESSION:
					var comp_expr: String = param.component_expressions[i]
					if comp_expr != "":
						_extract_refs_from_with_details(comp_expr, node_id, refs, _id_regex)

		if refs.size() > 0:
			_expr_refs[node_id] = refs


## Extracts referenced node IDs from an expression string and appends unique
## entries to [param out_refs].  Also stores the full call text per edge in
## [member _expr_ref_details].
func _extract_refs_from_with_details(expr_text: String, consumer_id: String,
		out_refs: Array[String], id_regex: RegEx) -> void:
	# Find full calls
	var full_matches := _expr_ref_regex.search_all(expr_text)
	var id_matches := id_regex.search_all(expr_text)
	for i in range(mini(full_matches.size(), id_matches.size())):
		var ref_id: String = id_matches[i].get_string(1)
		var call_text: String = full_matches[i].get_string(1)
		if not out_refs.has(ref_id):
			out_refs.append(ref_id)
		# Store detail per edge
		var edge_key := "%s→%s" % [consumer_id, ref_id]
		if not _expr_ref_details.has(edge_key):
			_expr_ref_details[edge_key] = []
		var details: Array = _expr_ref_details[edge_key]
		if not details.has(call_text):
			details.append(call_text)


## Checks if the mouse is near any expression reference line and updates
## hover state.  The actual tooltip display is handled in [method _process]
## after the hover delay elapses.
func _update_expr_ref_hover(local_mouse: Vector2) -> void:
	var hit_dist_sq := 144.0  # 12px threshold squared
	var best_dist_sq := hit_dist_sq
	var best_consumer := ""
	var best_source := ""

	for from_id in _expr_refs:
		var from_view: GNNodeView = _node_views.get(from_id, null)
		if from_view == null:
			continue
		var ref_ids: Array = _expr_refs[from_id]
		for to_id in ref_ids:
			var to_view: GNNodeView = _node_views.get(to_id, null)
			if to_view == null:
				continue
			# Replicate the screen-space coords from _draw_expr_ref_lines
			var consumer_center := from_view.position_offset + from_view.size / 2.0
			var source_center := to_view.position_offset + to_view.size / 2.0
			var p_src := (source_center - scroll_offset / zoom) * zoom
			var p_dst := (consumer_center - scroll_offset / zoom) * zoom
			# Clip to visible segment (exclude portions hidden under nodes)
			var src_rect := Rect2(
				(to_view.position_offset - scroll_offset / zoom) * zoom,
				to_view.size * zoom)
			var dst_rect := Rect2(
				(from_view.position_offset - scroll_offset / zoom) * zoom,
				from_view.size * zoom)
			var vis_start := _clip_line_to_rect_exit(p_src, p_dst, src_rect)
			var vis_end := _clip_line_to_rect_exit(p_dst, p_src, dst_rect)
			var d_sq := _point_to_segment_dist_sq(local_mouse, vis_start, vis_end)
			if d_sq < best_dist_sq:
				best_dist_sq = d_sq
				best_consumer = from_id
				best_source = to_id

	if best_consumer.is_empty():
		_expr_ref_hover_edge = ""
		_expr_ref_hover_time = 0.0
		_expr_ref_tooltip.visible = false
		return

	var edge_key := "%s→%s" % [best_consumer, best_source]
	var calls: Array = _expr_ref_details.get(edge_key, [])
	if calls.is_empty():
		_expr_ref_hover_edge = ""
		_expr_ref_hover_time = 0.0
		_expr_ref_tooltip.visible = false
		return

	# Reset timer if the user moved to a different edge
	if edge_key != _expr_ref_hover_edge:
		_expr_ref_hover_time = 0.0
		_expr_ref_tooltip.visible = false

	_expr_ref_hover_edge = edge_key
	_expr_ref_hover_mouse = local_mouse
	_expr_ref_hover_consumer = best_consumer
	_expr_ref_hover_source = best_source


## Ticks the expression-ref hover timer and shows the tooltip when the delay
## has elapsed.  Called from [method _process] so time accumulates even when
## the mouse is stationary.
func _tick_expr_ref_hover(delta: float) -> void:
	if _expr_ref_hover_edge.is_empty():
		return
	_expr_ref_hover_time += delta
	if _expr_ref_hover_time < _EXPR_REF_HOVER_DELAY:
		return
	if _expr_ref_tooltip.visible:
		return  # Already showing — no need to rebuild

	var calls: Array = _expr_ref_details.get(_expr_ref_hover_edge, [])
	if calls.is_empty():
		return

	var label: RichTextLabel = _expr_ref_tooltip.get_node("Label")
	var lines := PackedStringArray()
	lines.append("[color=#3dd9e6]%s[/color] → [color=#3dd9e6]%s[/color]" % [_expr_ref_hover_source, _expr_ref_hover_consumer])
	for c in calls:
		lines.append("  [code]%s[/code]" % str(c))
	label.text = "\n".join(lines)

	_expr_ref_tooltip.position = _expr_ref_hover_mouse + Vector2(16, -10)
	_expr_ref_tooltip.reset_size()
	_expr_ref_tooltip.visible = true


## Returns the squared distance from point [param p] to line segment [param a]-[param b].
static func _point_to_segment_dist_sq(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.001:
		return (p - a).length_squared()
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	var proj := a + ab * t
	return (p - proj).length_squared()


## Rescans expression references (if dirty) and triggers a redraw of the overlay.

# ─── Wireless node-reference hover ───────────────────────────────────────────

## Called every MouseMotion event. Converts screen pos to graph-content space,
## finds which node (if any) the mouse is over, and rebuilds _wireless_refs.
func _update_wireless_hover(local_mouse: Vector2) -> void:
	var graph_pos := local_mouse / zoom + scroll_offset / zoom
	var new_hovered := ""
	for node_id in _node_views:
		var view: GNNodeView = _node_views[node_id]
		if Rect2(view.position_offset, view.size).has_point(graph_pos):
			new_hovered = node_id
			break
	if new_hovered != _hovered_node_id:
		_hovered_node_id = new_hovered
		_rebuild_wireless_refs()
		_expr_ref_overlay.queue_redraw()


## Scans the hovered node's parameters for node_ref entries whose value
## names an existing node in the network, and populates _wireless_refs.
func _rebuild_wireless_refs() -> void:
	_wireless_refs.clear()
	if _hovered_node_id.is_empty() or network == null:
		return
	var node: GNNode = network.nodes.get(_hovered_node_id, null)
	if node == null:
		return
	var entries: Array = []
	for param_name in node.parameters:
		var param: GNParameter = node.parameters[param_name]
		if param.node_ref_family >= -1:
			var val: String = str(param.value)
			if not val.is_empty() and network.nodes.has(val):
				entries.append({"param_name": param_name, "target_id": val})
	if not entries.is_empty():
		_wireless_refs[_hovered_node_id] = entries


## Called every cook frame — the dirty flag avoids redundant full regex rescans.
func update_expr_refs() -> void:
	if _expr_refs_dirty:
		_scan_expr_references()
		_expr_refs_dirty = false
	if _expr_ref_overlay != null:
		_expr_ref_overlay.queue_redraw()


## Draws dashed lines between nodes that reference each other via expressions,
## and the ghost wire when a connection is pending (dropped on empty canvas).
## Connected to [member _expr_ref_overlay]'s `draw` signal.
func _draw_expr_ref_lines() -> void:
	# --- Selected wire highlights ---
	_draw_selected_wires()

	# --- Drop-on-wire highlight (node drag hover) ---
	_draw_drag_over_wire()

	# --- Ghost wire (pending connection drop) ---
	_draw_ghost_wire()

	# --- Wireless node reference lines (amber, hover-only) ---
	if not _wireless_refs.is_empty():
		var wire_color := Color(1.0, 0.65, 0.1, 0.45)  # Amber, translucent
		for consumer_id in _wireless_refs:
			var from_view: GNNodeView = _node_views.get(consumer_id, null)
			if from_view == null:
				continue
			var entries: Array = _wireless_refs[consumer_id]
			for entry in entries:
				var to_view: GNNodeView = _node_views.get(entry["target_id"], null)
				if to_view == null:
					continue
				var consumer_center := from_view.position_offset + from_view.size / 2.0
				var source_center := to_view.position_offset + to_view.size / 2.0
				var p_src := (source_center - scroll_offset / zoom) * zoom
				var p_dst := (consumer_center - scroll_offset / zoom) * zoom
				_draw_dashed_line_on(_expr_ref_overlay, p_src, p_dst,
						wire_color, 1.5, 6.0, 5.0)
				# Arrow at midpoint
				var src_rect := Rect2(
					(to_view.position_offset - scroll_offset / zoom) * zoom,
					to_view.size * zoom)
				var dst_rect := Rect2(
					(from_view.position_offset - scroll_offset / zoom) * zoom,
					from_view.size * zoom)
				var vis_start := _clip_line_to_rect_exit(p_src, p_dst, src_rect)
				var vis_end   := _clip_line_to_rect_exit(p_dst, p_src, dst_rect)
				var vis_mid := (vis_start + vis_end) * 0.5
				var dir := (p_dst - p_src).normalized()
				var perp := Vector2(-dir.y, dir.x)
				var arrow_size := 10.0
				var tip   := vis_mid + dir * arrow_size * 0.6
				var left  := vis_mid - dir * arrow_size * 0.4 + perp * arrow_size * 0.5
				var right := vis_mid - dir * arrow_size * 0.4 - perp * arrow_size * 0.5
				_expr_ref_overlay.draw_colored_polygon(
						PackedVector2Array([tip, left, right]), wire_color)
				# Param name label near the source node
				var label_pos := p_src + (p_dst - p_src).normalized() * 20.0 + Vector2(4, -4)
				_expr_ref_overlay.draw_string(
						ThemeDB.fallback_font, label_pos,
						entry["param_name"],
						HORIZONTAL_ALIGNMENT_LEFT, -1, 11, wire_color)



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

			# from_id = consumer (has the expression), to_id = source (referenced)
			# Draw line from source → consumer so the arrow shows data flow direction
			var consumer_center := from_view.position_offset + from_view.size / 2.0
			var source_center := to_view.position_offset + to_view.size / 2.0

			# Convert from graph-content space to overlay (screen) space
			var p_src := (source_center - scroll_offset / zoom) * zoom
			var p_dst := (consumer_center - scroll_offset / zoom) * zoom

			_draw_dashed_line_on(_expr_ref_overlay, p_src, p_dst,
					line_color, line_width, dash_length, gap_length)

			# Compute visible segment (where line exits each node's rect)
			# so the arrow sits on the visible portion, not hidden under a node
			var src_rect := Rect2(
				(to_view.position_offset - scroll_offset / zoom) * zoom,
				to_view.size * zoom)
			var dst_rect := Rect2(
				(from_view.position_offset - scroll_offset / zoom) * zoom,
				from_view.size * zoom)
			var vis_start := _clip_line_to_rect_exit(p_src, p_dst, src_rect)
			var vis_end := _clip_line_to_rect_exit(p_dst, p_src, dst_rect)
			var vis_mid := (vis_start + vis_end) * 0.5

			# Draw arrow at midpoint of visible segment
			var dir := (p_dst - p_src).normalized()
			var perp := Vector2(-dir.y, dir.x)
			var arrow_size := 12.0  # constant screen pixels
			var arrow_tip := vis_mid + dir * arrow_size * 0.6
			var arrow_left := vis_mid - dir * arrow_size * 0.4 + perp * arrow_size * 0.5
			var arrow_right := vis_mid - dir * arrow_size * 0.4 - perp * arrow_size * 0.5
			_expr_ref_overlay.draw_colored_polygon(
					PackedVector2Array([arrow_tip, arrow_left, arrow_right]), line_color)


## Finds where the line from [param origin] to [param target] exits [param rect].
func _clip_line_to_rect_exit(origin: Vector2, target: Vector2, rect: Rect2) -> Vector2:
	if not rect.has_point(origin):
		return origin
	var dir := target - origin
	if dir.length_squared() < 0.001:
		return origin
	# Test intersection with all 4 edges, keep the nearest positive t
	var best_t := INF
	# Left edge
	if abs(dir.x) > 0.001:
		var t := (rect.position.x - origin.x) / dir.x
		if t > 0.0 and t < best_t:
			var y := origin.y + dir.y * t
			if y >= rect.position.y and y <= rect.end.y:
				best_t = t
		# Right edge
		t = (rect.end.x - origin.x) / dir.x
		if t > 0.0 and t < best_t:
			var y2 := origin.y + dir.y * t
			if y2 >= rect.position.y and y2 <= rect.end.y:
				best_t = t
	# Top edge
	if abs(dir.y) > 0.001:
		var t := (rect.position.y - origin.y) / dir.y
		if t > 0.0 and t < best_t:
			var x := origin.x + dir.x * t
			if x >= rect.position.x and x <= rect.end.x:
				best_t = t
		# Bottom edge
		t = (rect.end.y - origin.y) / dir.y
		if t > 0.0 and t < best_t:
			var x2 := origin.x + dir.x * t
			if x2 >= rect.position.x and x2 <= rect.end.x:
				best_t = t
	if best_t < INF:
		return origin + dir * best_t
	return origin


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


## Returns the node-view ID under the given graph-space position, or "" if none.
func _get_node_id_at(graph_pos: Vector2) -> String:
	for view_name in _node_views:
		var view: GNNodeView = _node_views[view_name]
		var rect := Rect2(view.position_offset, view.size)
		if rect.has_point(graph_pos):
			return view_name
	return ""


## Returns true if any node view occupies the given graph-space position.
func _is_node_at_position(local_pos: Vector2) -> bool:
	var graph_pos: Vector2 = (local_pos + scroll_offset) / zoom
	return not _get_node_id_at(graph_pos).is_empty()


## If a node is under the given graph-space position and it is not already
## selected, deselect everything else and select just that node.  This ensures
## the right-click context menu always targets the node under the cursor.
func _select_node_under_cursor(graph_pos: Vector2) -> void:
	var hit_id := _get_node_id_at(graph_pos)
	if hit_id.is_empty():
		return  # Clicked on empty canvas — leave selection as-is
	var view: GNNodeView = _node_views.get(hit_id, null)
	if view == null:
		return
	if view.selected:
		return  # Already selected — keep current (possibly multi-) selection
	_deselect_all()
	view.selected = true
	if view.gn_node:
		operator_selected.emit(view.gn_node.id)


## Attempts to dive into the selected SubNetworkNode (if exactly one is selected).
func _try_dive_into_selected() -> void:
	var selected := _get_selected_node_ids()
	if selected.size() != 1:
		return
	var node: GNNode = network.get_node_by_id(selected[0])
	if node is SubNetworkNode:
		dive_into_requested.emit(selected[0])

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
## If [param target_graph_pos] is provided, nodes are centered there instead of
## the current mouse position.
func paste_clipboard(target_graph_pos := Vector2(INF, INF)) -> void:
	if _clipboard.is_empty() or not _clipboard.has("nodes"):
		return
	if network == null or read_only:
		return

	var nodes_data: Dictionary = _clipboard["nodes"]
	var conns_data: Array = _clipboard.get("connections", [])

	# Build ID remap: old_id → new_id
	var id_remap: Dictionary = {}
	var new_nodes: Array[GNNode] = []

	# Compute the centroid of the original nodes so we can re-center the
	# pasted group at the current mouse cursor position.
	var centroid := Vector2.ZERO
	var node_count := 0
	for old_id in nodes_data:
		var nd: Dictionary = nodes_data[old_id]
		var raw_pos = nd.get("position", null)
		if raw_pos is Array and raw_pos.size() >= 2:
			centroid += Vector2(float(raw_pos[0]), float(raw_pos[1]))
		elif raw_pos is Vector2:
			centroid += raw_pos
		node_count += 1
	if node_count > 0:
		centroid /= float(node_count)

	# Target position: use explicit target if provided, otherwise fall back to
	# the current mouse cursor in graph space.
	var mouse_graph_pos: Vector2
	if target_graph_pos.x != INF:
		mouse_graph_pos = target_graph_pos
	else:
		mouse_graph_pos = (get_local_mouse_position() + scroll_offset) / zoom
	var paste_offset := mouse_graph_pos - centroid

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

		# Offset position so pasted group is centered at the mouse cursor
		node.graph_position += paste_offset

		id_remap[old_id] = new_id
		new_nodes.append(node)

	# Remap expression references and wireless node-reference params inside
	# pasted nodes so that chop("slider1", "value") becomes
	# chop("slider1_copy", "value") when slider1 was also pasted.
	_remap_pasted_references(new_nodes, id_remap)

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

	# Sync dynamic port counts — trim ports that had connections in the
	# source patch but not in the paste (e.g. pasting a single SwitchTOP
	# that originally had 20 inputs).
	for node in new_nodes:
		if node._dynamic_input:
			network._update_dynamic_node_inputs(node.id)

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


## Remaps node-ID references inside expressions, component expressions,
## script code bodies, and wireless node-reference parameters of pasted nodes
## so that they point at the pasted copies instead of the originals.
func _remap_pasted_references(pasted_nodes: Array[GNNode], id_remap: Dictionary) -> void:
	for node in pasted_nodes:
		for param_name in node.parameters:
			var param: GNParameter = node.parameters[param_name]

			# Main expression
			if param.mode == GNParameter.Mode.EXPRESSION and not param.expression.is_empty():
				var updated := param.expression
				for old_id in id_remap:
					updated = network._replace_id_in_expr(updated, old_id, id_remap[old_id])
				if updated != param.expression:
					param.set_expression(updated)

			# Per-component expressions (Vector2/3/4, Color)
			for i in range(param.component_expressions.size()):
				if param.component_modes.size() > i and \
						param.component_modes[i] == GNParameter.Mode.EXPRESSION:
					var comp_expr: String = param.component_expressions[i]
					if not comp_expr.is_empty():
						var updated := comp_expr
						for old_id in id_remap:
							updated = network._replace_id_in_expr(updated, old_id, id_remap[old_id])
						if updated != comp_expr:
							param.component_expressions[i] = updated
							param._compile_component_expression(i)

		# Script operator code bodies
		if node.node_type in network._SCRIPT_NODE_TYPES:
			var code_param: GNParameter = node.parameters.get("code", null)
			if code_param != null:
				var code_val: String = code_param.value if code_param.value is String else ""
				if not code_val.is_empty():
					var updated := code_val
					for old_id in id_remap:
						if old_id in updated:
							updated = network._replace_id_in_expr(updated, old_id, id_remap[old_id])
					if updated != code_val:
						node.set_param_value("code", updated)

		# CallbackDAT script slots
		if node.node_type == "callbackdat":
			for cb_param_name in network._CALLBACK_CODE_PARAMS:
				var cb_param: GNParameter = node.parameters.get(cb_param_name, null)
				if cb_param != null:
					var cb_val: String = cb_param.value if cb_param.value is String else ""
					if not cb_val.is_empty():
						var updated := cb_val
						for old_id in id_remap:
							if old_id in updated:
								updated = network._replace_id_in_expr(updated, old_id, id_remap[old_id])
						if updated != cb_val:
							node.set_param_value(cb_param_name, updated)

		# Wireless node-reference string parameters (Select ops, ParameterCHOP, etc.)
		var ref_params: Dictionary = node.get_node_reference_params()
		for ref_param_name in ref_params:
			var ref_param: GNParameter = node.parameters.get(ref_param_name, null)
			if ref_param == null:
				continue
			var val: String = str(ref_param.value)
			for old_id in id_remap:
				if val == old_id:
					val = id_remap[old_id]
				elif "/" in val:
					val = network._replace_path_segment(val, old_id, id_remap[old_id])
			if val != str(ref_param.value):
				node.set_param_value(ref_param_name, val)


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
## The overlay panel is built once and then shown/hidden on subsequent toggles.
func toggle_shortcut_overlay() -> void:
	if _shortcut_overlay != null:
		# Already built — just toggle visibility and re-center.
		_shortcut_overlay.visible = not _shortcut_overlay.visible
		if _shortcut_overlay.visible:
			_shortcut_overlay.position = (size - _shortcut_overlay.size) / 2
		return

	# First-time build
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
		["─── Wire Selection ───", ""],
		["Click Wire", "Select Wire"],
		["Shift + Click Wire", "Add Wire to Selection"],
		["Delete", "Delete Selected Wires/Nodes"],
		["Dbl-Click Wire", "Insert Node on Wire"],
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
## Emits wire_style_changed so the editor can persist.
func cycle_wire_style() -> int:
	var idx := (_wire_style + 1) % _WIRE_CURVATURES.size()
	set_wire_style(idx)
	wire_style_changed.emit(idx)
	return idx

## Sets the wire style by index (0=curved, 1=straight, 2=right-angle).
func set_wire_style(idx: int) -> void:
	_wire_style = clampi(idx, 0, _WIRE_CURVATURES.size() - 1)
	connection_lines_curvature = _WIRE_CURVATURES[_wire_style]
	queue_redraw()


# ═══════════════════════════════════════════════════════════════════════════════
# Wire Selection & Drag-to-Insert
# ═══════════════════════════════════════════════════════════════════════════════

## Converts a GraphEdit connection dict (StringName keys) to our canonical form.
func _wire_dict_from_graphedit(d: Dictionary) -> Dictionary:
	return {
		"from_node": String(d.get("from_node", d.get("from", ""))),
		"from_port": int(d.get("from_port", 0)),
		"to_node": String(d.get("to_node", d.get("to", ""))),
		"to_port": int(d.get("to_port", 0)),
	}


## Returns the index in _selected_wires matching the given connection, or -1.
func _find_wire_index(conn: Dictionary) -> int:
	var fn := String(conn.get("from_node", conn.get("from", "")))
	var fp := int(conn.get("from_port", 0))
	var tn := String(conn.get("to_node", conn.get("to", "")))
	var tp := int(conn.get("to_port", 0))
	for i in range(_selected_wires.size()):
		var w: Dictionary = _selected_wires[i]
		if w["from_node"] == fn and w["from_port"] == fp \
				and w["to_node"] == tn and w["to_port"] == tp:
			return i
	return -1


## Deletes all currently selected wires with undo support.
func _delete_selected_wires() -> void:
	if _selected_wires.is_empty() or network == null:
		return

	var to_delete := _selected_wires.duplicate()
	_selected_wires.clear()

	_undo_redo.create_action("Delete %d wire(s)" % to_delete.size())
	for w in to_delete:
		var fn: String = w["from_node"]
		var fp: int = w["from_port"]
		var tn: String = w["to_node"]
		var tp: int = w["to_port"]
		network.disconnect_nodes(fn, fp, tn, tp)
		_undo_redo.add_do_method(_ur_disconnect.bind(fn, fp, tn, tp))
		_undo_redo.add_undo_method(_ur_connect.bind(fn, fp, tn, tp))
	_undo_redo.commit_action(false)

	_expr_ref_overlay.queue_redraw()
	GNLogger.info("GraphEditor", "Deleted %d wire(s)" % to_delete.size())


## After a box-select gesture ends, select wires that intersect the actual
## drag rectangle.  This allows selecting a single wire by drawing a box
## across it, even without selecting either endpoint node.
func _update_wire_box_selection() -> void:
	if _box_select_origin.x < 0:
		return  # No box-select gesture was in progress

	var release_pos := get_local_mouse_position()
	# Build the rect in local (screen) space from the two corners
	var top_left := Vector2(
		minf(_box_select_origin.x, release_pos.x),
		minf(_box_select_origin.y, release_pos.y))
	var bot_right := Vector2(
		maxf(_box_select_origin.x, release_pos.x),
		maxf(_box_select_origin.y, release_pos.y))
	var local_rect := Rect2(top_left, bot_right - top_left)

	# Skip tiny rects (plain clicks, not real box drags)
	if local_rect.size.x < 4.0 and local_rect.size.y < 4.0:
		return

	var intersecting: Array = get_connections_intersecting_with_rect(local_rect)
	var changed := false
	for conn_dict in intersecting:
		var w := _wire_dict_from_graphedit(conn_dict)
		if _find_wire_index(w) < 0:
			_selected_wires.append(w)
			changed = true

	if changed:
		_expr_ref_overlay.queue_redraw()


## Clears wire selection.  Called when the user clicks empty space or Escape.
func deselect_wires() -> void:
	if not _selected_wires.is_empty():
		_selected_wires.clear()
		_expr_ref_overlay.queue_redraw()


## Returns the port position in graph-content space for a given node/port.
func _get_port_graph_pos(node_id: String, port_idx: int, is_output: bool) -> Vector2:
	var view: GNNodeView = _node_views.get(node_id, null)
	if view == null:
		return Vector2.ZERO
	var local_pos: Vector2
	if is_output:
		local_pos = view.get_output_port_position(port_idx)
	else:
		local_pos = view.get_input_port_position(port_idx)
	return view.position_offset + local_pos


## Draws highlight outlines on selected wires, matching the actual curve.
## Uses GraphEdit.get_connection_line() so straight / curved / right-angle
## styles are all respected.
func _draw_selected_wires() -> void:
	if _selected_wires.is_empty():
		return

	var highlight_color := Color(1.0, 0.85, 0.2, 0.9)  # Gold/yellow
	var highlight_width := connection_lines_thickness
	var glow_color := Color(1.0, 0.85, 0.2, 0.15)
	var glow_width := connection_lines_thickness + 4.0

	for w in _selected_wires:
		var from_graph := _get_port_graph_pos(w["from_node"], w["from_port"], true)
		var to_graph := _get_port_graph_pos(w["to_node"], w["to_port"], false)

		# Convert to overlay (local screen) space
		var p1 := (from_graph - scroll_offset / zoom) * zoom
		var p2 := (to_graph - scroll_offset / zoom) * zoom

		# Ask GraphEdit for the actual bezier / straight / right-angle points
		var pts: PackedVector2Array = get_connection_line(p1, p2)
		if pts.size() >= 2:
			_expr_ref_overlay.draw_polyline(pts, glow_color, glow_width, true)
			_expr_ref_overlay.draw_polyline(pts, highlight_color, highlight_width, true)
		else:
			# Fallback for degenerate case
			_expr_ref_overlay.draw_line(p1, p2, highlight_color, highlight_width, true)


# ═══════════════════════════════════════════════════════════════════════════════
# Drop-on-Wire (Houdini-style)
# ═══════════════════════════════════════════════════════════════════════════════

## Called every frame during an active single-node drag.  Checks whether the
## dragged node's center is hovering over a wire that is compatible with the
## node's I/O.  Updates [member _drag_over_wire] and triggers overlay redraws.
func _update_drag_over_wire() -> void:
	if not _node_drag_active or _pre_move_positions.size() != 1 or network == null:
		if not _drag_over_wire.is_empty():
			_drag_over_wire = {}
			_drag_wire_in_port = -1
			_drag_wire_out_port = -1
			_expr_ref_overlay.queue_redraw()
		return

	var dragged_id: String = _pre_move_positions.keys()[0]
	var view: GNNodeView = _node_views.get(dragged_id, null)
	if view == null:
		return

	# Get the center of the dragged node in local (overlay) pixel space
	var center_graph := view.position_offset + view.size / 2.0
	var center_local := (center_graph - scroll_offset / zoom) * zoom

	# Hit-test wires
	var hit := get_closest_connection_at_point(center_local, _DRAG_WIRE_HIT_DISTANCE)
	if hit.is_empty():
		if not _drag_over_wire.is_empty():
			_drag_over_wire = {}
			_drag_wire_in_port = -1
			_drag_wire_out_port = -1
			_expr_ref_overlay.queue_redraw()
		return

	var wire := _wire_dict_from_graphedit(hit)

	# Skip wires that already connect to/from the dragged node
	if wire["from_node"] == dragged_id or wire["to_node"] == dragged_id:
		if not _drag_over_wire.is_empty():
			_drag_over_wire = {}
			_drag_wire_in_port = -1
			_drag_wire_out_port = -1
			_expr_ref_overlay.queue_redraw()
		return

	# Check I/O compatibility of the dragged node with this wire
	var from_node: GNNode = network.get_node_by_id(wire["from_node"])
	var to_node: GNNode = network.get_node_by_id(wire["to_node"])
	if from_node == null or to_node == null:
		return

	var out_port: GNPort = from_node.get_output_port(wire["from_port"])
	var in_port: GNPort = to_node.get_input_port(wire["to_port"])
	if out_port == null or in_port == null:
		return

	var dragged_node: GNNode = network.get_node_by_id(dragged_id)
	if dragged_node == null:
		return

	# Find a compatible input port on the dragged node (accepts upstream family)
	var compat_in: int = -1
	for port: GNPort in dragged_node.input_ports:
		if port.family == out_port.family:
			compat_in = port.index
			break
	# Find a compatible output port on the dragged node (produces downstream family)
	var compat_out: int = -1
	for port: GNPort in dragged_node.output_ports:
		if port.family == in_port.family:
			compat_out = port.index
			break

	if compat_in < 0 or compat_out < 0:
		if not _drag_over_wire.is_empty():
			_drag_over_wire = {}
			_drag_wire_in_port = -1
			_drag_wire_out_port = -1
			_expr_ref_overlay.queue_redraw()
		return

	# Only redraw if the hovered wire changed
	if _drag_over_wire != wire:
		_drag_over_wire = wire
		_drag_wire_in_port = compat_in
		_drag_wire_out_port = compat_out
		_expr_ref_overlay.queue_redraw()


## Draws a green glow on the wire the dragged node is hovering over.
func _draw_drag_over_wire() -> void:
	if _drag_over_wire.is_empty():
		return

	var accent := Color(0.2, 1.0, 0.4, 0.9)   # Bright green
	var glow := Color(0.2, 1.0, 0.4, 0.18)

	var from_graph := _get_port_graph_pos(
			_drag_over_wire["from_node"], _drag_over_wire["from_port"], true)
	var to_graph := _get_port_graph_pos(
			_drag_over_wire["to_node"], _drag_over_wire["to_port"], false)

	var p1 := (from_graph - scroll_offset / zoom) * zoom
	var p2 := (to_graph - scroll_offset / zoom) * zoom

	var pts: PackedVector2Array = get_connection_line(p1, p2)
	if pts.size() >= 2:
		_expr_ref_overlay.draw_polyline(pts, glow, connection_lines_thickness + 6.0, true)
		_expr_ref_overlay.draw_polyline(pts, accent, connection_lines_thickness + 1.0, true)
	else:
		_expr_ref_overlay.draw_line(p1, p2, accent, connection_lines_thickness + 1.0, true)

	# Draw a small "+" indicator at the wire midpoint
	var mid := (p1 + p2) / 2.0
	var arm := 6.0
	_expr_ref_overlay.draw_line(mid - Vector2(arm, 0), mid + Vector2(arm, 0), accent, 2.0, true)
	_expr_ref_overlay.draw_line(mid - Vector2(0, arm), mid + Vector2(0, arm), accent, 2.0, true)


## Splices an already-existing dragged node into a wire.  Handles:
##   - Disconnecting the old wire
##   - Snapping the node to the wire midpoint
##   - Connecting from → dragged → to
##   - Cascading surrounding nodes apart
##   - Full undo/redo support (move + splice as one action)
func _perform_drag_wire_splice(wire: Dictionary, in_port: int, out_port: int) -> void:
	if network == null:
		return

	var dragged_id: String = _pre_move_positions.keys()[0]
	var dragged_view: GNNodeView = _node_views.get(dragged_id, null)
	if dragged_view == null:
		return

	var fn: String = wire["from_node"]
	var fp: int = wire["from_port"]
	var tn: String = wire["to_node"]
	var tp: int = wire["to_port"]

	var from_view: GNNodeView = _node_views.get(fn, null)
	var to_view: GNNodeView = _node_views.get(tn, null)

	# Calculate midpoint to position the dragged node
	var mid_pos: Vector2
	if from_view and to_view:
		mid_pos = (from_view.position_offset + to_view.position_offset) / 2.0
		# Center the node horizontally at the midpoint
		mid_pos.x -= dragged_view.size.x / 2.0
		# Vertically center between the two nodes
		var from_center_y := from_view.position_offset.y + from_view.size.y / 2.0
		var to_center_y := to_view.position_offset.y + to_view.size.y / 2.0
		mid_pos.y = (from_center_y + to_center_y) / 2.0 - dragged_view.size.y / 2.0
	else:
		mid_pos = dragged_view.position_offset

	# Snap-record the original position for undo
	var old_pos: Vector2 = _pre_move_positions.get(dragged_id, dragged_view.position_offset)

	# Move node to midpoint
	dragged_view.position_offset = mid_pos
	if dragged_view.gn_node:
		dragged_view.gn_node.graph_position = mid_pos

	# Remove old wire
	network.disconnect_nodes(fn, fp, tn, tp)
	disconnect_node(fn, fp, tn, tp)

	# Connect: from → dragged → to
	var ok1 := network.connect_nodes(fn, fp, dragged_id, in_port)
	var ok2 := network.connect_nodes(dragged_id, out_port, tn, tp)
	connect_node(fn, fp, dragged_id, in_port)
	connect_node(dragged_id, out_port, tn, tp)

	# Record full undo: move + splice
	_undo_redo.create_action("Drop %s onto wire" % dragged_id)

	# Undo = restore old connections + move back
	_undo_redo.add_undo_method(_ur_disconnect.bind(fn, fp, dragged_id, in_port))
	_undo_redo.add_undo_method(_ur_disconnect.bind(dragged_id, out_port, tn, tp))
	_undo_redo.add_undo_method(_ur_connect.bind(fn, fp, tn, tp))
	_undo_redo.add_undo_method(_ur_set_positions.bind({dragged_id: old_pos}))

	# Redo = move + splice
	_undo_redo.add_do_method(_ur_set_positions.bind({dragged_id: mid_pos}))
	_undo_redo.add_do_method(_ur_disconnect.bind(fn, fp, tn, tp))
	_undo_redo.add_do_method(_ur_connect.bind(fn, fp, dragged_id, in_port))
	_undo_redo.add_do_method(_ur_connect.bind(dragged_id, out_port, tn, tp))

	# Cascade nodes apart if needed
	var moved := _make_room_for_insert(fn, tn, dragged_id)
	if not moved.is_empty():
		_undo_redo.add_undo_method(_ur_animate_positions.bind(moved))

	_undo_redo.commit_action(false)

	_pre_move_positions.clear()
	_node_drag_ann_info.clear()

	if ok1 and ok2:
		GNLogger.info("GraphEditor", "Dropped '%s' onto wire %s:%d → %s:%d" % [
			dragged_id, fn, fp, tn, tp])
	else:
		GNLogger.warn("GraphEditor", "Drop-on-wire partially failed: %s → %s → %s" % [
			fn, dragged_id, tn])


## Shake-to-disconnect: remove the dragged node from its chain(s) and
## re-wire upstream→downstream directly.  Only works for single-node drags
## where the node has at least one through-connection (in→out on port 0).
func _perform_shake_disconnect(node_id: String) -> void:
	if network == null:
		return

	var in_conns: Array = network.get_input_connections(node_id)
	var out_conns: Array = network.get_output_connections(node_id)

	if in_conns.is_empty() and out_conns.is_empty():
		return  # Nothing to disconnect

	_undo_redo.create_action("Shake-disconnect '%s'" % node_id)

	# Build bypass pairs: for each input port, find matching output port wires.
	# Port 0→0 is the most common "pass-through" case.
	var bypass_pairs: Array = []  # Array of { from, fp, to, tp }
	for ic in in_conns:
		for oc in out_conns:
			if ic.to_port == oc.from_port:
				bypass_pairs.append({
					"from": ic.from_node, "fp": ic.from_port,
					"to": oc.to_node, "tp": oc.to_port,
				})

	# Disconnect all wires from/to this node
	for ic in in_conns:
		network.disconnect_nodes(ic.from_node, ic.from_port, node_id, ic.to_port)
		disconnect_node(ic.from_node, ic.from_port, node_id, ic.to_port)
		_undo_redo.add_undo_method(_ur_connect.bind(
			ic.from_node, ic.from_port, node_id, ic.to_port))
		_undo_redo.add_do_method(_ur_disconnect.bind(
			ic.from_node, ic.from_port, node_id, ic.to_port))

	for oc in out_conns:
		network.disconnect_nodes(node_id, oc.from_port, oc.to_node, oc.to_port)
		disconnect_node(node_id, oc.from_port, oc.to_node, oc.to_port)
		_undo_redo.add_undo_method(_ur_connect.bind(
			node_id, oc.from_port, oc.to_node, oc.to_port))
		_undo_redo.add_do_method(_ur_disconnect.bind(
			node_id, oc.from_port, oc.to_node, oc.to_port))

	# Reconnect bypass pairs (upstream → downstream directly)
	for bp in bypass_pairs:
		network.connect_nodes(bp["from"], bp["fp"], bp["to"], bp["tp"])
		connect_node(bp["from"], bp["fp"], bp["to"], bp["tp"])
		_undo_redo.add_do_method(_ur_connect.bind(
			bp["from"], bp["fp"], bp["to"], bp["tp"]))
		_undo_redo.add_undo_method(_ur_disconnect.bind(
			bp["from"], bp["fp"], bp["to"], bp["tp"]))

	_undo_redo.commit_action(false)

	var wire_count := in_conns.size() + out_conns.size()
	var wire_label := "wire" if wire_count == 1 else "wires"
	show_toast("Disconnected %d %s from %s" % [wire_count, wire_label, node_id], ToastType.INFO, 1.5)
	GNLogger.info("GraphEditor", "Shake-disconnect '%s' (%d bypass pairs)" % [
		node_id, bypass_pairs.size()])


## Initiates a wire drag-to-insert: the user has selected a wire by clicking it,
## then drags on it.  When released, opens a filtered palette showing operators
## that can sit between the two connected nodes (accepts the output family as
## input AND produces the input family as output).
func _begin_wire_insert(wire: Dictionary) -> void:
	if network == null:
		return

	var from_node: GNNode = network.get_node_by_id(wire["from_node"])
	var to_node: GNNode = network.get_node_by_id(wire["to_node"])
	if from_node == null or to_node == null:
		return

	var out_port: GNPort = from_node.get_output_port(wire["from_port"])
	var in_port: GNPort = to_node.get_input_port(wire["to_port"])
	if out_port == null or in_port == null:
		return

	# For insert, the new node must accept the upstream family AND produce
	# the downstream family.  Often these are the same (e.g. TOP→TOP→TOP).
	_wire_insert_pending = {
		"from_node": wire["from_node"],
		"from_port": wire["from_port"],
		"to_node": wire["to_node"],
		"to_port": wire["to_port"],
		"out_family": out_port.family,
		"in_family": in_port.family,
	}

	# Position the new node at the midpoint of the two connected nodes
	var from_view: GNNodeView = _node_views.get(wire["from_node"], null)
	var to_view: GNNodeView = _node_views.get(wire["to_node"], null)
	if from_view and to_view:
		_spawn_position = (from_view.position_offset + to_view.position_offset) / 2.0
	else:
		_spawn_position = (get_local_mouse_position() + scroll_offset) / zoom

	# Get operators that accept the upstream family as input
	var registry := GNExtensionRegistry.instance()
	var accept_in := registry.get_operators_accepting_family(out_port.family)

	# If the families differ (rare — e.g. TOP→IMG bridge), also filter by
	# output family.  In the common case (same family), this is a no-op.
	var allowed := PackedStringArray()
	if out_port.family == in_port.family:
		for op_name in accept_in:
			allowed.append(op_name)
	else:
		var produce_out := registry.get_operators_producing_family(in_port.family)
		var produce_set: Dictionary = {}
		for op_name in produce_out:
			produce_set[op_name] = true
		for op_name in accept_in:
			if produce_set.has(op_name):
				allowed.append(op_name)

	_palette.popup_at_filtered(
		get_screen_position() + get_local_mouse_position(), allowed)


## Called from _on_palette_node_selected — if _wire_insert_pending is active,
## splices the new node into the existing wire.
func _try_wire_insert_splice(new_node: GNNode) -> void:
	if _wire_insert_pending.is_empty():
		return

	var wp := _wire_insert_pending
	_wire_insert_pending = {}

	var fn: String = wp["from_node"]
	var fp: int = wp["from_port"]
	var tn: String = wp["to_node"]
	var tp: int = wp["to_port"]
	var out_family: int = wp["out_family"]
	var in_family: int = wp["in_family"]

	# Find the first compatible input port on the new node
	var new_input_port: int = -1
	for port: GNPort in new_node.input_ports:
		if port.family == out_family:
			new_input_port = port.index
			break
	if new_input_port < 0:
		return

	# Find the first compatible output port on the new node
	var new_output_port: int = -1
	for port: GNPort in new_node.output_ports:
		if port.family == in_family:
			new_output_port = port.index
			break
	if new_output_port < 0:
		return

	# Remove the old wire
	network.disconnect_nodes(fn, fp, tn, tp)
	# Also force-remove the visual wire in case the signal handler missed it
	# (can happen if GraphEdit's internal state holds a stale connection).
	disconnect_node(fn, fp, tn, tp)

	# Connect: old_from → new_node → old_to
	var ok1 := network.connect_nodes(fn, fp, new_node.id, new_input_port)
	var ok2 := network.connect_nodes(new_node.id, new_output_port, tn, tp)
	# Force visual wires in case signal-based add didn't fire
	connect_node(fn, fp, new_node.id, new_input_port)
	connect_node(new_node.id, new_output_port, tn, tp)

	# Record undo
	_undo_redo.create_action("Insert %s into wire" % new_node.id)
	_undo_redo.add_do_method(_ur_disconnect.bind(fn, fp, tn, tp))
	_undo_redo.add_do_method(_ur_connect.bind(fn, fp, new_node.id, new_input_port))
	_undo_redo.add_do_method(_ur_connect.bind(new_node.id, new_output_port, tn, tp))
	_undo_redo.add_undo_method(_ur_disconnect.bind(fn, fp, new_node.id, new_input_port))
	_undo_redo.add_undo_method(_ur_disconnect.bind(new_node.id, new_output_port, tn, tp))
	_undo_redo.add_undo_method(_ur_connect.bind(fn, fp, tn, tp))

	_selected_wires.clear()
	_expr_ref_overlay.queue_redraw()

	# Animate surrounding nodes apart if there isn't enough room.
	# Returns the original positions of all moved nodes for undo.
	var moved := _make_room_for_insert(fn, tn, new_node.id)
	if not moved.is_empty():
		# On undo, animate nodes back to their original positions.
		_undo_redo.add_undo_method(_ur_animate_positions.bind(moved))
	_undo_redo.commit_action(false)

	if ok1 and ok2:
		GNLogger.info("GraphEditor", "Inserted '%s' between %s:%d → %s:%d" % [
			new_node.id, fn, fp, tn, tp])
	else:
		GNLogger.warn("GraphEditor", "Wire insert partially failed: %s → %s → %s" % [
			fn, new_node.id, tn])


## Checks whether the new node fits between the upstream and downstream nodes.
## If the horizontal gap is too tight, cascades a push outward so no nodes
## overlap.  Returns a dict of { node_id: original_position } for all nodes
## that were moved (empty if no push was needed).
const _INSERT_PAD := 40.0  # Extra pixels of breathing room on each side.
const _INSERT_ANIM_DURATION := 0.25  # Seconds for the slide animation.

func _make_room_for_insert(from_id: String, to_id: String, new_id: String) -> Dictionary:
	var new_view: GNNodeView = _node_views.get(new_id, null)
	if new_view == null:
		return {}

	var new_width: float = new_view.size.x
	var needed_half: float = new_width / 2.0 + _INSERT_PAD

	# Collect all node views sorted by X position for collision cascading.
	var all_views: Array[GNNodeView] = []
	for nid in _node_views:
		all_views.append(_node_views[nid])
	all_views.sort_custom(func(a: GNNodeView, b: GNNodeView) -> bool:
		return a.position_offset.x < b.position_offset.x)

	# Build a map of original positions before any moves.
	var original_positions: Dictionary = {}  # node_id → Vector2
	var targets: Dictionary = {}  # node_id → Vector2 (final position)

	# ── Push left chain (from_id and everything to its left) ──
	var from_view: GNNodeView = _node_views.get(from_id, null)
	if from_view != null:
		var new_center_x: float = new_view.position_offset.x + new_width / 2.0
		var from_right: float = from_view.position_offset.x + from_view.size.x
		var required_right: float = new_center_x - needed_half
		if from_right > required_right:
			var push_left: float = from_right - required_right
			# Push from_view left, then cascade to anything it now overlaps.
			_cascade_push(from_view, -push_left, all_views, original_positions, targets)

	# ── Push right chain (to_id and everything to its right) ──
	var to_view: GNNodeView = _node_views.get(to_id, null)
	if to_view != null:
		var new_center_x: float = new_view.position_offset.x + new_width / 2.0
		var to_left: float = to_view.position_offset.x
		var required_left: float = new_center_x + needed_half
		if to_left < required_left:
			var push_right: float = required_left - to_left
			_cascade_push(to_view, push_right, all_views, original_positions, targets)

	if targets.is_empty():
		return {}

	# Animate all affected nodes to their targets.
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_CUBIC)
	for nid in targets:
		var v: GNNodeView = _node_views.get(nid, null)
		if v != null:
			tw.tween_property(v, "position_offset", targets[nid], _INSERT_ANIM_DURATION)
	tw.finished.connect(func():
		for nid2 in targets:
			var v2: GNNodeView = _node_views.get(nid2, null)
			if v2 != null and v2.gn_node:
				v2.gn_node.graph_position = v2.position_offset
	)

	return original_positions


## Pushes [param start_view] by [param delta_x] (negative = left, positive = right)
## and recursively pushes any node it would collide with in that direction.
## Records original positions and final targets for undo and animation.
func _cascade_push(start_view: GNNodeView, delta_x: float,
		all_views: Array[GNNodeView], original_positions: Dictionary,
		targets: Dictionary) -> void:
	var nid: String = start_view.name
	# Prevent infinite recursion — if already targeted, skip.
	if targets.has(nid):
		return
	# Record original position.
	original_positions[nid] = start_view.position_offset

	var new_pos := start_view.position_offset + Vector2(delta_x, 0)
	targets[nid] = new_pos

	var new_left: float = new_pos.x
	var new_right: float = new_pos.x + start_view.size.x

	# Check if the new position overlaps with a neighbour in the push direction.
	if delta_x < 0:
		# Pushing left — cascade into nodes that are to our left.
		for v in all_views:
			if v == start_view or targets.has(v.name):
				continue
			var v_right: float = v.position_offset.x + v.size.x
			# Only consider nodes whose right edge was to the left of (or touching)
			# our original left edge — i.e., nodes that are to our left.
			if v_right <= start_view.position_offset.x + 1.0:
				if v_right + _INSERT_PAD > new_left:
					var push: float = v_right + _INSERT_PAD - new_left
					_cascade_push(v, -push, all_views, original_positions, targets)
	else:
		# Pushing right — cascade into nodes that are to our right.
		for v in all_views:
			if v == start_view or targets.has(v.name):
				continue
			var v_left: float = v.position_offset.x
			# Only consider nodes whose left edge was to the right of (or touching)
			# our original right edge.
			var orig_right: float = start_view.position_offset.x + start_view.size.x
			if v_left >= orig_right - 1.0:
				if v_left < new_right + _INSERT_PAD:
					var push: float = new_right + _INSERT_PAD - v_left
					_cascade_push(v, push, all_views, original_positions, targets)


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
	# Move first. Selecting rebuilds the inspector, and doing that before the
	# scroll made the jump wait on that rebuild.
	scroll_to_node(node_id)
	for vn in _node_views:
		var other: GNNodeView = _node_views[vn]
		var should_select := other == view
		if other.selected != should_select:
			other.selected = should_select
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
	# clear(true) frees the Load Preset submenu. queue_free on that submenu
	# while the menu still owns it crashes the engine, with no script error,
	# the next time this menu opens.
	if _context_menu.visible:
		_context_menu.hide()
	_context_menu.clear(true)
	_param_preset_submenu = null

	var has_selection := not _get_selected_node_ids().is_empty()
	var has_clipboard := not _clipboard.is_empty()

	# Always available
	_context_menu.add_item("Add Node…", _CtxID.ADD_NODE)
	_context_menu.set_item_shortcut(_context_menu.get_item_index(_CtxID.ADD_NODE), _shortcut(KEY_A, false, true), true)
	_context_menu.add_item("Add Network Box", _CtxID.ADD_NETWORK_BOX)
	_context_menu.add_item("Add Sticky Note", _CtxID.ADD_STICKY_NOTE)
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
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.DELETE), not has_selection and _selected_wires.is_empty())

	var has_wires := not _selected_wires.is_empty()
	_context_menu.add_item("Delete Wire(s)", _CtxID.DELETE_WIRES)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.DELETE_WIRES), not has_wires)

	var single_wire := _selected_wires.size() == 1
	_context_menu.add_item("Insert Node on Wire...", _CtxID.INSERT_NODE_ON_WIRE)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.INSERT_NODE_ON_WIRE), not single_wire)

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

	# Viewer window — enabled when exactly one node is selected (any family)
	var selected_ids := _get_selected_node_ids()
	var single_node_selected := selected_ids.size() == 1
	_context_menu.add_separator()
	_context_menu.add_item("Open Viewer", _CtxID.OPEN_VIEWER)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.OPEN_VIEWER), not single_node_selected)

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

	_context_menu.add_item("Group into Sub-Network", _CtxID.GROUP_SELECTED)
	_context_menu.set_item_shortcut(_context_menu.get_item_index(_CtxID.GROUP_SELECTED), _shortcut(KEY_G, true), true)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.GROUP_SELECTED), not has_selection)

	# Promote to Custom Asset — enabled when exactly one SubNetworkNode is selected
	var is_single_subnet := false
	var is_single_custom_asset := false
	if selected_ids.size() == 1 and network != null:
		var subnet_node: GNNode = network.get_node_by_id(selected_ids[0])
		if subnet_node is SubNetworkNode:
			is_single_subnet = true
		if subnet_node is GNCustomOperator:
			is_single_custom_asset = true
	_context_menu.add_item("Promote to Custom Asset…", _CtxID.PROMOTE_TO_ASSET)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.PROMOTE_TO_ASSET), not is_single_subnet)

	# Custom asset actions — enabled only when exactly one GNCustomOperator is selected
	# "Edit Asset" is disabled for extension read-only assets
	var is_editable_asset := is_single_custom_asset
	if is_single_custom_asset and selected_ids.size() == 1:
		var co_node := network.get_node_by_id(selected_ids[0])
		if co_node is GNCustomOperator:
			var reg := GNExtensionRegistry.instance()
			var entry := reg.get_entry(co_node.node_type)
			if entry != null and entry.asset_read_only:
				is_editable_asset = false
	_context_menu.add_item("Edit Asset…", _CtxID.EDIT_ASSET)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.EDIT_ASSET), not is_editable_asset)
	_context_menu.add_item("Make Editable", _CtxID.MAKE_EDITABLE)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.MAKE_EDITABLE), not is_single_custom_asset)
	_context_menu.add_item("Re-promote Parameters…", _CtxID.REPROMOTE_ASSET)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.REPROMOTE_ASSET), not is_editable_asset)

	# Export / Import sub-network patches
	_context_menu.add_item("Export Sub-Network…", _CtxID.EXPORT_SUBNET_PATCH)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.EXPORT_SUBNET_PATCH), not is_single_subnet)
	_context_menu.add_item("Import .gnpatch…", _CtxID.IMPORT_SUBNET_PATCH)

	# Add Spare Parameter — enabled when exactly one node is selected
	_context_menu.add_item("Add Spare Parameter…", _CtxID.ADD_SPARE_PARAM)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.ADD_SPARE_PARAM), not single_node_selected)

	_context_menu.add_separator()
	_context_menu.add_item("Node Help", _CtxID.NODE_HELP)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.NODE_HELP), selected_ids.size() != 1)

	# Export Output — enabled when exactly one node selected with exportable output
	var can_export := false
	if selected_ids.size() == 1 and network != null:
		var export_node: GNNode = network.get_node_by_id(selected_ids[0])
		if export_node != null:
			can_export = export_node.can_export_output()
	_context_menu.add_item("Export Output…", _CtxID.EXPORT_OUTPUT)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.EXPORT_OUTPUT), not can_export)

	# Insert CHOP Reference — enabled when exactly one CHOP node is selected
	var is_single_chop := false
	if selected_ids.size() == 1 and network != null:
		var chop_node: GNNode = network.get_node_by_id(selected_ids[0])
		if chop_node != null and chop_node.family == GNFamily.Type.CHOP:
			is_single_chop = true
	_context_menu.add_item("Insert CHOP Reference…", _CtxID.INSERT_CHOP_REF)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.INSERT_CHOP_REF), not is_single_chop)

	# ── Parameter Preset actions ──────────────────────────────────────
	_context_menu.add_separator()

	var single_selected := selected_ids.size() == 1
	var sel_node_name := ""
	var sel_node_family_str := ""
	if single_selected and network != null:
		var sn: GNNode = network.get_node_by_id(selected_ids[0])
		if sn != null:
			sel_node_name = sn.id
			sel_node_family_str = GNFamily.get_family_name(sn.family).to_lower()

	# Copy / Paste Params — single node selected, same-type clipboard
	_context_menu.add_item("Copy Parameters", _CtxID.COPY_PARAMS)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.COPY_PARAMS), not single_selected)

	var can_paste_params := false
	if single_selected and network != null:
		var paste_node: GNNode = network.get_node_by_id(selected_ids[0])
		can_paste_params = GNParamPresetManager.can_paste(paste_node)
	_context_menu.add_item("Paste Parameters", _CtxID.PASTE_PARAMS)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.PASTE_PARAMS), not can_paste_params)

	_context_menu.add_item("Reset to Defaults", _CtxID.RESET_PARAMS)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.RESET_PARAMS), not single_selected)

	_context_menu.add_item("Save Param Preset…", _CtxID.SAVE_PARAM_PRESET)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.SAVE_PARAM_PRESET), not single_selected)

	# Load Param Preset submenu — populated dynamically
	if single_selected and network != null:
		var preset_node: GNNode = network.get_node_by_id(selected_ids[0])
		if preset_node != null:
			var op_type: String = preset_node.get_script().get_global_name()
			_param_preset_list = GNParamPresetManager.get_preset_list(op_type)
	else:
		_param_preset_list = []

	_param_preset_submenu = PopupMenu.new()
	_param_preset_submenu.name = "ParamPresetSubmenu"
	if _param_preset_list.is_empty():
		_param_preset_submenu.add_item("(no presets)", -1)
		_param_preset_submenu.set_item_disabled(0, true)
	else:
		for i in range(_param_preset_list.size()):
			var entry: Dictionary = _param_preset_list[i]
			var label: String = entry["name"]
			if entry["is_factory"]:
				label += "  [factory]"
			_param_preset_submenu.add_item(label, _CtxID.LOAD_PARAM_PRESET_BASE + i)
		_param_preset_submenu.id_pressed.connect(_on_context_menu_id_pressed)
	_context_menu.add_child(_param_preset_submenu)
	_context_menu.add_submenu_item("Load Param Preset", "ParamPresetSubmenu")
	_context_menu.set_item_disabled(
		_context_menu.item_count - 1, not single_selected or _param_preset_list.is_empty())

	# ── Copy Reference ────────────────────────────────────────────────
	_context_menu.add_separator()

	_context_menu.add_item('Copy Node Path  op("%s")' % sel_node_name if single_selected else "Copy Node Path", _CtxID.COPY_NODE_PATH)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.COPY_NODE_PATH), not single_selected)

	var output_ref_label := "Copy Output Ref"
	if single_selected and not sel_node_family_str.is_empty():
		match sel_node_family_str:
			"chop":
				output_ref_label = 'Copy Output  chop("%s", "out")' % sel_node_name
			"top":
				output_ref_label = 'Copy Output  top("%s")' % sel_node_name
			"ui":
				output_ref_label = 'Copy Output  chop("%s", "value")' % sel_node_name
			_:
				output_ref_label = 'Copy Output  op("%s")' % sel_node_name
	_context_menu.add_item(output_ref_label, _CtxID.COPY_OUTPUT_REF)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.COPY_OUTPUT_REF), not single_selected)

	_context_menu.add_separator()

	_context_menu.add_item("Copy as JSON", _CtxID.COPY_AS_JSON)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.COPY_AS_JSON), not has_selection)

	_context_menu.add_item("Paste from JSON", _CtxID.PASTE_FROM_JSON)
	var _clip_text := DisplayServer.clipboard_get().strip_edges()
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.PASTE_FROM_JSON),
		_clip_text.is_empty() or not _clip_text.begins_with("{"))

	_context_menu.add_item("Copy Debug Info", _CtxID.COPY_DEBUG_INFO)
	_context_menu.set_item_disabled(_context_menu.get_item_index(_CtxID.COPY_DEBUG_INFO), not single_selected)

	_context_menu.add_item("Copy Network JSON", _CtxID.COPY_NETWORK_JSON)

	_context_menu.add_separator()
	_context_menu.add_item("Search Nodes…", _CtxID.SEARCH_NODES)
	_context_menu.set_item_shortcut(_context_menu.get_item_index(_CtxID.SEARCH_NODES), _shortcut(KEY_F, true), true)

	_context_menu.position = Vector2i(screen_pos)
	_context_menu.reset_size()
	_context_menu.popup()


## Emits a signal with the selected node ID, if exactly one node is selected.
func _ctx_emit_selection(sig: Signal) -> void:
	var sel := _get_selected_node_ids()
	if sel.size() == 1:
		sig.emit(sel[0])


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
			paste_clipboard(_context_graph_pos)
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
			elif not _selected_wires.is_empty():
				_delete_selected_wires()
		_CtxID.DELETE_WIRES:
			_delete_selected_wires()
		_CtxID.INSERT_NODE_ON_WIRE:
			if _selected_wires.size() == 1:
				_begin_wire_insert(_selected_wires[0])
		_CtxID.SELECT_ALL:
			for view_name in _node_views:
				_node_views[view_name].selected = true
		_CtxID.UNDO:
			undo_action()
		_CtxID.REDO:
			redo_action()
		_CtxID.OPEN_VIEWER:
			_ctx_emit_selection(open_viewer_requested)
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
			_ctx_emit_selection(help_requested)
		_CtxID.EXPORT_OUTPUT:
			_begin_export_output()
		_CtxID.GROUP_SELECTED:
			group_selected_into_subnet()
		_CtxID.COPY_NODE_PATH:
			_copy_node_path_to_clipboard()
		_CtxID.COPY_OUTPUT_REF:
			_copy_output_ref_to_clipboard()
		_CtxID.COPY_PARAMS:
			_copy_selected_params()
		_CtxID.PASTE_PARAMS:
			_paste_selected_params()
		_CtxID.RESET_PARAMS:
			_reset_selected_params()
		_CtxID.SAVE_PARAM_PRESET:
			_show_save_preset_dialog()
		_CtxID.ADD_CHOP_EXPORT, _CtxID.INSERT_CHOP_REF:
			_show_insert_chop_ref_dialog()
		_CtxID.ADD_NETWORK_BOX:
			_annotations.add_annotation_at_mouse("box", _get_selected_node_ids(), get_local_mouse_position())
		_CtxID.ADD_STICKY_NOTE:
			_annotations.add_annotation_at_mouse("note", _get_selected_node_ids(), get_local_mouse_position())
		_CtxID.PROMOTE_TO_ASSET:
			_show_promote_to_asset_dialog()
		_CtxID.EDIT_ASSET:
			_ctx_emit_selection(edit_asset_requested)
		_CtxID.MAKE_EDITABLE:
			_ctx_emit_selection(make_editable_requested)
		_CtxID.REPROMOTE_ASSET:
			_ctx_emit_selection(repromote_asset_requested)
		_CtxID.ADD_SPARE_PARAM:
			_show_add_spare_param_dialog()
		_CtxID.EXPORT_SUBNET_PATCH:
			_ctx_emit_selection(export_subnet_requested)
		_CtxID.IMPORT_SUBNET_PATCH:
			import_patch_requested.emit(_context_graph_pos)
		_CtxID.COPY_AS_JSON:
			_copy_selected_as_json()
		_CtxID.PASTE_FROM_JSON:
			_paste_from_json()
		_CtxID.COPY_DEBUG_INFO:
			_copy_debug_info_to_clipboard()
		_CtxID.COPY_NETWORK_JSON:
			_copy_network_json_to_clipboard()
		_CtxID.SEARCH_NODES:
			_search.open_search()
		_:
			# Dynamic preset load IDs
			if id >= _CtxID.LOAD_PARAM_PRESET_BASE:
				var preset_idx: int = id - _CtxID.LOAD_PARAM_PRESET_BASE
				_load_param_preset(preset_idx)


## Copies selected nodes + connections as JSON to the OS clipboard.
func _copy_selected_as_json() -> void:
	if network == null:
		return
	var selected_ids: Array[String] = _get_selected_node_ids()
	if selected_ids.is_empty():
		return

	var nodes_data: Dictionary = {}
	for node_id in selected_ids:
		var node: GNNode = network.nodes.get(node_id, null)
		if node:
			nodes_data[node_id] = node.to_dict()

	var conns_data: Array = []
	for conn in network.connections:
		if selected_ids.has(conn.from_node) and selected_ids.has(conn.to_node):
			conns_data.append({
				"from": conn.from_node,
				"from_port": conn.from_port,
				"to": conn.to_node,
				"to_port": conn.to_port,
			})

	var payload := {"nodes": nodes_data, "connections": conns_data}
	var json_text := JSON.stringify(payload, "  ")
	DisplayServer.clipboard_set(json_text)
	GNLogger.info("GraphEditor", "Copied %d node(s) as JSON (%d bytes)" % [
		nodes_data.size(), json_text.length()])


## Pastes nodes from JSON text on the OS clipboard.
func _paste_from_json() -> void:
	var clip_text := DisplayServer.clipboard_get().strip_edges()
	if clip_text.is_empty():
		GNLogger.warn("GraphEditor", "Clipboard is empty")
		return

	var json := JSON.new()
	var err := json.parse(clip_text)
	if err != OK:
		GNLogger.warn("GraphEditor", "Paste JSON: parse error — %s" % json.get_error_message())
		return

	var payload: Dictionary = json.data
	if not payload.has("nodes"):
		GNLogger.warn("GraphEditor", "Paste JSON: missing 'nodes' key")
		return

	# Normalize connection keys: "from"/"to" → "from_node"/"to_node"
	var conns: Array = payload.get("connections", [])
	var normalized_conns: Array = []
	for cd in conns:
		normalized_conns.append({
			"from_node": cd.get("from_node", cd.get("from", "")),
			"from_port": int(cd.get("from_port", 0)),
			"to_node": cd.get("to_node", cd.get("to", "")),
			"to_port": int(cd.get("to_port", 0)),
		})

	_clipboard = {"nodes": payload["nodes"], "connections": normalized_conns}
	paste_clipboard(_context_graph_pos)
	GNLogger.info("GraphEditor", "Pasted %d node(s) from JSON" % payload["nodes"].size())


## Copies a single node's debug state to the OS clipboard.
func _copy_debug_info_to_clipboard() -> void:
	var selected := _get_selected_node_ids()
	if selected.size() != 1 or network == null:
		return
	var node: GNNode = network.get_node_by_id(selected[0])
	if node == null:
		return

	var lines: PackedStringArray = PackedStringArray()
	lines.append("=== %s ===" % node.id)
	lines.append("Type: %s" % node.node_type)
	lines.append("Family: %s" % GNFamily.get_family_name(node.family))
	lines.append("Class: %s" % node.get_script().get_global_name())
	lines.append("Dirty: %s" % str(node.dirty))
	lines.append("Active: %s" % str(node.is_active))
	lines.append("Cook valid: %s" % str(node.cook_valid))
	lines.append("Cook time: %.3f ms" % node.cook_time_ms)
	lines.append("Time dependent: %s" % str(node.time_dependent))
	lines.append("Bypass: %s" % str(node.bypass))
	lines.append("Locked: %s" % str(node.locked))
	lines.append("")

	# Parameters
	lines.append("--- Parameters ---")
	for param_name in node.get_parameter_names():
		var param: GNParameter = node.get_parameter(param_name)
		if param:
			var mode_str := ""
			if param.mode == GNParameter.Mode.EXPRESSION:
				mode_str = " [expr: %s]" % param.expression
			lines.append("  %s = %s%s" % [param_name, str(param.value), mode_str])
	lines.append("")

	# Output
	lines.append("--- Output ---")
	if node.cached_output != null:
		lines.append("  Type: %s" % node.cached_output.get_class())
		lines.append("  Valid: %s" % str(node.cached_output.valid))
		lines.append("  Timestamp: %d" % node.cached_output.timestamp)
		lines.append("  Summary: %s" % node.cached_output.get_data_summary())
	else:
		lines.append("  (null)")
	lines.append("")

	# Connections
	lines.append("--- Connections ---")
	var in_conns := network.get_input_connections(node.id)
	for conn in in_conns:
		lines.append("  IN:  %s:%d -> :%d" % [conn.from_node, conn.from_port, conn.to_port])
	var out_conns := network.get_output_connections(node.id)
	for conn in out_conns:
		lines.append("  OUT: :%d -> %s:%d" % [conn.from_port, conn.to_node, conn.to_port])

	if node.node_warning != "":
		lines.append("")
		lines.append("WARNING: %s" % node.node_warning)
	if node.node_error != "":
		lines.append("")
		lines.append("ERROR: %s" % node.node_error)

	var text := "\n".join(lines)
	DisplayServer.clipboard_set(text)
	GNLogger.info("GraphEditor", "Copied debug info for '%s' (%d bytes)" % [
		node.id, text.length()])


## Copies the entire network as JSON to the OS clipboard.
func _copy_network_json_to_clipboard() -> void:
	if network == null:
		return
	var json_text := JSON.stringify(network.to_dict(), "  ")
	DisplayServer.clipboard_set(json_text)
	GNLogger.info("GraphEditor", "Copied network JSON (%d bytes)" % json_text.length())


## Copies an expression-ready op("node_id") path for the selected node.
func _copy_node_path_to_clipboard() -> void:
	var selected := _get_selected_node_ids()
	if selected.size() != 1 or network == null:
		return
	var node: GNNode = network.get_node_by_id(selected[0])
	if node == null:
		return
	var ref := 'op("%s")' % node.id
	DisplayServer.clipboard_set(ref)
	GNLogger.info("GraphEditor", "Copied node path: %s" % ref)


## Copies a family-appropriate output reference for the selected node.
## CHOP → chop("name", "out"), TOP → top("name"), other → op("name").
func _copy_output_ref_to_clipboard() -> void:
	var selected := _get_selected_node_ids()
	if selected.size() != 1 or network == null:
		return
	var node: GNNode = network.get_node_by_id(selected[0])
	if node == null:
		return
	var family_str := GNFamily.get_family_name(node.family).to_lower()
	# Check if the expression function registry has a dedicated function for this family
	var expr_registry: Dictionary = GNFamily.get_expression_func_registry()
	var expr_func: String = ""
	for fn_name: String in expr_registry:
		if expr_registry[fn_name] == node.family:
			expr_func = fn_name
			break

	var ref: String
	if not expr_func.is_empty():
		# Family has a registered expression function — use it
		var completions: Array[Dictionary] = []
		if node.cached_output != null:
			completions = node.cached_output.get_completions()
		if not completions.is_empty():
			# Has named sub-values (e.g. CHOP channels) — include first one
			ref = '%s("%s", "%s")' % [expr_func, node.id, completions[0]["label"]]
		else:
			ref = '%s("%s")' % [expr_func, node.id]
	elif family_str == "ui":
		# UI nodes output widget_state as a CHOP — use first channel
		var chan := "%s:value" % node.id
		var state_port := node.output_ports.size() - 1
		var state_data: GNData = node.get_output_data(state_port) if state_port >= 0 else null
		if state_data != null:
			var completions := state_data.get_completions()
			if not completions.is_empty():
				chan = completions[0]["label"]
		ref = 'chop("%s", "%s")' % [node.id, chan]
	else:
		ref = 'op("%s")' % node.id
	DisplayServer.clipboard_set(ref)
	GNLogger.info("GraphEditor", "Copied output ref: %s" % ref)


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

## The output port index selected for export (-1 = default / auto).
var _export_port_index: int = -1

## Begins the export workflow: identifies the selected node, then either opens
## the FileDialog directly (single exportable output) or shows a port picker
## popup first (multiple exportable outputs).
func _begin_export_output() -> void:
	var selected := _get_selected_node_ids()
	if selected.size() != 1 or network == null:
		return
	var node: GNNode = network.get_node_by_id(selected[0])
	if node == null or not node.can_export_output():
		return
	_export_target_node = node

	var outputs := node.get_exportable_outputs()
	if outputs.size() <= 1:
		# Single export — go straight to FileDialog
		_export_port_index = outputs[0]["port"] if not outputs.is_empty() else -1
		_open_export_dialog(outputs[0]["filters"] if not outputs.is_empty() else [])
	else:
		# Multiple exports — show port picker popup first
		_show_export_port_picker(outputs)


## Shows a popup menu listing the exportable output ports so the user can
## choose which one to export.
func _show_export_port_picker(outputs: Array[Dictionary]) -> void:
	var popup := PopupMenu.new()
	popup.name = "ExportPortPicker"
	for i in range(outputs.size()):
		var entry: Dictionary = outputs[i]
		var port_idx: int = entry["port"]
		var label: String = entry["label"]
		var filters: Array = entry["filters"]
		var desc := ""
		if not filters.is_empty():
			desc = filters[0].get("description", "")
		popup.add_item("%s  (%s)" % [label, desc] if not desc.is_empty() else label, i)
		popup.set_item_metadata(popup.get_item_index(i), entry)
	popup.id_pressed.connect(func(id: int) -> void:
		var idx := popup.get_item_index(id)
		var meta: Dictionary = popup.get_item_metadata(idx)
		_export_port_index = meta["port"]
		_open_export_dialog(meta["filters"])
		popup.queue_free()
	)
	popup.canceled.connect(func() -> void:
		_export_target_node = null
		popup.queue_free()
	)
	add_child(popup)
	popup.popup_centered()


## Lazy-inits and configures the FileDialog, then shows it.
func _open_export_dialog(filters: Array) -> void:
	if _export_dialog == null:
		_export_dialog = FileDialog.new()
		_export_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		_export_dialog.title = "Export Output"
		_export_dialog.size = Vector2i(800, 500)
		_export_dialog.file_selected.connect(_on_export_file_selected)
		add_child(_export_dialog)

	_export_dialog.clear_filters()
	if filters.is_empty():
		_export_dialog.add_filter("*.tres", "Godot Resource")
	else:
		for f in filters:
			_export_dialog.add_filter(f["filter"], f["description"])

	_export_dialog.current_file = _export_target_node.id if _export_target_node else "export"
	_export_dialog.popup_centered()


## Called when the user confirms a file path in the export dialog.
func _on_export_file_selected(path: String) -> void:
	if _export_target_node == null:
		return

	var err: Error = _export_target_node.export_output(path, _export_port_index)

	if err == OK:
		GNLogger.info("Export", "Exported '%s' (port %d) → %s" % [_export_target_node.id, _export_port_index, path])
	else:
		GNLogger.error("Export", "Failed to export '%s' (port %d) → %s (error %d)" % [_export_target_node.id, _export_port_index, path, err])
	_export_target_node = null
	_export_port_index = -1


# ═══════════════════════════════════════════════════════════════════════════════
# Undo / Redo
# ═══════════════════════════════════════════════════════════════════════════════

## Undoes the last graph action.
func undo_action() -> void:
	if _undo_redo.has_undo():
		var action_name: String = _undo_redo.get_current_action_name()
		_undo_redo.undo()
		GNLogger.info("GraphEditor", "Undo: %s  (version %d)" % [action_name, _undo_redo.get_version()])
		if network != null:
			network.notify_state_changed()


## Redoes the last undone graph action.
func redo_action() -> void:
	if _undo_redo.has_redo():
		_undo_redo.redo()
		var action_name: String = _undo_redo.get_current_action_name()
		GNLogger.info("GraphEditor", "Redo: %s  (version %d)" % [action_name, _undo_redo.get_version()])
		if network != null:
			network.notify_state_changed()


## Clears all undo/redo history (call on New/Load).
func clear_undo_history() -> void:
	_undo_redo.clear_history()


# ── Move tracking ────────────────────────────────────────────────────────────

## For each annotation affected by a node drag:
## { ann_id: { "start_pos": Vector2, "siblings": { node_id: Vector2 } } }
var _node_drag_ann_info: Dictionary = {}

## Last known position of first dragged node (for computing per-frame delta).
var _node_drag_last_pos: Vector2 = Vector2.ZERO

## Whether a node drag is currently in progress.
var _node_drag_active: bool = false

## Snapshot selected node positions when a drag begins.
## Also determine which annotations (boxes AND sticky notes) contain dragged
## nodes so we can move them live during the drag.
func _on_begin_node_move() -> void:
	_pre_move_positions.clear()
	_node_drag_ann_info.clear()
	_node_drag_active = false
	_drag_over_wire = {}
	_drag_wire_in_port = -1
	_drag_wire_out_port = -1
	_shake_axis = -1
	_shake_sign = 0.0
	_shake_leg = 0.0
	_shake_reversals = 0
	_shake_timer = 0.0
	_shake_triggered = false

	var selected_ids: Array[String] = []
	for view_name in _node_views:
		var view: GNNodeView = _node_views[view_name]
		if view.selected:
			_pre_move_positions[view_name] = view.position_offset
			selected_ids.append(view_name)

	if selected_ids.is_empty():
		return

	# Record last-known position of the first selected node for delta tracking
	_node_drag_last_pos = _node_views[selected_ids[0]].position_offset
	_node_drag_active = true

	# For each annotation (box or note), check if any selected node is inside it.
	# Annotation rect is in pixel space (regular Control); convert node centers
	# from graph space to pixel space for a correct containment test.
	for ann_id in _annotations.get_annotation_views():
		var ann_view: Control = _annotations.get_annotation_views()[ann_id]
		var is_box := ann_view is GNNetworkBox
		var is_note := ann_view is GNStickyNote
		if not is_box and not is_note:
			continue
		var ann_rect := Rect2(ann_view.position, ann_view.size)
		var has_selected_inside := false
		for sid in selected_ids:
			var nv: GNNodeView = _node_views[sid]
			var pixel_center := nv.position_offset * zoom - scroll_offset + nv.size * zoom / 2.0
			if ann_rect.has_point(pixel_center):
				has_selected_inside = true
				break
		if has_selected_inside:
			# Snapshot annotation position and non-selected siblings (boxes only)
			var siblings: Dictionary = {}
			if is_box:
				for view_name in _node_views:
					if view_name in _pre_move_positions:
						continue  # already being moved by GraphEdit
					var nv2: GNNodeView = _node_views[view_name]
					var pixel_center2 := nv2.position_offset * zoom - scroll_offset + nv2.size * zoom / 2.0
					if ann_rect.has_point(pixel_center2):
						siblings[view_name] = nv2.position_offset
			_node_drag_ann_info[ann_id] = {
				"start_pos": ann_view.position,
				"siblings": siblings,
			}


## Called every frame — syncs annotation transforms on scroll/zoom changes,
## applies group-move deltas during active node drags, and handles edge-scroll
## when a wire is being dragged near the viewport border.
func _process(delta: float) -> void:
	# Redraw overlay when scroll/zoom changes (keeps wire highlights and
	# expression ref lines aligned with the graph content).
	if zoom != _last_zoom or scroll_offset != _last_scroll:
		_expr_ref_overlay.queue_redraw()
		_last_zoom = zoom
		_last_scroll = scroll_offset

	# ── Edge auto-scroll while dragging a wire or node near the border ──
	if _wire_dragging or _node_drag_active:
		_handle_edge_scroll(delta)

	# ── Expression ref hover tooltip timer ──
	if expr_refs_visible and not _expr_ref_hover_edge.is_empty():
		_tick_expr_ref_hover(delta)

	# Fast path: nothing to do if no annotations exist and no node drag is active.
	if not _annotations.has_annotations() and not _node_drag_active:
		return

	# --- Lightweight scroll/zoom sync for annotations ---
	# Skip during active drags (positions are managed by drag handlers).
	if _annotations.has_annotations() and not _node_drag_active and not _annotations.is_box_dragging():
		_annotations.sync_if_needed(zoom, scroll_offset)

	# --- Group-move tracking during node drags ---
	if not _node_drag_active or _pre_move_positions.is_empty():
		return
	if _annotations.is_group_moving():
		return

	# Compute delta from the first selected node's current position
	var first_id: String = _pre_move_positions.keys()[0]
	if not _node_views.has(first_id):
		return
	var current_pos: Vector2 = _node_views[first_id].position_offset
	var frame_delta := current_pos - _node_drag_last_pos
	if frame_delta.is_zero_approx():
		return

	# ── Shake-to-disconnect detection ──
	# A handful of compares on the one node being dragged. No allocation.
	if not _shake_triggered and _pre_move_positions.size() == 1:
		var speed := frame_delta.length() / maxf(delta, 0.001)
		var along_x := absf(frame_delta.x)
		var along_y := absf(frame_delta.y)
		var frame_axis := 0 if along_x >= along_y else 1
		var along := along_x if frame_axis == 0 else along_y
		var across := along_y if frame_axis == 0 else along_x
		var clear_axis := along > 0.0 and along >= across * _SHAKE_AXIS_RATIO
		if _shake_axis < 0:
			if speed > _SHAKE_MIN_SPEED and clear_axis:
				_shake_axis = frame_axis
				_shake_sign = signf(frame_delta.x if frame_axis == 0 else frame_delta.y)
				_shake_leg = along
		elif frame_axis == _shake_axis and clear_axis:
			var cur_sign := signf(frame_delta.x if _shake_axis == 0 else frame_delta.y)
			if cur_sign == _shake_sign:
				_shake_leg += along
			else:
				if _shake_leg >= _SHAKE_MIN_LEG and speed > _SHAKE_MIN_SPEED:
					if _shake_reversals == 0:
						_shake_timer = 0.0
					_shake_reversals += 1
				_shake_sign = cur_sign
				_shake_leg = along
			if _shake_reversals > 0:
				_shake_timer += delta
				if _shake_timer > _SHAKE_TIME_WINDOW:
					_shake_reversals = 0
					_shake_timer = 0.0
			if _shake_reversals >= _SHAKE_REVERSAL_THRESHOLD:
				_shake_triggered = true
				_perform_shake_disconnect(first_id)

	_node_drag_last_pos = current_pos

	# frame_delta is in graph space (from position_offset); convert to pixel
	# space for annotation Controls.
	var pixel_delta := frame_delta * zoom
	_annotations.apply_drag_delta(pixel_delta, frame_delta, _node_drag_ann_info)

	# ── Drop-on-wire detection during drag ──
	_update_drag_over_wire()


## Compare positions after drag ends and record for undo if changed.
func _on_end_node_move() -> void:
	_node_drag_active = false

	# ── Drop-on-wire: splice the dragged node into the hovered wire ──
	var splice_wire := _drag_over_wire
	var splice_in := _drag_wire_in_port
	var splice_out := _drag_wire_out_port
	_drag_over_wire = {}
	_drag_wire_in_port = -1
	_drag_wire_out_port = -1
	_expr_ref_overlay.queue_redraw()

	if not splice_wire.is_empty() and splice_in >= 0 and splice_out >= 0 \
			and _pre_move_positions.size() == 1:
		_perform_drag_wire_splice(splice_wire, splice_in, splice_out)
		return  # Undo action is recorded inside _perform_drag_wire_splice
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

	# Persist annotation positions and add sibling nodes to undo tracking
	if changed and not _node_drag_ann_info.is_empty():
		for ann_id in _node_drag_ann_info:
			var info: Dictionary = _node_drag_ann_info[ann_id]
			if _annotations.get_annotation_views().has(ann_id) and network:
				var pixel_pos: Vector2 = _annotations.get_annotation_views()[ann_id].position
				var graph_pos := (pixel_pos + scroll_offset) / zoom
				network.update_annotation(ann_id, {"position": graph_pos})
			var siblings: Dictionary = info.get("siblings", {})
			for sib_id in siblings:
				if _node_views.has(sib_id):
					var new_sib_pos: Vector2 = _node_views[sib_id].position_offset
					if network and network.nodes.has(sib_id):
						network.nodes[sib_id].graph_position = new_sib_pos
					old_positions[sib_id] = siblings[sib_id]
					new_positions[sib_id] = new_sib_pos

	if changed:
		_undo_redo.create_action("Move %d node(s)" % old_positions.size())
		_undo_redo.add_do_method(_ur_set_positions.bind(new_positions))
		_undo_redo.add_undo_method(_ur_set_positions.bind(old_positions))
		_undo_redo.commit_action(false)

	_pre_move_positions.clear()
	_node_drag_ann_info.clear()


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


## Like _ur_set_positions but animates the move with a tween.
## Used by undo of wire-insert so nodes slide back smoothly.
func _ur_animate_positions(positions: Dictionary) -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_CUBIC)
	for node_id in positions:
		var pos: Vector2 = positions[node_id]
		var node: GNNode = network.get_node_by_id(node_id) if network else null
		if node:
			node.graph_position = pos
		if _node_views.has(node_id):
			tw.tween_property(_node_views[node_id], "position_offset",
					pos, _INSERT_ANIM_DURATION)


## Renames a node.
func _ur_rename(old_id: String, new_id: String) -> void:
	if network:
		network.rename_node(old_id, new_id)


## Replaces ALL connections in the current network with the given snapshot.
## Each entry is [from_node, from_port, to_node, to_port].
func _ur_set_connections(conn_data: Array) -> void:
	if network == null:
		return
	network.connections.clear()
	for cd in conn_data:
		network.connections.append(
			GNConnection.create(cd[0], cd[1], cd[2], cd[3]))
	network._invalidate_topo()
	network.notify_state_changed()


## Redo helper for group-into-subnet: removes original nodes, adds subnet,
## and restores the post-group connection state.
func _ur_do_group_subnet(removed_ids: Array, subnet_id: String,
		subnet_dict: Dictionary, post_conns: Array) -> void:
	if network == null:
		return
	# Remove the original selected nodes
	for nid in removed_ids:
		_ur_remove_node(nid)
	# Add the SubNetworkNode (including its inner network via from_dict)
	_ur_add_node(subnet_id, subnet_dict)
	# Restore connections to the post-group state
	_ur_set_connections(post_conns)


## Undo helper for group-into-subnet: removes subnet, restores original
## nodes, and restores the pre-group connection state.
func _ur_undo_group_subnet(subnet_id: String, nodes_snapshot: Array,
		pre_conns: Array) -> void:
	if network == null:
		return
	# Remove the SubNetworkNode
	_ur_remove_node(subnet_id)
	# Restore the original nodes
	for nd in nodes_snapshot:
		_ur_add_node(nd[0], nd[1])
	# Restore connections to the pre-group state
	_ur_set_connections(pre_conns)


# ═══════════════════════════════════════════════════════════════════════════════
# Group Selected → Sub-Network
# ═══════════════════════════════════════════════════════════════════════════════

## Moves the selected nodes into a new SubNetworkNode.
## Auto-creates InTunnel/OutTunnel nodes for wires crossing the group boundary.
##
## Algorithm:
## 1. Identify the selected node set.
## 2. Classify all connections as internal, incoming (external→selected),
##    or outgoing (selected→external).
## 3. Create a SubNetworkNode at the centroid of the selection.
## 4. For each unique incoming wire endpoint: create an InTunnel in the inner
##    network and add a matching input port to the SubNetworkNode.
## 5. For each unique outgoing wire source: create an OutTunnel in the inner
##    network and add a matching output port to the SubNetworkNode.
## 6. Move selected nodes into the inner network, remapping connections.
## 7. Remove old nodes and wires from the parent network.
## 8. Reconnect external wires to the SubNetworkNode's ports.
func group_selected_into_subnet() -> void:
	if network == null or read_only:
		return
	var selected := _get_selected_node_ids()
	if selected.is_empty():
		return

	# ── Snapshot for undo ───────────────────────────────────────────────
	var pre_nodes_snapshot: Array = []
	for nid in selected:
		var node: GNNode = network.nodes.get(nid, null)
		if node:
			pre_nodes_snapshot.append([nid, node.to_dict()])
	var pre_conns_snapshot: Array = []
	for conn in network.connections:
		pre_conns_snapshot.append([conn.from_node, conn.from_port,
				conn.to_node, conn.to_port])

	var selected_set: Dictionary = {}
	for nid in selected:
		selected_set[nid] = true

	# ── Classify connections ────────────────────────────────────────────
	var internal_conns: Array[GNConnection] = []
	var incoming_conns: Array[GNConnection] = []   # external → selected
	var outgoing_conns: Array[GNConnection] = []   # selected → external

	for conn in network.connections:
		var from_in := selected_set.has(conn.from_node)
		var to_in := selected_set.has(conn.to_node)
		if from_in and to_in:
			internal_conns.append(conn)
		elif not from_in and to_in:
			incoming_conns.append(conn)
		elif from_in and not to_in:
			outgoing_conns.append(conn)
		# else: both external — not our concern

	# ── Compute centroid ────────────────────────────────────────────────
	var centroid := Vector2.ZERO
	for nid in selected:
		var node: GNNode = network.get_node_by_id(nid)
		if node:
			centroid += node.graph_position
	centroid /= float(selected.size())

	# ── Create SubNetworkNode ───────────────────────────────────────────
	var subnet = GNExtensionRegistry.instance().create_instance("SubNetworkNode")
	var subnet_id := network.generate_unique_id("subnet")
	subnet.initialize(subnet_id)
	subnet.graph_position = centroid
	subnet._ensure_inner_network()

	# ── Create InTunnels for incoming wires ─────────────────────────────
	# Deduplicate by (from_node, from_port) — multiple wires from the same
	# source become one InTunnel.
	var in_tunnel_map: Dictionary = {}  # "from_node:from_port" → InTunnel
	var in_tunnel_index: int = 0
	for conn in incoming_conns:
		var key := "%s:%d" % [conn.from_node, conn.from_port]
		if in_tunnel_map.has(key):
			continue
		var source_node: GNNode = network.get_node_by_id(conn.from_node)
		var source_port: GNPort = source_node.get_output_port(conn.from_port) if source_node else null
		var port_family: int = source_port.family if source_port else GNFamily.Type.TOP

		var tunnel := InTunnel.new()
		tunnel.tunnel_index = in_tunnel_index
		tunnel.tunnel_family = port_family
		tunnel.tunnel_label = "in%d" % in_tunnel_index
		var tunnel_id: String = subnet.inner_network.generate_unique_id("in_tunnel")
		tunnel.initialize(tunnel_id)
		tunnel.graph_position = Vector2(-300, in_tunnel_index * 150)
		# Rebuild output port to match family
		tunnel.output_ports.clear()
		tunnel.add_output("out", port_family, "Data from parent input %d" % in_tunnel_index)
		subnet.inner_network.add_node(tunnel)
		in_tunnel_map[key] = tunnel
		in_tunnel_index += 1

	# ── Create OutTunnels for outgoing wires ────────────────────────────
	# Deduplicate by (from_node, from_port) — one OutTunnel per unique source
	# inside the group.
	var out_tunnel_map: Dictionary = {}  # "from_node:from_port" → OutTunnel
	var out_tunnel_index: int = 0
	for conn in outgoing_conns:
		var key := "%s:%d" % [conn.from_node, conn.from_port]
		if out_tunnel_map.has(key):
			continue
		var source_node: GNNode = network.get_node_by_id(conn.from_node)
		var source_port: GNPort = source_node.get_output_port(conn.from_port) if source_node else null
		var port_family: int = source_port.family if source_port else GNFamily.Type.TOP

		var tunnel := OutTunnel.new()
		tunnel.tunnel_index = out_tunnel_index
		tunnel.tunnel_family = port_family
		tunnel.tunnel_label = "out%d" % out_tunnel_index
		var tunnel_id: String = subnet.inner_network.generate_unique_id("out_tunnel")
		tunnel.initialize(tunnel_id)
		tunnel.graph_position = Vector2(600, out_tunnel_index * 150)
		# Rebuild input port to match family
		tunnel.input_ports.clear()
		tunnel.add_input("in", port_family, false, "Data to send to parent output %d" % out_tunnel_index)
		subnet.inner_network.add_node(tunnel)
		out_tunnel_map[key] = tunnel
		out_tunnel_index += 1

	# ── Move selected nodes into inner network ──────────────────────────
	# We need to: remove from parent scene tree, add to inner network.
	for nid in selected:
		var node: GNNode = network.get_node_by_id(nid)
		if node == null:
			continue
		# Recenter positions relative to centroid
		node.graph_position = node.graph_position - centroid + Vector2(150, 0)
		# Detach from parent network's scene tree and data model
		# (direct dict manipulation to avoid signaling and queue_free)
		network.nodes.erase(nid)
		if node.is_inside_tree():
			node.get_parent().remove_child(node)
		# Add to inner network
		subnet.inner_network.nodes[nid] = node

	# ── Remap internal connections ──────────────────────────────────────
	for conn in internal_conns:
		# Remove from parent
		network.connections.erase(conn)
		# Add to inner network
		subnet.inner_network.connections.append(conn)

	# ── Remap incoming connections ──────────────────────────────────────
	for conn in incoming_conns:
		var key := "%s:%d" % [conn.from_node, conn.from_port]
		var tunnel = in_tunnel_map[key]
		# Remove old wire from parent
		network.connections.erase(conn)
		# Wire: InTunnel output → original target inside inner network
		var inner_conn := GNConnection.create(tunnel.id, 0, conn.to_node, conn.to_port)
		subnet.inner_network.connections.append(inner_conn)

	# ── Remap outgoing connections ──────────────────────────────────────
	# Store external targets to reconnect after subnet is added
	var external_rewires: Array[Dictionary] = []  # [{from_tunnel_idx, to_node, to_port}]
	for conn in outgoing_conns:
		var key := "%s:%d" % [conn.from_node, conn.from_port]
		var tunnel = out_tunnel_map[key]
		# Remove old wire from parent
		network.connections.erase(conn)
		# Wire: source inside inner network → OutTunnel input
		var inner_conn := GNConnection.create(conn.from_node, conn.from_port, tunnel.id, 0)
		subnet.inner_network.connections.append(inner_conn)
		# Remember external target for reconnection
		external_rewires.append({
			"from_tunnel_idx": tunnel.tunnel_index,
			"to_node": conn.to_node,
			"to_port": conn.to_port,
		})

	# ── Invalidate inner network topology ───────────────────────────────
	subnet.inner_network._invalidate_topo()

	# ── Sync external ports from tunnels ────────────────────────────────
	subnet.sync_ports_from_tunnels()

	# ── Add SubNetworkNode to parent network ────────────────────────────
	network.add_node(subnet)

	# ── Reconnect external incoming wires to SubNetworkNode inputs ──────
	for conn in incoming_conns:
		var key := "%s:%d" % [conn.from_node, conn.from_port]
		var tunnel = in_tunnel_map[key]
		network.connect_nodes(conn.from_node, conn.from_port, subnet_id, tunnel.tunnel_index)

	# ── Reconnect external outgoing wires from SubNetworkNode outputs ───
	for rw in external_rewires:
		network.connect_nodes(subnet_id, rw["from_tunnel_idx"], rw["to_node"], rw["to_port"])

	# ── Emit node_removed for each selected node (updates views) ────────
	for nid in selected:
		network.node_removed.emit(nid)

	# ── Invalidate parent topology ──────────────────────────────────────
	network._invalidate_topo()
	network.notify_state_changed()

	# ── Record undo action ──────────────────────────────────────────────
	var post_conns_snapshot: Array = []
	for conn in network.connections:
		post_conns_snapshot.append([conn.from_node, conn.from_port,
				conn.to_node, conn.to_port])

	_undo_redo.create_action("Group %d node(s) into Sub-Network" % selected.size())
	_undo_redo.add_do_method(
		_ur_do_group_subnet.bind(selected, subnet_id,
				subnet.to_dict(), post_conns_snapshot))
	_undo_redo.add_undo_method(
		_ur_undo_group_subnet.bind(subnet_id, pre_nodes_snapshot,
				pre_conns_snapshot))
	_undo_redo.commit_action(false)

	GNLogger.info("GraphEditor", "Grouped %d nodes into sub-network '%s' (%d in, %d out)" % [
		selected.size(), subnet_id, in_tunnel_map.size(), out_tunnel_map.size()])


# ═══════════════════════════════════════════════════════════════════════════════
# Parameter Presets — Copy / Paste / Save / Load / Reset
# ═══════════════════════════════════════════════════════════════════════════════

## Copies parameters of the single selected node to the param clipboard.
func _copy_selected_params() -> void:
	var selected := _get_selected_node_ids()
	if selected.size() != 1 or network == null:
		return
	var node: GNNode = network.get_node_by_id(selected[0])
	if node == null:
		return
	GNParamPresetManager.copy_params(node)


## Pastes param clipboard onto the single selected node (same operator type).
func _paste_selected_params() -> void:
	var selected := _get_selected_node_ids()
	if selected.size() != 1 or network == null:
		return
	var node: GNNode = network.get_node_by_id(selected[0])
	if node == null:
		return
	var applied := GNParamPresetManager.paste_params(node)
	if applied > 0:
		# Trigger inspector rebuild to reflect new values
		node.parameters_changed.emit(node.id)


## Resets all parameters on the single selected node to defaults.
func _reset_selected_params() -> void:
	var selected := _get_selected_node_ids()
	if selected.size() != 1 or network == null:
		return
	var node: GNNode = network.get_node_by_id(selected[0])
	if node == null:
		return
	var count := GNParamPresetManager.reset_to_defaults(node)
	if count > 0:
		node.parameters_changed.emit(node.id)


## Shows a dialog to name and save a param preset for the selected node.
func _show_save_preset_dialog() -> void:
	var selected := _get_selected_node_ids()
	if selected.size() != 1 or network == null:
		return
	_save_preset_target_node = network.get_node_by_id(selected[0])
	if _save_preset_target_node == null:
		return

	if _save_preset_dialog == null:
		_save_preset_dialog = AcceptDialog.new()
		_save_preset_dialog.title = "Save Parameter Preset"
		_save_preset_dialog.ok_button_text = "Save"
		_save_preset_dialog.size = Vector2i(360, 120)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)

		var lbl := Label.new()
		lbl.text = "Preset name:"
		vbox.add_child(lbl)

		_save_preset_line_edit = LineEdit.new()
		_save_preset_line_edit.placeholder_text = "My Preset"
		_save_preset_line_edit.select_all_on_focus = true
		vbox.add_child(_save_preset_line_edit)

		_save_preset_dialog.add_child(vbox)
		_save_preset_dialog.confirmed.connect(_on_save_preset_confirmed)
		add_child(_save_preset_dialog)

	var op_type: String = _save_preset_target_node.get_script().get_global_name()
	_save_preset_dialog.title = "Save Param Preset — %s" % op_type
	_save_preset_line_edit.text = ""
	_save_preset_line_edit.grab_focus.call_deferred()
	_save_preset_dialog.popup_centered()


## Called when the user confirms the save preset dialog.
func _on_save_preset_confirmed() -> void:
	var preset_name: String = _save_preset_line_edit.text.strip_edges()
	if preset_name.is_empty():
		GNLogger.warn("GraphEditor", "Cannot save preset with empty name")
		return
	if _save_preset_target_node == null:
		return
	var ok := GNParamPresetManager.save_preset(_save_preset_target_node, preset_name)
	if ok:
		GNLogger.info("GraphEditor", "Parameter preset '%s' saved" % preset_name)
	_save_preset_target_node = null


## Loads a parameter preset by index from the cached preset list.
func _load_param_preset(preset_idx: int) -> void:
	if preset_idx < 0 or preset_idx >= _param_preset_list.size():
		return
	var selected := _get_selected_node_ids()
	if selected.size() != 1 or network == null:
		return
	var node: GNNode = network.get_node_by_id(selected[0])
	if node == null:
		return
	var entry: Dictionary = _param_preset_list[preset_idx]
	var applied := GNParamPresetManager.load_preset(node, entry["path"])
	if applied > 0:
		node.parameters_changed.emit(node.id)


# ═══════════════════════════════════════════════════════════════════════════════
# Add Spare Parameter
# ═══════════════════════════════════════════════════════════════════════════════

## Shows a dialog to add a user-defined spare parameter to the selected node.
func _show_add_spare_param_dialog() -> void:
	var selected := _get_selected_node_ids()
	if selected.size() != 1 or network == null:
		return
	var target_node: GNNode = network.get_node_by_id(selected[0])
	if target_node == null:
		return

	if _spare_param_dialog != null:
		_spare_param_dialog.queue_free()

	_spare_param_dialog = AcceptDialog.new()
	_spare_param_dialog.title = "Add Spare Parameter — %s" % target_node.id
	_spare_param_dialog.ok_button_text = "Add"
	_spare_param_dialog.size = Vector2i(400, 240)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	var name_lbl := Label.new()
	name_lbl.text = "Parameter name:"
	vbox.add_child(name_lbl)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "my_param"
	name_edit.select_all_on_focus = true
	vbox.add_child(name_edit)

	var type_lbl := Label.new()
	type_lbl.text = "Type:"
	vbox.add_child(type_lbl)
	var type_option := OptionButton.new()
	type_option.add_item("Float", GNParameter.ValueType.FLOAT)
	type_option.add_item("Int", GNParameter.ValueType.INT)
	type_option.add_item("Bool", GNParameter.ValueType.BOOL)
	type_option.add_item("String", GNParameter.ValueType.STRING)
	type_option.add_item("Color", GNParameter.ValueType.COLOR)
	type_option.add_item("Vector2", GNParameter.ValueType.VECTOR2)
	type_option.add_item("Vector2i", GNParameter.ValueType.VECTOR2I)
	vbox.add_child(type_option)

	# --- Range row (visible for Float / Int) ---
	var range_box := HBoxContainer.new()
	range_box.name = "RangeRow"
	range_box.add_theme_constant_override("separation", 8)
	var min_lbl := Label.new()
	min_lbl.text = "Min:"
	min_lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	range_box.add_child(min_lbl)
	var min_edit := LineEdit.new()
	min_edit.placeholder_text = "(none)"
	min_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	min_edit.tooltip_text = "Leave empty for no minimum"
	range_box.add_child(min_edit)
	var max_lbl := Label.new()
	max_lbl.text = "Max:"
	max_lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	range_box.add_child(max_lbl)
	var max_edit := LineEdit.new()
	max_edit.placeholder_text = "(none)"
	max_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	max_edit.tooltip_text = "Leave empty for no maximum"
	range_box.add_child(max_edit)
	vbox.add_child(range_box)

	# Show range row only for numeric types
	var _update_range_vis := func() -> void:
		var sel_id: int = type_option.get_selected_id()
		range_box.visible = (sel_id == GNParameter.ValueType.FLOAT or sel_id == GNParameter.ValueType.INT)
	_update_range_vis.call()
	type_option.item_selected.connect(func(_idx: int) -> void: _update_range_vis.call())

	var label_lbl := Label.new()
	label_lbl.text = "Display label (optional):"
	vbox.add_child(label_lbl)
	var label_edit := LineEdit.new()
	label_edit.placeholder_text = "My Param"
	vbox.add_child(label_edit)

	_spare_param_dialog.add_child(vbox)

	var node_id: String = target_node.id
	_spare_param_dialog.confirmed.connect(func() -> void:
		var p_name: String = name_edit.text.strip_edges()
		if p_name.is_empty():
			GNLogger.warn("GraphEditor", "Spare parameter name cannot be empty")
			_spare_param_dialog.queue_free()
			return
		# Ensure no collision with existing params
		var node: GNNode = network.get_node_by_id(node_id) if network else null
		if node == null:
			_spare_param_dialog.queue_free()
			return
		if node.get_parameter(p_name) != null:
			GNLogger.warn("GraphEditor", "Parameter '%s' already exists on '%s'" % [p_name, node_id])
			_spare_param_dialog.queue_free()
			return

		var vt: int = type_option.get_selected_id()
		var p_label: String = label_edit.text.strip_edges()
		if p_label.is_empty():
			p_label = p_name.capitalize()

		# Parse optional range
		var mn_text: String = min_edit.text.strip_edges()
		var mx_text: String = max_edit.text.strip_edges()
		var mn_val: Variant = null
		var mx_val: Variant = null
		if vt == GNParameter.ValueType.FLOAT:
			if mn_text.is_valid_float():
				mn_val = mn_text.to_float()
			if mx_text.is_valid_float():
				mx_val = mx_text.to_float()
		elif vt == GNParameter.ValueType.INT:
			if mn_text.is_valid_int():
				mn_val = mn_text.to_int()
			if mx_text.is_valid_int():
				mx_val = mx_text.to_int()

		var param: GNParameter = null
		match vt:
			GNParameter.ValueType.FLOAT:
				param = GNParameter.create_float(p_name, 0.0, mn_val, mx_val, 0.01, p_label)
			GNParameter.ValueType.INT:
				param = GNParameter.create_int(p_name, 0, mn_val, mx_val, p_label)
			GNParameter.ValueType.BOOL:
				param = GNParameter.create_bool(p_name, false, p_label)
			GNParameter.ValueType.STRING:
				param = GNParameter.create_string(p_name, "", p_label)
			GNParameter.ValueType.COLOR:
				param = GNParameter.create_color(p_name, Color.WHITE, p_label)
			GNParameter.ValueType.VECTOR2:
				param = GNParameter.create_vector2(p_name, Vector2.ZERO, p_label)
			GNParameter.ValueType.VECTOR2I:
				param = GNParameter.create_vector2i(p_name, Vector2i.ZERO, p_label)
			_:
				param = GNParameter.create_float(p_name, 0.0, null, null, 0.01, p_label)

		node.add_spare_parameter(param)
		GNLogger.info("GraphEditor", "Added spare parameter '%s' to '%s'" % [p_name, node_id])
		_spare_param_dialog.queue_free()
	)
	_spare_param_dialog.canceled.connect(func() -> void:
		_spare_param_dialog.queue_free()
	)
	add_child(_spare_param_dialog)
	name_edit.grab_focus.call_deferred()
	_spare_param_dialog.popup_centered()


# ═══════════════════════════════════════════════════════════════════════════════
# Insert CHOP Reference
# ═══════════════════════════════════════════════════════════════════════════════

## Shows the promote-to-custom-asset dialog for the selected SubNetworkNode.
func _show_promote_to_asset_dialog() -> void:
	var selected := _get_selected_node_ids()
	if selected.size() != 1 or network == null:
		return
	var node: GNNode = network.get_node_by_id(selected[0])
	if not node is SubNetworkNode:
		return

	if _promote_asset_dialog != null:
		_promote_asset_dialog.queue_free()
	_promote_asset_dialog = GNAssetPromotionDialog.new()
	_promote_asset_dialog.asset_created.connect(func(path: String, op_name: String) -> void:
		GNLogger.info("GraphEditor", "Custom asset '%s' created at %s" % [op_name, path])
	)
	add_child(_promote_asset_dialog)
	_promote_asset_dialog.setup(node as SubNetworkNode)
	_promote_asset_dialog.popup_centered()


## Shows the promotion dialog for an explicit SubNetworkNode (used by re-promote).
func _show_promote_to_asset_dialog_for(subnet: SubNetworkNode) -> void:
	if _promote_asset_dialog != null:
		_promote_asset_dialog.queue_free()
	_promote_asset_dialog = GNAssetPromotionDialog.new()
	_promote_asset_dialog.asset_created.connect(func(path: String, op_name: String) -> void:
		GNLogger.info("GraphEditor", "Custom asset '%s' re-promoted at %s" % [op_name, path])
	)
	add_child(_promote_asset_dialog)
	_promote_asset_dialog.setup(subnet)
	_promote_asset_dialog.popup_centered()


## Shows a dialog to insert a chop() expression reference from the selected CHOP
## node into a target parameter on any node.  Replaces the old "Add CHOP Export"
## workflow — instead of a separate export mapping, this writes a chop() expression
## directly into the target parameter (same-frame, composable with math).
func _show_insert_chop_ref_dialog() -> void:
	var selected := _get_selected_node_ids()
	if selected.size() != 1 or network == null:
		return
	_chop_ref_source_node = network.get_node_by_id(selected[0])
	if _chop_ref_source_node == null or _chop_ref_source_node.family != GNFamily.Type.CHOP:
		return

	# Gather available channel names from the CHOP's cached output
	var channel_names: PackedStringArray = []
	if _chop_ref_source_node.cached_output != null:
		var completions := _chop_ref_source_node.cached_output.get_completions()
		for c in completions:
			channel_names.append(c["label"])

	var dialog := AcceptDialog.new()
	dialog.title = "Insert CHOP Reference — %s" % _chop_ref_source_node.id
	dialog.ok_button_text = "Insert Reference"
	dialog.size = Vector2i(420, 280)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	# Source channel
	var ch_lbl := Label.new()
	ch_lbl.text = "Source channel:"
	vbox.add_child(ch_lbl)
	var ch_edit := LineEdit.new()
	ch_edit.text = "out" if channel_names.is_empty() else channel_names[0]
	ch_edit.placeholder_text = "e.g., out"
	vbox.add_child(ch_edit)
	if not channel_names.is_empty():
		var hint := Label.new()
		hint.text = "Available: %s" % ", ".join(channel_names)
		hint.add_theme_font_size_override("font_size", 10)
		hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		vbox.add_child(hint)

	# Target node
	var tn_lbl := Label.new()
	tn_lbl.text = "Target node ID:"
	vbox.add_child(tn_lbl)
	var tn_edit := LineEdit.new()
	tn_edit.placeholder_text = "e.g., noise1"
	vbox.add_child(tn_edit)

	# Target param
	var tp_lbl := Label.new()
	tp_lbl.text = "Target parameter:"
	vbox.add_child(tp_lbl)
	var tp_edit := LineEdit.new()
	tp_edit.placeholder_text = "e.g., scale"
	vbox.add_child(tp_edit)

	# Scale / offset (optional, baked into the expression)
	var opts := HBoxContainer.new()
	opts.add_theme_constant_override("separation", 8)
	var sc_lbl := Label.new()
	sc_lbl.text = "Scale:"
	opts.add_child(sc_lbl)
	var sc_spin := SpinBox.new()
	sc_spin.value = 1.0
	sc_spin.min_value = -1000.0
	sc_spin.max_value = 1000.0
	sc_spin.step = 0.01
	opts.add_child(sc_spin)
	var off_lbl := Label.new()
	off_lbl.text = "Offset:"
	opts.add_child(off_lbl)
	var off_spin := SpinBox.new()
	off_spin.value = 0.0
	off_spin.min_value = -10000.0
	off_spin.max_value = 10000.0
	off_spin.step = 0.01
	opts.add_child(off_spin)
	vbox.add_child(opts)

	dialog.add_child(vbox)

	var source_id: String = _chop_ref_source_node.id
	dialog.confirmed.connect(func() -> void:
		var channel: String = ch_edit.text.strip_edges()
		var target_node_id: String = tn_edit.text.strip_edges()
		var target_param_name: String = tp_edit.text.strip_edges()
		if channel.is_empty() or target_node_id.is_empty() or target_param_name.is_empty():
			GNLogger.warn("GraphEditor", "Insert CHOP Ref: all fields required")
			dialog.queue_free()
			return

		var target: GNNode = network.nodes.get(target_node_id, null)
		if target == null:
			GNLogger.warn("GraphEditor", "Insert CHOP Ref: target node '%s' not found" % target_node_id)
			dialog.queue_free()
			return
		var p: GNParameter = target.parameters.get(target_param_name, null)
		if p == null:
			GNLogger.warn("GraphEditor", "Insert CHOP Ref: target param '%s.%s' not found" % [
				target_node_id, target_param_name])
			dialog.queue_free()
			return

		# Use set_chop_reference() which generates the expression and switches to EXPRESSION mode
		p.set_chop_reference(source_id, channel, sc_spin.value, off_spin.value)
		target.mark_dirty()

		GNLogger.info("GraphEditor", "Inserted CHOP reference: %s → %s.%s  expr='%s'" % [
			source_id, target_node_id, target_param_name, p.expression])
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered()


# ─────────────────────────────────────────────────────────────────────────────
# Edge auto-scroll while dragging wires or nodes near the viewport border
# ─────────────────────────────────────────────────────────────────────────────
func _handle_edge_scroll(delta: float) -> void:
	var mouse := get_local_mouse_position()
	var vp_size := size
	var scroll_delta := Vector2.ZERO

	# Left edge
	if mouse.x < _EDGE_SCROLL_MARGIN:
		var t := 1.0 - clampf(mouse.x / _EDGE_SCROLL_MARGIN, 0.0, 1.0)
		scroll_delta.x -= _EDGE_SCROLL_SPEED * t * delta
	# Right edge
	elif mouse.x > vp_size.x - _EDGE_SCROLL_MARGIN:
		var t := 1.0 - clampf((vp_size.x - mouse.x) / _EDGE_SCROLL_MARGIN, 0.0, 1.0)
		scroll_delta.x += _EDGE_SCROLL_SPEED * t * delta
	# Top edge
	if mouse.y < _EDGE_SCROLL_MARGIN:
		var t := 1.0 - clampf(mouse.y / _EDGE_SCROLL_MARGIN, 0.0, 1.0)
		scroll_delta.y -= _EDGE_SCROLL_SPEED * t * delta
	# Bottom edge
	elif mouse.y > vp_size.y - _EDGE_SCROLL_MARGIN:
		var t := 1.0 - clampf((vp_size.y - mouse.y) / _EDGE_SCROLL_MARGIN, 0.0, 1.0)
		scroll_delta.y += _EDGE_SCROLL_SPEED * t * delta

	if scroll_delta != Vector2.ZERO:
		scroll_offset += scroll_delta
		# When dragging nodes, feed the scroll delta into GraphEdit's
		# internal drag tracking by synthesizing a mouse motion event.
		# GraphEdit positions dragged nodes via drag_from + drag_accum/zoom;
		# adding scroll_delta to drag_accum (via event.relative) keeps its
		# calculation in sync with the scroll change.  Directly setting
		# position_offset instead would be overwritten by GraphEdit's next
		# real mouse event, causing a stutter/snap fight.
		if _node_drag_active:
			var synth := InputEventMouseMotion.new()
			synth.position = get_local_mouse_position()
			synth.global_position = get_global_mouse_position()
			synth.relative = scroll_delta
			synth.button_mask = MOUSE_BUTTON_MASK_LEFT
			get_viewport().push_input(synth)
			# Keep _node_drag_last_pos in sync so the group-move code
			# in _process() sees only mouse-driven delta, not scroll.
			_node_drag_last_pos += scroll_delta / zoom


# ─────────────────────────────────────────────────────────────────────────────
# Toast notifications — temporary overlay messages
# ─────────────────────────────────────────────────────────────────────────────
enum ToastType { INFO, WARNING, ERROR }


## Pin the toast stack to the top-center of the visible GraphEdit rect.
func _update_toast_position() -> void:
	if _toast_container == null or not is_inside_tree():
		return
	var vis := get_global_rect()
	var sz := _toast_container.get_combined_minimum_size()
	_toast_container.size = sz
	_toast_container.global_position = Vector2(
		vis.position.x + (vis.size.x - sz.x) * 0.5,
		vis.position.y + _TOAST_TOP_MARGIN
	)


func show_toast(message: String, type: int = ToastType.INFO, duration: float = 3.0) -> void:
	if _toast_container == null:
		return

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	match type:
		ToastType.ERROR:
			sb.bg_color = Color(0.7, 0.15, 0.15, 0.92)
		ToastType.WARNING:
			sb.bg_color = Color(0.72, 0.55, 0.1, 0.92)
		_:
			sb.bg_color = Color(0.18, 0.18, 0.22, 0.92)
	panel.add_theme_stylebox_override("panel", sb)

	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 14)
	panel.add_child(label)

	panel.modulate.a = 0.0
	_toast_container.add_child(panel)

	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)
	tw.tween_interval(duration)
	tw.tween_property(panel, "modulate:a", 0.0, 0.3)
	tw.tween_callback(panel.queue_free)


## Callback for GNLogger.toast_sink — maps logger levels to toast types.
func _on_logger_toast(log_level: int, message: String) -> void:
	match log_level:
		GNLogger.Level.ERROR:
			show_toast(message, ToastType.ERROR)
		GNLogger.Level.WARN:
			show_toast(message, ToastType.WARNING)


# ═══════════════════════════════════════════════════════════════════════════════
# Drag-and-Drop — .gnpatch and .gnasset files from OS file browser
# ═══════════════════════════════════════════════════════════════════════════════

## Accepts .gnpatch and .gnasset file drops from the OS file browser.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.has("files"):
		var files: PackedStringArray = data["files"]
		for f in files:
			if f.ends_with(".gnpatch") or f.ends_with(".gnasset"):
				return true
	return false


## Handles dropped .gnpatch / .gnasset files.
func _drop_data(at_position: Vector2, data: Variant) -> void:
	if network == null or read_only:
		return
	if not (data is Dictionary and data.has("files")):
		return

	var files: PackedStringArray = data["files"]
	var graph_pos := (at_position + scroll_offset) / zoom
	var offset_step := Vector2(40, 40)
	var idx := 0

	for file_path in files:
		var drop_pos := graph_pos + offset_step * idx
		if file_path.ends_with(".gnpatch"):
			_drop_gnpatch(file_path, drop_pos)
			idx += 1
		elif file_path.ends_with(".gnasset"):
			_drop_gnasset(file_path, drop_pos)
			idx += 1


## Creates a SubNetworkNode from a dropped .gnpatch file.
func _drop_gnpatch(file_path: String, graph_pos: Vector2) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		GNLogger.error("GraphEditor", "Cannot read dropped .gnpatch: %s" % file_path)
		return
	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_text) != OK:
		GNLogger.error("GraphEditor", "JSON parse error in %s" % file_path)
		return

	var data: Dictionary = json.data if json.data is Dictionary else {}
	if data.is_empty() or not data.has("nodes"):
		GNLogger.error("GraphEditor", "Invalid .gnpatch: %s" % file_path)
		return

	var label := file_path.get_file().get_basename().to_pascal_case()
	var meta: Dictionary = data.get("_metadata", {})
	var family_str: String = meta.get("family", "COMP")

	var subnet := SubNetworkNode.new()
	var unique_id := network.generate_unique_id("sub_network")
	subnet.initialize(unique_id)
	subnet.graph_position = graph_pos
	subnet.family = GNFamily.string_to_type(family_str)
	subnet._ensure_inner_network()

	var clean_data := data.duplicate()
	clean_data.erase("_metadata")
	subnet.inner_network.from_dict(clean_data)
	subnet.sync_ports_from_tunnels()

	if subnet.parameters.has("label"):
		subnet.parameters["label"].value = meta.get("source_label", label)

	network.add_node(subnet)
	_create_node_view(subnet)
	GNLogger.info("GraphEditor", "Dropped .gnpatch '%s' as sub-network '%s'" % [
		file_path.get_file(), unique_id])


## Creates a GNCustomOperator instance from a dropped .gnasset file.
func _drop_gnasset(file_path: String, graph_pos: Vector2) -> void:
	# Ensure asset is registered
	var reg := GNExtensionRegistry.instance()
	var data := GNCustomOperator._read_asset_json(file_path)
	if data.is_empty():
		GNLogger.error("GraphEditor", "Invalid .gnasset: %s" % file_path)
		return
	var identity: Dictionary = data.get("identity", {})
	var op_name: String = identity.get("op_name", "")
	if op_name.is_empty():
		GNLogger.error("GraphEditor", "Asset missing op_name: %s" % file_path)
		return

	# Register if not already known (e.g., file from outside scanned dirs)
	if not reg.has_operator(op_name):
		reg._register_custom_asset(file_path)

	# Create the instance
	var node := GNCustomOperator.new()
	if not node.load_from_asset(file_path):
		GNLogger.error("GraphEditor", "Failed to load .gnasset: %s" % file_path)
		node.free()
		return

	var unique_id := network.generate_unique_id(node.node_type)
	node.initialize(unique_id)
	node.graph_position = graph_pos

	network.add_node(node)
	_create_node_view(node)
	GNLogger.info("GraphEditor", "Dropped .gnasset '%s' as '%s'" % [
		file_path.get_file(), unique_id])
