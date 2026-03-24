class_name CheckBoxUI
extends GNUiBase
## Checkbox widget for PanelTOP.
##
## Unlike ToggleUI (CheckButton with on/off label), this is a standard
## checkbox with a text label beside it — mirrors Godot's CheckBox.
## Outputs widget_state: {"value": 0 or 1}

var _checkbox: CheckBox = null


func _init() -> void:
	node_type = "check_box"


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("label", "Check", "Label", "Checkbox label text"))
	add_parameter(GNParameter.create_bool("default_on", false, "Default On", "Initial checked state"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(100, 24), "Min Size", "Minimum widget size"))


func _cook(_inputs: Array[GNData]) -> GNData:
	_ensure_checkbox()

	_checkbox.text = get_param_value("label")
	var ms: Vector2i = get_param_value("min_size")
	_checkbox.custom_minimum_size = Vector2(ms.x, ms.y)

	widget_state = {"value": 1.0 if _checkbox.button_pressed else 0.0}
	return null


func _ensure_checkbox() -> void:
	if _checkbox != null:
		return
	_checkbox = CheckBox.new()
	_checkbox.name = id + "_checkbox"
	_checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_checkbox.button_pressed = get_param_value("default_on")
	_checkbox.toggled.connect(_on_toggled)
	_control_node = _checkbox


func _on_toggled(_pressed: bool) -> void:
	widget_state["value"] = 1.0 if _checkbox.button_pressed else 0.0
	mark_dirty()


func destroy_control_node() -> void:
	if _checkbox != null and _checkbox.toggled.is_connected(_on_toggled):
		_checkbox.toggled.disconnect(_on_toggled)
	_checkbox = null
	super.destroy_control_node()
