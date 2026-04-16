class_name ToggleUI
extends GNUiBase
## Toggle / checkbox widget for PanelTOP.
##
## Outputs widget_state: {"value": 0.0 or 1.0}

var _check: CheckButton = null


func _init() -> void:
	node_type = "toggle"


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("label", "Toggle", "Label", "Display label"))
	add_parameter(GNParameter.create_bool("default_on", false, "Default On", "Initial toggle state"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(120, 32), "Min Size", "Minimum widget size"))


func _cook(_inputs: Array[GNData]) -> GNData:
	_ensure_check()

	_check.text = get_param_value("label")
	var ms: Vector2i = get_param_value("min_size")
	_check.custom_minimum_size = Vector2(ms.x, ms.y)

	widget_state = {
		"value": 1.0 if _check.button_pressed else 0.0,
	}

	return null


func _ensure_check() -> void:
	if _check != null:
		return
	_check = CheckButton.new()
	_check.name = id + "_toggle"
	_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_check.button_pressed = widget_state.get("value", 1.0 if get_param_value("default_on") else 0.0) > 0.5
	_check.toggled.connect(_on_toggled)
	_control_node = _check


func _on_toggled(_pressed: bool) -> void:
	widget_state["value"] = 1.0 if _check.button_pressed else 0.0
	mark_dirty()


func destroy_control_node() -> void:
	if _check != null and _check.toggled.is_connected(_on_toggled):
		_check.toggled.disconnect(_on_toggled)
	_check = null
	super.destroy_control_node()
