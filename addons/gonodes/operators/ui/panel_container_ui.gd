class_name PanelContainerUI
extends GNUiBase
## Styled panel wrapper widget for PanelTOP.
##
## Wraps child UI widgets in a PanelContainer with optional StyleBox.
## Outputs widget_state: {} (pure layout, no interactive state).

var _panel: PanelContainer = null
var _inner: VBoxContainer = null
var _managed_children: Array[Control] = []
var _prev_managed: Array[Control] = []


func _init() -> void:
	node_type = "panel_container"
	node_description = "Styled panel container for child UI widgets."


func _init_ports() -> void:
	_enable_dynamic_inputs(GNFamily.Type.UI, "ui", "UI Input")
	add_output("out", GNFamily.Type.UI, "Container widget output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_color("bg_color", Color(0.15, 0.15, 0.15, 0.8), "Background", "Panel background color"))
	add_parameter(GNParameter.create_int("corner_radius", 4, 0, 32, "Corner Radius", "Rounded corner radius"))
	add_parameter(GNParameter.create_int("padding", 8, 0, 32, "Padding", "Internal padding"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(0, 0), "Min Size", "Minimum container size"))


func _cook(_inputs: Array[GNData]) -> GNData:
	_ensure_panel()

	# Update style
	var style := StyleBoxFlat.new()
	style.bg_color = get_param_value("bg_color")
	var radius: int = get_param_value("corner_radius")
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	var pad: int = get_param_value("padding")
	style.content_margin_left = pad
	style.content_margin_top = pad
	style.content_margin_right = pad
	style.content_margin_bottom = pad
	_panel.add_theme_stylebox_override("panel", style)

	var ms: Vector2i = get_param_value("min_size")
	_panel.custom_minimum_size = Vector2(ms.x, ms.y)

	_prev_managed = _managed_children.duplicate()
	_managed_children.clear()
	_populate_children()
	_remove_stale_children()

	widget_state = {}
	return null


func _ensure_panel() -> void:
	if _panel != null:
		return
	_panel = PanelContainer.new()
	_panel.name = id + "_panelcont"
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inner = VBoxContainer.new()
	_inner.name = id + "_inner"
	_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.add_child(_inner)
	_control_node = _panel


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
				if ctrl.get_parent() != _inner:
					if ctrl.get_parent() != null:
						ctrl.get_parent().remove_child(ctrl)
					_inner.add_child(ctrl)
				_managed_children.append(ctrl)


func _remove_stale_children() -> void:
	for ctrl in _prev_managed:
		if ctrl != null and is_instance_valid(ctrl) and not _managed_children.has(ctrl):
			if ctrl.get_parent() == _inner:
				_inner.remove_child(ctrl)
	_prev_managed.clear()
