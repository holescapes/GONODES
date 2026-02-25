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

## Signal emitted when an operator node is selected (for external inspector/viewer hookup).
signal operator_selected(node_id: String)

## Signal emitted when selection is cleared.
signal operator_deselected()


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

	# Create palette popup
	_palette = GNNodePalette.new()
	_palette.visible = false
	_palette.node_type_selected.connect(_on_palette_node_selected)
	add_child(_palette)

	GNLogger.info("GraphEditor", "Graph editor ready")


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			# Open node palette at mouse position
			_spawn_position = (get_local_mouse_position() + scroll_offset) / zoom
			_palette.popup_at(get_global_mouse_position())
			get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			# Right-click → open palette
			_spawn_position = (get_local_mouse_position() + scroll_offset) / zoom
			_palette.popup_at(get_global_mouse_position())
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
	add_child(view)
	_node_views[node.id] = view
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

	# Let the network validate (type check, cycle check, etc.)
	var success := network.connect_nodes(
		String(from_node), from_port, String(to_node), to_port)

	if not success:
		GNLogger.warn("GraphEditor", "Connection rejected: %s:%d → %s:%d" % [
			from_node, from_port, to_node, to_port])
	# Visual wire is added via the network signal callback (_on_network_connection_added)


## User disconnects a wire (right-click drag or right_disconnects).
func _on_disconnection_request(from_node: StringName, from_port: int,
		to_node: StringName, to_port: int) -> void:
	if network == null:
		return

	network.disconnect_nodes(String(from_node), from_port, String(to_node), to_port)
	# Visual wire removal via network signal callback (_on_network_connection_removed)


## User presses Delete with nodes selected.
func _on_delete_nodes_request(node_names: Array[StringName]) -> void:
	if network == null:
		return

	for node_name in node_names:
		var node_id := String(node_name)
		if network.nodes.has(node_id):
			network.remove_node(node_id)
			# View removal via network signal callback (_on_network_node_removed)
			GNLogger.info("GraphEditor", "User deleted node '%s'" % node_id)


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
	GNLogger.info("GraphEditor", "Spawned '%s' (%s) at %s" % [
		unique_id, operator_type, str(_spawn_position)])


