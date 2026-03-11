class_name XYPadUI
extends GNUiBase
## 2D XY pad widget for PanelTOP.
##
## Click/drag to set an (x, y) position within a normalized rectangle.
## Outputs widget_state: {"x": <float>, "y": <float>}

var _pad: Control = null
var _x: float = 0.5
var _y: float = 0.5
var _dragging: bool = false


func _init() -> void:
	node_type = "xypad"
	node_description = "2D XY pad — click/drag to set position. Outputs normalized x, y."


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("label", "XY Pad", "Label", "Display label"))
	add_parameter(GNParameter.create_int("size", 128, 48, 512, "Size", "Pad size in pixels"))
	add_parameter(GNParameter.create_color("pad_color", Color(0.2, 0.2, 0.25), "Pad Color", "Background color"))
	add_parameter(GNParameter.create_color("cursor_color", Color(1.0, 0.4, 0.2), "Cursor Color", "Crosshair cursor color"))
	add_parameter(GNParameter.create_float("default_x", 0.5, 0.0, 1.0, 0.01, "Default X", "Initial X"))
	add_parameter(GNParameter.create_float("default_y", 0.5, 0.0, 1.0, 0.01, "Default Y", "Initial Y"))


func _cook(_inputs: Array[GNData]) -> GNData:
	_ensure_pad()

	var sz: int = get_param_value("size")
	_pad.custom_minimum_size = Vector2(sz, sz + 18)
	_pad.queue_redraw()

	widget_state = {
		"x": _x,
		"y": _y,
	}

	return null


func _ensure_pad() -> void:
	if _pad != null:
		return
	_pad = Control.new()
	_pad.name = id + "_xypad"
	_pad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_pad.gui_input.connect(_on_pad_input)
	_pad.draw.connect(_on_pad_draw)
	_x = get_param_value("default_x")
	_y = get_param_value("default_y")
	_control_node = _pad


func _on_pad_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if _dragging:
				_update_from_mouse(mb.position)
	elif event is InputEventMouseMotion and _dragging:
		_update_from_mouse((event as InputEventMouseMotion).position)


func _update_from_mouse(pos: Vector2) -> void:
	var sz: float = float(get_param_value("size"))
	_x = clampf(pos.x / sz, 0.0, 1.0)
	_y = clampf(pos.y / sz, 0.0, 1.0)
	widget_state["x"] = _x
	widget_state["y"] = _y
	_pad.queue_redraw()
	mark_dirty()


func _on_pad_draw() -> void:
	if _pad == null:
		return
	var sz: int = get_param_value("size")
	var pad_color: Color = get_param_value("pad_color")
	var cursor_color: Color = get_param_value("cursor_color")
	var rect := Rect2(0, 0, sz, sz)

	# Background
	_pad.draw_rect(rect, pad_color)
	# Border
	_pad.draw_rect(rect, Color(0.4, 0.4, 0.45), false, 1.0)

	# Crosshair
	var cx: float = _x * sz
	var cy: float = _y * sz
	_pad.draw_line(Vector2(cx, 0), Vector2(cx, sz), cursor_color.darkened(0.4), 1.0)
	_pad.draw_line(Vector2(0, cy), Vector2(sz, cy), cursor_color.darkened(0.4), 1.0)

	# Cursor dot
	_pad.draw_circle(Vector2(cx, cy), 5.0, cursor_color)

	# Label
	var label_text: String = get_param_value("label")
	_pad.draw_string(ThemeDB.fallback_font, Vector2(0, sz + 14),
		"%s: (%.2f, %.2f)" % [label_text, _x, _y], HORIZONTAL_ALIGNMENT_CENTER,
		sz, 11)


func destroy_control_node() -> void:
	if _pad != null:
		if _pad.gui_input.is_connected(_on_pad_input):
			_pad.gui_input.disconnect(_on_pad_input)
		if _pad.draw.is_connected(_on_pad_draw):
			_pad.draw.disconnect(_on_pad_draw)
	_pad = null
	_x = 0.5
	_y = 0.5
	_dragging = false
	super.destroy_control_node()
