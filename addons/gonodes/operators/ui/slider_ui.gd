class_name SliderUI
extends GNUiBase
## Horizontal slider widget for PanelTOP.
##
## Outputs widget_state: {"value": <float>}
## Value range is configurable via min_val / max_val parameters.

var _slider: HSlider = null


func _init() -> void:
	node_type = "slider"


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("label", "Slider", "Label", "Display label"))
	add_parameter(GNParameter.create_float("min_val", 0.0, null, null, 0.01, "Min", "Minimum value"))
	add_parameter(GNParameter.create_float("max_val", 1.0, null, null, 0.01, "Max", "Maximum value"))
	add_parameter(GNParameter.create_float("step", 0.01, 0.0, 1.0, 0.001, "Step", "Value step (0 = continuous)"))
	add_parameter(GNParameter.create_float("default_val", 0.5, null, null, 0.01, "Default", "Initial value"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(200, 24), "Min Size", "Minimum slider size"))


func _cook(_inputs: Array[GNData]) -> GNData:
	_ensure_slider()

	_slider.min_value = get_param_value("min_val")
	_slider.max_value = get_param_value("max_val")
	_slider.step = get_param_value("step")
	var ms: Vector2i = get_param_value("min_size")
	_slider.custom_minimum_size = Vector2(ms.x, ms.y)

	widget_state = {
		"value": _slider.value,
	}

	return null


func _ensure_slider() -> void:
	if _slider != null:
		return
	_slider = HSlider.new()
	_slider.name = id + "_slider"
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.min_value = get_param_value("min_val")
	_slider.max_value = get_param_value("max_val")
	_slider.step = get_param_value("step")
	_slider.value = widget_state.get("value", get_param_value("default_val"))
	_slider.value_changed.connect(_on_value_changed)
	_control_node = _slider


func _on_value_changed(_value: float) -> void:
	widget_state["value"] = _slider.value
	mark_dirty()


var _remote_dragging: bool = false


## Override: HSlider's C++ input handler doesn't fire via gui_input signal,
## so we compute the value directly from the mouse position.
func _dispatch_panel_input(event: InputEvent) -> void:
	if _slider == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_remote_dragging = mb.pressed
			if mb.pressed:
				_set_slider_from_pos(mb.position.x)
			return
	elif event is InputEventMouseMotion and _remote_dragging:
		_set_slider_from_pos(event.position.x)


func _set_slider_from_pos(x: float) -> void:
	var ratio := clampf(x / maxf(_slider.size.x, 1.0), 0.0, 1.0)
	_slider.value = _slider.min_value + ratio * (_slider.max_value - _slider.min_value)


func destroy_control_node() -> void:
	if _slider != null and _slider.value_changed.is_connected(_on_value_changed):
		_slider.value_changed.disconnect(_on_value_changed)
	_slider = null
	super.destroy_control_node()
