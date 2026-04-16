class_name ButtonUI
extends GNUiBase
## Interactive push button widget for PanelTOP.
##
## Outputs widget_state: {"press": 0.0 or 1.0, "toggle": 0.0 or 1.0}
## press = 1.0 only on the frame the button is clicked (impulse).
## toggle = alternates 0/1 each click when toggle_mode is enabled.

var _button: Button = null
var _toggle_value: float = 0.0
## Set true by signal, consumed (reset) after one cook frame.
var _press_impulse: bool = false


func _init() -> void:
	node_type = "button"


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

	if _button.toggle_mode:
		_button.button_pressed = widget_state.get("toggle", 0.0) > 0.5
		_toggle_value = 1.0 if _button.button_pressed else 0.0

	# Build widget_state: press impulse lasts exactly one cook frame.
	widget_state = {
		"press": 1.0 if _press_impulse else 0.0,
		"toggle": _toggle_value,
		"hover": widget_state.get("hover", 0.0),
	}
	if _press_impulse:
		_press_impulse = false
		# Schedule another cook so press resets to 0.0 next frame.
		mark_dirty.call_deferred()

	return null


func _ensure_button() -> void:
	if _button != null:
		return
	_button = Button.new()
	_button.name = id + "_btn"
	_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button.pressed.connect(_on_button_pressed)
	_button.mouse_entered.connect(_on_hover_changed.bind(true))
	_button.mouse_exited.connect(_on_hover_changed.bind(false))
	_control_node = _button


func _on_button_pressed() -> void:
	_press_impulse = true
	if _button.toggle_mode:
		_toggle_value = 1.0 if _button.button_pressed else 0.0
	mark_dirty()


func _on_hover_changed(hovered: bool) -> void:
	widget_state["hover"] = 1.0 if hovered else 0.0
	mark_dirty()


func destroy_control_node() -> void:
	if _button != null:
		if _button.pressed.is_connected(_on_button_pressed):
			_button.pressed.disconnect(_on_button_pressed)
		if _button.mouse_entered.is_connected(_on_hover_changed):
			_button.mouse_entered.disconnect(_on_hover_changed)
		if _button.mouse_exited.is_connected(_on_hover_changed):
			_button.mouse_exited.disconnect(_on_hover_changed)
	_button = null
	_toggle_value = 0.0
	super.destroy_control_node()
