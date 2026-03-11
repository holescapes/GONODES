class_name ColorPickerUI
extends GNUiBase
## Color picker widget for PanelTOP.
##
## Outputs widget_state: {"r": <float>, "g": <float>, "b": <float>, "a": <float>}

var _picker: ColorPickerButton = null


func _init() -> void:
	node_type = "colorpicker"
	node_description = "Color picker button. Outputs RGBA channels as state."


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
	_picker.color = get_param_value("default_color")
	_picker.edit_alpha = get_param_value("edit_alpha")
	_picker.color_changed.connect(_on_color_changed)
	_control_node = _picker


func _on_color_changed(color: Color) -> void:
	widget_state = {"r": color.r, "g": color.g, "b": color.b, "a": color.a}
	mark_dirty()


func destroy_control_node() -> void:
	if _picker != null and _picker.color_changed.is_connected(_on_color_changed):
		_picker.color_changed.disconnect(_on_color_changed)
	_picker = null
	super.destroy_control_node()
