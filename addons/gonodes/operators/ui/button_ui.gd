class_name ButtonUI
extends GNUiBase
## Interactive push button widget for PanelTOP.
##
## Outputs widget_state: {"press": 0.0 or 1.0, "toggle": 0.0 or 1.0}
## press = 1.0 only on the frame the button is clicked (impulse).
## toggle = alternates 0/1 each click when toggle_mode is enabled.

var _button: Button = null
var _was_pressed: bool = false
var _toggle_value: float = 0.0


func _init() -> void:
	node_type = "button"
	node_description = "Interactive push button. Outputs press impulse and toggle state."


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("label", "Button", "Label", "Button text"))
	add_parameter(GNParameter.create_bool("toggle_mode", false, "Toggle Mode", "Alternate on/off each click"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(120, 40), "Min Size", "Minimum button size"))


func _cook(_inputs: Array[GNData]) -> GNData:
	_ensure_button()

	_button.text = get_param_value("label")
	_button.toggle_mode = get_param_value("toggle_mode")
	var ms: Vector2i = get_param_value("min_size")
	_button.custom_minimum_size = Vector2(ms.x, ms.y)

	# Detect press impulse
	var pressed_now: bool = _button.button_pressed if _button.toggle_mode else false
	var press_impulse: float = 0.0
	if _button.toggle_mode:
		_toggle_value = 1.0 if _button.button_pressed else 0.0
	# press impulse is handled via signal

	widget_state = {
		"press": widget_state.get("press", 0.0),
		"toggle": _toggle_value,
	}

	return null


func _ensure_button() -> void:
	if _button != null:
		return
	_button = Button.new()
	_button.name = id + "_btn"
	_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button.pressed.connect(_on_button_pressed)
	_control_node = _button


func _on_button_pressed() -> void:
	widget_state["press"] = 1.0
	if _button.toggle_mode:
		_toggle_value = 1.0 if _button.button_pressed else 0.0
		widget_state["toggle"] = _toggle_value
	mark_dirty()


func destroy_control_node() -> void:
	if _button != null and _button.pressed.is_connected(_on_button_pressed):
		_button.pressed.disconnect(_on_button_pressed)
	_button = null
	_toggle_value = 0.0
	super.destroy_control_node()
