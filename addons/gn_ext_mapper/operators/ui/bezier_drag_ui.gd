class_name BezierDragUI
extends GNUiBase
## Interactive 4×4 Bezier control point grid.  Drag handles to reshape the
## surface.  Outputs 32 CHOP channels with human-readable position names
## (top_left_x/y through bot_right_x/y) — wire directly into BezierMapTOP.

# Row-major order: row 0-3 (top→bottom), col 0-3 (left→right).
const _CP_NAMES: PackedStringArray = [
	"top_left", "top_cleft", "top_cright", "top_right",
	"umid_left", "umid_cleft", "umid_cright", "umid_right",
	"lmid_left", "lmid_cleft", "lmid_cright", "lmid_right",
	"bot_left", "bot_cleft", "bot_cright", "bot_right",
]

# Default positions: uniform 4×4 grid
const _DEFAULTS := [
	Vector2(0.0, 0.0), Vector2(0.333, 0.0), Vector2(0.667, 0.0), Vector2(1.0, 0.0),
	Vector2(0.0, 0.333), Vector2(0.333, 0.333), Vector2(0.667, 0.333), Vector2(1.0, 0.333),
	Vector2(0.0, 0.667), Vector2(0.333, 0.667), Vector2(0.667, 0.667), Vector2(1.0, 0.667),
	Vector2(0.0, 1.0), Vector2(0.333, 1.0), Vector2(0.667, 1.0), Vector2(1.0, 1.0),
]

var _pad: Control = null
var _points: PackedVector2Array = PackedVector2Array()
var _dragging: int = -1

const HANDLE_RADIUS := 5.0
const GRAB_RADIUS := 10.0


func _init() -> void:
	node_type = "bezier_drag"
	_points.resize(16)
	for i in range(16):
		_points[i] = _DEFAULTS[i]


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("label", "Bezier Drag", "Label", "Display label"))
	add_parameter(GNParameter.create_int("size", 200, 64, 512, "Size", "Pad size in pixels"))
	add_parameter(GNParameter.create_color("bg_color", Color(0.12, 0.12, 0.15), "Background", "Pad background"))
	add_parameter(GNParameter.create_color("handle_color", Color(1.0, 0.35, 0.15), "Handle Color", "Control point color"))
	add_parameter(GNParameter.create_color("wire_color", Color(0.6, 0.85, 1.0, 0.5), "Wire Color", "Grid wireframe"))


func _cook(_inputs: Array[GNData]) -> GNData:
	_ensure_pad()

	var sz: int = get_param_value("size")
	_pad.custom_minimum_size = Vector2(sz, sz + 18)
	_pad.queue_redraw()

	widget_state = {}
	for i in range(16):
		var key: String = _CP_NAMES[i]
		widget_state[key + "_x"] = _points[i].x
		widget_state[key + "_y"] = _points[i].y

	return null


func _ensure_pad() -> void:
	if _pad != null:
		return
	_pad = Control.new()
	_pad.name = id + "_bezierdrag"
	_pad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_pad.gui_input.connect(_on_pad_input)
	_pad.draw.connect(_on_pad_draw)
	_control_node = _pad


func _on_pad_input(event: InputEvent) -> void:
	var sz: float = float(get_param_value("size"))

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = _hit_test(mb.position, sz)
			else:
				_dragging = -1
	elif event is InputEventMouseMotion and _dragging >= 0:
		var pos: Vector2 = (event as InputEventMouseMotion).position
		_points[_dragging] = Vector2(
			clampf(pos.x / sz, -0.2, 1.2),
			clampf(pos.y / sz, -0.2, 1.2))
		_pad.queue_redraw()
		mark_dirty()


func _hit_test(pos: Vector2, sz: float) -> int:
	var best := -1
	var best_dist := GRAB_RADIUS
	for i in range(16):
		var px := Vector2(_points[i].x * sz, _points[i].y * sz)
		var d: float = pos.distance_to(px)
		if d < best_dist:
			best_dist = d
			best = i
	return best


func _on_pad_draw() -> void:
	if _pad == null:
		return
	var sz: int = get_param_value("size")
	var bg: Color = get_param_value("bg_color")
	var hc: Color = get_param_value("handle_color")
	var wc: Color = get_param_value("wire_color")

	_pad.draw_rect(Rect2(0, 0, sz, sz), bg)
	_pad.draw_rect(Rect2(0, 0, sz, sz), Color(0.3, 0.3, 0.35), false, 1.0)

	# Grid wireframe (4×4, row-major)
	for row in range(4):
		for col in range(3):
			var a_idx: int = row * 4 + col
			var b_idx: int = row * 4 + col + 1
			_pad.draw_line(
				Vector2(_points[a_idx].x * sz, _points[a_idx].y * sz),
				Vector2(_points[b_idx].x * sz, _points[b_idx].y * sz),
				wc, 1.0, true)
	for col in range(4):
		for row in range(3):
			var a_idx: int = row * 4 + col
			var b_idx: int = (row + 1) * 4 + col
			_pad.draw_line(
				Vector2(_points[a_idx].x * sz, _points[a_idx].y * sz),
				Vector2(_points[b_idx].x * sz, _points[b_idx].y * sz),
				wc, 1.0, true)

	# Handles — corner points slightly larger
	for i in range(16):
		var px := Vector2(_points[i].x * sz, _points[i].y * sz)
		var is_corner: bool = (i == 0 or i == 3 or i == 12 or i == 15)
		var r: float = HANDLE_RADIUS + 1.0 if is_corner else HANDLE_RADIUS
		var color := hc.lightened(0.3) if i == _dragging else hc
		_pad.draw_circle(px, r, color)
		_pad.draw_arc(px, r, 0, TAU, 24, Color(1, 1, 1, 0.4), 1.0, true)

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
	_points.resize(16)
	for i in range(16):
		_points[i] = _DEFAULTS[i]
	super.destroy_control_node()
