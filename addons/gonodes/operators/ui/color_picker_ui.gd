class_name ColorPickerUI
extends GNUiBase
## Color picker widget for PanelTOP.
##
## Outputs widget_state: {"r": <float>, "g": <float>, "b": <float>, "a": <float>}

var _picker: ColorPickerButton = null


func _init() -> void:
	node_type = "color_picker"


func _init_parameters() -> void:
	add_parameter(GNParameter.create_color("default_color", Color.WHITE, "Default", "Initial color"))
	add_parameter(GNParameter.create_bool("edit_alpha", true, "Edit Alpha", "Show alpha slider"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(80, 32), "Min Size", "Minimum widget size"))


func _cook(_inputs: Array[GNData]) -> GNData:
	_ensure_picker()

	_picker.edit_alpha = get_param_value("edit_alpha")
	var ms: Vector2i = get_param_value("min_size")
	_picker.custom_minimum_size = Vector2(ms.x, ms.y)

	var c: Color = _picker.color
	widget_state = {"r": c.r, "g": c.g, "b": c.b, "a": c.a}
	return null


func _ensure_picker() -> void:
	if _picker != null:
		return
	_picker = ColorPickerButton.new()
	_picker.name = id + "_colorpicker"
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var def: Color = get_param_value("default_color")
	_picker.color = Color(
		widget_state.get("r", def.r),
		widget_state.get("g", def.g),
		widget_state.get("b", def.b),
		widget_state.get("a", def.a))
	_picker.edit_alpha = get_param_value("edit_alpha")
	_picker.color_changed.connect(_on_color_changed)
	_control_node = _picker


func _on_color_changed(color: Color) -> void:
	widget_state = {"r": color.r, "g": color.g, "b": color.b, "a": color.a}
	mark_dirty()


## Swatch colors for the overlay grid.
const _SWATCH_COLORS: Array[Color] = [
	Color.WHITE, Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW,
	Color.CYAN, Color.MAGENTA, Color.ORANGE, Color(0.2, 0.6, 1.0), Color(0.5, 0.0, 0.8),
]


var _overlay_grid: GridContainer = null


## Override: show an inline color swatch grid overlay instead of the native popup.
func _dispatch_panel_input(event: InputEvent) -> void:
	if _picker == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_show_color_overlay()


func _show_color_overlay() -> void:
	var grid := GridContainer.new()
	grid.name = "ColorGrid"
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)

	for color in _SWATCH_COLORS:
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(30, 30)
		swatch.size = Vector2(30, 30)
		swatch.color = color
		swatch.mouse_filter = Control.MOUSE_FILTER_STOP
		grid.add_child(swatch)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 0.95)
	style.border_color = Color(0.4, 0.4, 0.4, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(grid)
	panel.custom_minimum_size = Vector2(5 * 32 + 8, 2 * 32 + 8)
	panel.size = panel.custom_minimum_size

	_overlay_grid = grid
	_request_panel_overlay(panel)


func _handle_overlay_input(event: InputEvent) -> bool:
	if _overlay_grid == null:
		return false
	if not (event is InputEventMouseButton):
		return false
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or mb.pressed:
		return false

	for i in range(_overlay_grid.get_child_count()):
		var swatch := _overlay_grid.get_child(i) as ColorRect
		if swatch != null and swatch.get_global_rect().has_point(mb.position):
			_picker.color = swatch.color
			_picker.emit_signal("color_changed", _picker.color)
			_dismiss_panel_overlay()
			return true
	_dismiss_panel_overlay()
	return true


func _on_overlay_dismissed() -> void:
	_overlay_grid = null


func destroy_control_node() -> void:
	if _picker != null and _picker.color_changed.is_connected(_on_color_changed):
		_picker.color_changed.disconnect(_on_color_changed)
	_picker = null
	super.destroy_control_node()