## Factory that creates operator instances by type name.
## Returns null for unknown types.
static func _create_operator_instance(operator_type: String) -> GNNode:
	match operator_type:
		# ── TOPs: Generators ──
		"NoiseTOP":
			return NoiseTOP.new()
		"RampTOP":
			return RampTOP.new()
		"CircleTOP":
			return CircleTOP.new()
		"RectangleTOP":
			return RectangleTOP.new()
		"ConstantTOP":
			return ConstantTOP.new()
		"TextTOP":
			return TextTOP.new()
		# ── TOPs: Filters (1 input) ──
		"LevelTOP":
			return LevelTOP.new()
		"BlurTOP":
			return BlurTOP.new()
		"TransformTOP":
			return TransformTOP.new()
		"HSVAdjustTOP":
			return HSVAdjustTOP.new()
		"EdgeTOP":
			return EdgeTOP.new()
		"ThresholdTOP":
			return ThresholdTOP.new()
		"FlipTOP":
			return FlipTOP.new()
		"TileTOP":
			return TileTOP.new()
		"CropTOP":
			return CropTOP.new()
		"FeedbackTOP":
			return FeedbackTOP.new()
		"ResolutionTOP":
			return ResolutionTOP.new()
		# ── TOPs: Combiners (2 inputs) ──
		"CompositeTOP":
			return CompositeTOP.new()
		"CrossTOP":
			return CrossTOP.new()
		"DisplaceTOP":
			return DisplaceTOP.new()
		"LookupTOP":
			return LookupTOP.new()
		# ── TOPs: Scripting ──
		"CustomShaderTOP":
			return CustomShaderTOP.new()
		# ── TOPs: Utility ──
		"NullTOP":
			return NullTOP.new()
		"SwitchTOP":
			return SwitchTOP.new()
		# ── TOPs: 3D Rendering ──
		"RenderTOP":
			return RenderTOP.new()
		# ── TOPs: Output ──
		"WindowTOP":
			return WindowTOP.new()
		# ── CHOPs: Generators ──
		"LFO_CHOP":
			return LFO_CHOP.new()
		"WaveCHOP":
			return WaveCHOP.new()
		"NoiseCHOP":
			return NoiseCHOP.new()
		"ConstantCHOP":
			return ConstantCHOP.new()
		"PatternCHOP":
			return PatternCHOP.new()
		"TimerCHOP":
			return TimerCHOP.new()
		# ── CHOPs: Filters (1 input) ──
		"MathCHOP":
			return MathCHOP.new()
		"FilterCHOP":
			return FilterCHOP.new()
		"LagCHOP":
			return LagCHOP.new()
		"LimitCHOP":
			return LimitCHOP.new()
		"TriggerCHOP":
			return TriggerCHOP.new()
		"SpeedCHOP":
			return SpeedCHOP.new()
		"CountCHOP":
			return CountCHOP.new()
		"HoldCHOP":
			return HoldCHOP.new()
		"SelectCHOP":
			return SelectCHOP.new()
		# ── CHOPs: Combiners ──
		"LogicCHOP":
			return LogicCHOP.new()
		"MergeCHOP":
			return MergeCHOP.new()
		"CrossCHOP":
			return CrossCHOP.new()
		# ── CHOPs: Utility ──
		"NullCHOP":
			return NullCHOP.new()
		"SwitchCHOP":
			return SwitchCHOP.new()
		# ── CHOPs: Bridge ──
		"DATtoCHOP":
			return DATtoCHOP.new()
		# ── SOPs: Generators ──
		"GridSOP":
			return GridSOP.new()
		"BoxSOP":
			return BoxSOP.new()
		"SphereSOP":
			return SphereSOP.new()
		"TorusSOP":
			return TorusSOP.new()
		"CylinderSOP":
			return CylinderSOP.new()
		"LineSOP":
			return LineSOP.new()
		"CircleSOP":
			return CircleSOP.new()
		# ── SOPs: Filters ──
		"TransformSOP":
			return TransformSOP.new()
		"NoiseSOP":
			return NoiseSOP.new()
		"SubdivideSOP":
			return SubdivideSOP.new()
		"WireframeSOP":
			return WireframeSOP.new()
		# ── SOPs: Combiners ──
		"MergeSOP":
			return MergeSOP.new()
		# ── SOPs: Utility ──
		"NullSOP":
			return NullSOP.new()
		"SwitchSOP":
			return SwitchSOP.new()
		# ── DATs: Generators ──
		"ConstantDAT":
			return ConstantDAT.new()
		"TextDAT":
			return TextDAT.new()
		"InfoDAT":
			return InfoDAT.new()
		"OscInDAT":
			return OscInDAT.new()
		# ── DATs: Filters ──
		"SelectDAT":
			return SelectDAT.new()
		"TransposeDAT":
			return TransposeDAT.new()
		"SortDAT":
			return SortDAT.new()
		"EvaluateDAT":
			return EvaluateDAT.new()
		# ── DATs: Combiners ──
		"MergeDAT":
			return MergeDAT.new()
		# ── DATs: Utility ──
		"NullDAT":
			return NullDAT.new()
		"SwitchDAT":
			return SwitchDAT.new()
		# ── DATs: Bridge ──
		"CHOPDAT":
			return CHOPDAT.new()
		# ── COMPs ──
		"GeometryCOMP":
			return GeometryCOMP.new()
		"CameraCOMP":
			return CameraCOMP.new()
		"LightCOMP":
			return LightCOMP.new()
		_:
			return null


## Returns a list of all available operator types grouped by family.
## Used by the palette to display options.
static func get_operator_registry() -> Dictionary:
	return {
		"TOP": [
			"NoiseTOP", "RampTOP", "CircleTOP", "RectangleTOP",
			"ConstantTOP", "TextTOP",
			"LevelTOP", "BlurTOP", "TransformTOP", "HSVAdjustTOP",
			"EdgeTOP", "ThresholdTOP", "FlipTOP", "TileTOP",
			"CropTOP", "FeedbackTOP", "ResolutionTOP",
			"CompositeTOP", "CrossTOP", "DisplaceTOP", "LookupTOP",
			"CustomShaderTOP", "RenderTOP",
			"NullTOP", "SwitchTOP",
			"WindowTOP",
		],
		"CHOP": [
			"LFO_CHOP", "WaveCHOP", "NoiseCHOP", "ConstantCHOP",
			"PatternCHOP", "TimerCHOP",
			"MathCHOP", "FilterCHOP", "LagCHOP", "LimitCHOP",
			"TriggerCHOP", "SpeedCHOP", "CountCHOP", "HoldCHOP",
			"SelectCHOP",
			"LogicCHOP", "MergeCHOP", "CrossCHOP",
			"NullCHOP", "SwitchCHOP",
			"DATtoCHOP",
		],
		"SOP": [
			"GridSOP", "BoxSOP", "SphereSOP", "TorusSOP",
			"CylinderSOP", "LineSOP", "CircleSOP",
			"TransformSOP", "NoiseSOP", "SubdivideSOP", "WireframeSOP",
			"MergeSOP",
			"NullSOP", "SwitchSOP",
		],
		"DAT": [
			"ConstantDAT", "TextDAT", "InfoDAT", "OscInDAT",
			"SelectDAT", "TransposeDAT", "SortDAT", "EvaluateDAT",
			"MergeDAT",
			"NullDAT", "SwitchDAT",
			"CHOPDAT",
		],
		"COMP": [
			"GeometryCOMP", "CameraCOMP", "LightCOMP",
		],
	}
