class_name KnobUI
extends GNUiBase
## Rotary knob widget for PanelTOP.
##
## Renders a dial via custom draw on a Control. Drag vertically to change value.
## Outputs widget_state: {"value": <float>, "angle": <degrees>}

var _knob: Control = null
var _value: float = 0.5
var _dragging: bool = false
var _drag_start_y: float = 0.0
var _drag_start_val: float = 0.0


func _init() -> void:
	node_type = "knob"


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("label", "Knob", "Label", "Display label"))
	add_parameter(GNParameter.create_float("min_val", 0.0, null, null, 0.01, "Min", "Minimum value"))
	add_parameter(GNParameter.create_float("max_val", 1.0, null, null, 0.01, "Max", "Maximum value"))
	add_parameter(GNParameter.create_float("default_val", 0.5, null, null, 0.01, "Default", "Initial value"))
	add_parameter(GNParameter.create_int("size", 64, 32, 256, "Size", "Knob diameter in pixels"))
	add_parameter(GNParameter.create_color("knob_color", Color(0.3, 0.6, 1.0), "Color", "Knob arc color"))


func _cook(_inputs: Array[GNData]) -> GNData:
	_ensure_knob()

	var sz: int = get_param_value("size")
	_knob.custom_minimum_size = Vector2(sz, sz + 18)  # +18 for label below

	# Clamp value to current range
	var min_v: float = get_param_value("min_val")
	var max_v: float = get_param_value("max_val")
	_value = clampf(_value, min_v, max_v)

	_knob.queue_redraw()

	var angle_range := 270.0  # Arc sweep in degrees
	var norm: float = (_value - min_v) / maxf(max_v - min_v, 0.0001)
	widget_state = {
		"value": _value,
		"angle": norm * angle_range,
	}

	return null


func _ensure_knob() -> void:
	if _knob != null:
		return
	_knob = Control.new()
	_knob.name = id + "_knob"
	_knob.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_knob.gui_input.connect(_on_knob_input)
	_knob.draw.connect(_on_knob_draw)
	_value = get_param_value("default_val")
	_control_node = _knob


func _on_knob_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_start_y = mb.position.y
				_drag_start_val = _value
			else:
				_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var min_v: float = get_param_value("min_val")
		var max_v: float = get_param_value("max_val")
		var sensitivity: float = (max_v - min_v) / 150.0
		var delta_y: float = _drag_start_y - mm.position.y
		_value = clampf(_drag_start_val + delta_y * sensitivity, min_v, max_v)
		widget_state["value"] = _value
		_knob.queue_redraw()
		mark_dirty()


func _on_knob_draw() -> void:
	if _knob == null:
		return
	var sz: int = get_param_value("size")
	var radius: float = sz * 0.4
	var center := Vector2(sz * 0.5, sz * 0.5)
	var knob_color: Color = get_param_value("knob_color")
	var bg_color := Color(0.25, 0.25, 0.28)

	# Background circle
	_knob.draw_arc(center, radius, deg_to_rad(-225.0), deg_to_rad(45.0), 32, bg_color, 3.0)

	# Value arc
	var min_v: float = get_param_value("min_val")
	var max_v: float = get_param_value("max_val")
	var norm: float = (_value - min_v) / maxf(max_v - min_v, 0.0001)
	var start_angle: float = deg_to_rad(-225.0)
	var end_angle: float = start_angle + deg_to_rad(270.0 * norm)
	if norm > 0.001:
		_knob.draw_arc(center, radius, start_angle, end_angle, 32, knob_color, 3.0)

	# Indicator line
	var indicator_angle: float = start_angle + deg_to_rad(270.0 * norm)
	var inner := center + Vector2(cos(indicator_angle), sin(indicator_angle)) * (radius * 0.6)
	var outer := center + Vector2(cos(indicator_angle), sin(indicator_angle)) * radius
	_knob.draw_line(inner, outer, Color.WHITE, 2.0)

	# Label text below knob
	var label_text: String = get_param_value("label")
	_knob.draw_string(ThemeDB.fallback_font, Vector2(0, sz + 14),
		"%s: %.2f" % [label_text, _value], HORIZONTAL_ALIGNMENT_CENTER,
		sz, 11)


func destroy_control_node() -> void:
	if _knob != null:
		if _knob.gui_input.is_connected(_on_knob_input):
			_knob.gui_input.disconnect(_on_knob_input)
		if _knob.draw.is_connected(_on_knob_draw):
			_knob.draw.disconnect(_on_knob_draw)
	_knob = null
	_value = 0.5
	_dragging = false
	super.destroy_control_node()
