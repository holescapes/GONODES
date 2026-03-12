class_name ContainerUI
extends GNUiBase
## Layout container widget for PanelTOP.
##
## Groups child UI widgets within a VBox, HBox, or Grid container.
## Accepts UI inputs via dynamic ports and nests their Control nodes
## inside its own container Control.
##
## Output 0: UI (the container Control for adoption by WindowOUT/PanelTOP).
## Output 1: CHOP (aggregated widget_state channels from all child widgets).

var _container: Container = null
var _managed_children: Array[Control] = []
var _prev_managed: Array[Control] = []
var _current_layout: int = -1




func _init() -> void:
	node_type = "container"
	node_description = "Layout container for grouping UI widgets (VBox, HBox, Grid)."


func _init_ports() -> void:
	_enable_dynamic_inputs(GNFamily.Type.UI, "ui", "UI Input")
	add_output("out", GNFamily.Type.UI, "Container widget output")
	# NOTE: CHOP "state" port is appended automatically by GNUiBase.initialize()


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("layout",
		PackedStringArray(["Vertical", "Horizontal", "Grid"]), 0,
		"Layout", "Container layout mode"))
	add_parameter(GNParameter.create_int("spacing", 4, 0, 32, "Spacing", "Gap between children"))
	add_parameter(GNParameter.create_int("padding", 4, 0, 32, "Padding", "Internal padding"))
	add_parameter(GNParameter.create_int("columns", 2, 1, 8, "Columns", "Grid columns (Grid mode only)"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(0, 0), "Min Size", "Minimum container size"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var layout_idx: int = get_param_value("layout")
	_ensure_container(layout_idx)

	var spacing: int = get_param_value("spacing")
	var padding: int = get_param_value("padding")
	var ms: Vector2i = get_param_value("min_size")

	_container.custom_minimum_size = Vector2(ms.x, ms.y)

	if _container is BoxContainer:
		(_container as BoxContainer).add_theme_constant_override("separation", spacing)
	elif _container is GridContainer:
		var grid: GridContainer = _container as GridContainer
		grid.columns = get_param_value("columns")
		grid.add_theme_constant_override("h_separation", spacing)
		grid.add_theme_constant_override("v_separation", spacing)

	# Padding via MarginContainer not available directly — use offsets
	# on the container's parent, but since we ARE the control_node,
	# padding is best done by the PanelTOP's root container.

	# Adopt child UI widgets from upstream connections
	_prev_managed = _managed_children.duplicate()
	_managed_children.clear()
	_populate_children()
	_remove_stale_children()

	widget_state = {}
	return null


func _ensure_container(layout_idx: int) -> void:
	if _container != null and _current_layout == layout_idx:
		return

	# Swap container type if needed
	var children: Array[Control] = []
	if _container != null:
		for child in _container.get_children():
			children.append(child as Control)
			_container.remove_child(child)
		_container.queue_free()
		_container = null

	match layout_idx:
		0:  # Vertical
			_container = VBoxContainer.new()
		1:  # Horizontal
			_container = HBoxContainer.new()
		2:  # Grid
			_container = GridContainer.new()

	_container.name = id + "_container"
	_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_container.size_flags_vertical = Control.SIZE_EXPAND_FILL

	for child in children:
		_container.add_child(child)

	_control_node = _container
	_current_layout = layout_idx


func _populate_children() -> void:
	var engine: GNCookEngine = get_parent() as GNCookEngine if get_parent() is GNCookEngine else null
	if engine == null or engine.network == null:
		return

	var network: GNNetwork = engine.network
	var conns: Array = network.get_input_connections(id).duplicate()
	conns.sort_custom(func(a: GNConnection, b: GNConnection) -> bool:
		return a.to_port < b.to_port)

	for conn in conns:
		var upstream: GNNode = network.nodes.get(conn.from_node, null)
		if upstream is GNUiBase:
			var ctrl: Control = (upstream as GNUiBase).get_control_node()
			if ctrl != null:
				if ctrl.get_parent() != _container:
					if ctrl.get_parent() != null:
						ctrl.get_parent().remove_child(ctrl)
					_container.add_child(ctrl)
				_managed_children.append(ctrl)


func _remove_stale_children() -> void:
	for ctrl in _prev_managed:
		if ctrl != null and is_instance_valid(ctrl) and not _managed_children.has(ctrl):
			if ctrl.get_parent() == _container:
				_container.remove_child(ctrl)
	_prev_managed.clear()


## Overrides base class: aggregates widget_state from ALL connected children
## (not just this container's own empty state).
func _build_state_chop() -> void:
	if _cached_state_chop == null:
		_cached_state_chop = GNChannelData.new()
	_cached_state_chop.channels.clear()
	_cached_state_chop.length = 1
	_cached_state_chop.sample_rate = 60.0

	var engine: GNCookEngine = get_parent() as GNCookEngine if get_parent() is GNCookEngine else null
	if engine == null or engine.network == null:
		return

	var network: GNNetwork = engine.network
	for conn in network.get_input_connections(id):
		var upstream: GNNode = network.nodes.get(conn.from_node, null)
		if upstream is GNUiBase:
			var ui: GNUiBase = upstream as GNUiBase
			for key in ui.widget_state:
				var ch_name: String = "%s:%s" % [ui.id, key]
				_cached_state_chop.set_single_value(ch_name, float(ui.widget_state[key]))


func destroy_control_node() -> void:
	for ctrl in _managed_children:
		if ctrl != null and is_instance_valid(ctrl) and ctrl.get_parent() == _container:
			_container.remove_child(ctrl)
	_managed_children.clear()
	_prev_managed.clear()
	_container = null
	_current_layout = -1
	super.destroy_control_node()
