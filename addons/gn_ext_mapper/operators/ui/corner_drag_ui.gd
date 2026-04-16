class_name CornerDragUI
extends GNUiBase
## Interactive 4-corner drag pad.  Outputs TL/TR/BL/BR corner positions
## as CHOP channels — wire into QuadMapTOP or StonerTOP corner parameters.

const _CORNER_KEYS: PackedStringArray = ["tl", "tr", "bl", "br"]
const _DEFAULTS := [
	Vector2(0.0, 0.0),  # TL
	Vector2(1.0, 0.0),  # TR
	Vector2(0.0, 1.0),  # BL
	Vector2(1.0, 1.0),  # BR
]

var _pad: Control = null
var _corners: PackedVector2Array = PackedVector2Array()
var _dragging: int = -1

const HANDLE_RADIUS := 6.0
const GRAB_RADIUS := 12.0


func _init() -> void:
	node_type = "corner_drag"
	_corners.resize(4)
	for i in range(4):
		_corners[i] = _DEFAULTS[i]


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("label", "Corner Drag", "Label", "Display label"))
	add_parameter(GNParameter.create_int("size", 200, 64, 512, "Size", "Pad size in pixels"))
	add_parameter(GNParameter.create_bool("fill_parent", false, "Fill Parent", "Expand to fill parent — enables aligned overlay in WindowOUT"))
	add_parameter(GNParameter.create_color("bg_color", Color(0.12, 0.12, 0.15), "Background", "Pad background"))
	add_parameter(GNParameter.create_color("handle_color", Color(1.0, 0.35, 0.15), "Handle Color", "Corner handle color"))
	add_parameter(GNParameter.create_color("wire_color", Color(0.6, 0.85, 1.0, 0.5), "Wire Color", "Wireframe outline"))


func _cook(_inputs: Array[GNData]) -> GNData:
	_ensure_pad()

	var fill: bool = get_param_value("fill_parent")
	var sz: int = get_param_value("size")
	if fill:
		_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_pad.custom_minimum_size = Vector2.ZERO
	else:
		_pad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_pad.size_flags_vertical = Control.SIZE_FILL
		_pad.custom_minimum_size = Vector2(sz, sz + 18)
	_pad.queue_redraw()

	widget_state = {}
	for i in range(4):
		var key: String = _CORNER_KEYS[i]
		widget_state[key + "_x"] = _corners[i].x
		widget_state[key + "_y"] = _corners[i].y

	return null


func _ensure_pad() -> void:
	if _pad != null:
		return
	_pad = Control.new()
	_pad.name = id + "_cornerdrag"
	_pad.gui_input.connect(_on_pad_input)
	_pad.draw.connect(_on_pad_draw)
	_control_node = _pad
	# Restore corners from saved widget_state
	for i in range(4):
		var key: String = _CORNER_KEYS[i]
		_corners[i] = Vector2(
			widget_state.get(key + "_x", _DEFAULTS[i].x),
			widget_state.get(key + "_y", _DEFAULTS[i].y))


## Returns the pixel area used for UV ↔ pixel mapping.
func _draw_area() -> Vector2:
	if get_param_value("fill_parent"):
		return _pad.size
	var sz: float = float(get_param_value("size"))
	return Vector2(sz, sz)


func _on_pad_input(event: InputEvent) -> void:
	var area := _draw_area()

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = _hit_test(mb.position, area)
			else:
				_dragging = -1
	elif event is InputEventMouseMotion and _dragging >= 0:
		var pos: Vector2 = (event as InputEventMouseMotion).position
		_corners[_dragging] = Vector2(
			clampf(pos.x / area.x, -0.2, 1.2),
			clampf(pos.y / area.y, -0.2, 1.2))
		_pad.queue_redraw()
		mark_dirty()


func _hit_test(pos: Vector2, area: Vector2) -> int:
	var best := -1
	var best_dist := GRAB_RADIUS
	for i in range(4):
		var px := Vector2(_corners[i].x * area.x, _corners[i].y * area.y)
		var d: float = pos.distance_to(px)
		if d < best_dist:
			best_dist = d
			best = i
	return best


func _on_pad_draw() -> void:
	if _pad == null:
		return
	var area := _draw_area()
	var fill: bool = get_param_value("fill_parent")
	var bg: Color = get_param_value("bg_color")
	var hc: Color = get_param_value("handle_color")
	var wc: Color = get_param_value("wire_color")

	# Background
	_pad.draw_rect(Rect2(Vector2.ZERO, area), bg)
	if not fill:
		_pad.draw_rect(Rect2(Vector2.ZERO, area), Color(0.3, 0.3, 0.35), false, 1.0)

	# Wireframe quad (TL → TR → BR → BL)
	var order := [0, 1, 3, 2]
	for i in range(4):
		var a := Vector2(_corners[order[i]].x * area.x, _corners[order[i]].y * area.y)
		var b := Vector2(_corners[order[(i + 1) % 4]].x * area.x, _corners[order[(i + 1) % 4]].y * area.y)
		_pad.draw_line(a, b, wc, 1.5, true)

	# Handles
	for i in range(4):
		var px := Vector2(_corners[i].x * area.x, _corners[i].y * area.y)
		var color := hc.lightened(0.3) if i == _dragging else hc
		_pad.draw_circle(px, HANDLE_RADIUS, color)
		_pad.draw_arc(px, HANDLE_RADIUS, 0, TAU, 24, Color(1, 1, 1, 0.5), 1.0, true)

	# Label (hidden in fill mode)
	if not fill:
		var sz: int = get_param_value("size")
		_pad.draw_string(ThemeDB.fallback_font, Vector2(0, sz + 14),
			get_param_value("label"), HORIZONTAL_ALIGNMENT_CENTER, sz, 11)


func destroy_control_node() -> void:
	if _pad != null:
		if _pad.gui_input.is_connected(_on_pad_input):
			_pad.gui_input.disconnect(_on_pad_input)
		if _pad.draw.is_connected(_on_pad_draw):
			_pad.draw.disconnect(_on_pad_draw)
	_pad = null
	_dragging = -1
	for i in range(4):
		_corners[i] = _DEFAULTS[i]
	super.destroy_control_node()
