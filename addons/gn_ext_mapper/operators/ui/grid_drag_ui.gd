class_name GridDragUI
extends GNUiBase
## Interactive NxM grid drag pad.  Outputs per-point offsets as CHOP channels
## (pt_X_Y_x, pt_X_Y_y) — wire directly into GridWarpTOP parameters.

var _pad: Control = null
var _points: PackedVector2Array = PackedVector2Array()
var _cols: int = 4
var _rows: int = 4
var _dragging: int = -1

const HANDLE_RADIUS := 5.0
const GRAB_RADIUS := 10.0


func _init() -> void:
	node_type = "grid_drag"


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("label", "Grid Drag", "Label", "Display label"))
	add_parameter(GNParameter.create_int("size", 200, 64, 512, "Size", "Pad size in pixels"))
	add_parameter(GNParameter.create_int("grid_cols", 4, 2, 8, "Grid Cols", "Columns"))
	add_parameter(GNParameter.create_int("grid_rows", 4, 2, 8, "Grid Rows", "Rows"))
	add_parameter(GNParameter.create_bool("fill_parent", false, "Fill Parent", "Expand to fill parent — enables aligned overlay in WindowOUT"))
	add_parameter(GNParameter.create_color("bg_color", Color(0.12, 0.12, 0.15), "Background", "Pad background"))
	add_parameter(GNParameter.create_color("handle_color", Color(1.0, 0.35, 0.15), "Handle Color", "Point handle color"))
	add_parameter(GNParameter.create_color("wire_color", Color(0.6, 0.85, 1.0, 0.5), "Wire Color", "Grid wireframe"))


func _cook(_inputs: Array[GNData]) -> GNData:
	_ensure_pad()

	var new_cols: int = get_param_value("grid_cols")
	var new_rows: int = get_param_value("grid_rows")
	if new_cols != _cols or new_rows != _rows:
		_rebuild_points(new_cols, new_rows)

	var sz: int = get_param_value("size")
	var fill: bool = get_param_value("fill_parent")
	if fill:
		_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_pad.custom_minimum_size = Vector2.ZERO
	else:
		_pad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_pad.size_flags_vertical = Control.SIZE_FILL
		_pad.custom_minimum_size = Vector2(sz, sz + 18)
	_pad.queue_redraw()

	# Build widget_state — offset from base grid position
	widget_state = {}
	for y in range(_rows):
		for x in range(_cols):
			var idx: int = y * _cols + x
			var base_u: float = float(x) / float(_cols - 1)
			var base_v: float = float(y) / float(_rows - 1)
			var offset_x: float = _points[idx].x - base_u
			var offset_y: float = _points[idx].y - base_v
			var key := "pt_%d_%d" % [x, y]
			widget_state[key + "_x"] = offset_x
			widget_state[key + "_y"] = offset_y

	return null


func _ensure_pad() -> void:
	if _pad != null:
		return
	_pad = Control.new()
	_pad.name = id + "_griddrag"
	_pad.gui_input.connect(_on_pad_input)
	_pad.draw.connect(_on_pad_draw)
	_control_node = _pad
	_rebuild_points(get_param_value("grid_cols"), get_param_value("grid_rows"))
	# Restore point offsets from saved widget_state
	for y in range(_rows):
		for x in range(_cols):
			var key := "pt_%d_%d" % [x, y]
			if widget_state.has(key + "_x"):
				var base_u: float = float(x) / float(_cols - 1)
				var base_v: float = float(y) / float(_rows - 1)
				_points[y * _cols + x] = Vector2(
					base_u + widget_state[key + "_x"],
					base_v + widget_state[key + "_y"])


func _rebuild_points(cols: int, rows: int) -> void:
	_cols = cols
	_rows = rows
	_points.resize(cols * rows)
	for y in range(rows):
		for x in range(cols):
			_points[y * cols + x] = Vector2(
				float(x) / float(cols - 1),
				float(y) / float(rows - 1))
	_dragging = -1


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
		_points[_dragging] = Vector2(
			clampf(pos.x / area.x, -0.2, 1.2),
			clampf(pos.y / area.y, -0.2, 1.2))
		_pad.queue_redraw()
		mark_dirty()


func _hit_test(pos: Vector2, area: Vector2) -> int:
	var best := -1
	var best_dist := GRAB_RADIUS
	for i in range(_points.size()):
		var px := Vector2(_points[i].x * area.x, _points[i].y * area.y)
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

	_pad.draw_rect(Rect2(Vector2.ZERO, area), bg)
	if not fill:
		_pad.draw_rect(Rect2(Vector2.ZERO, area), Color(0.3, 0.3, 0.35), false, 1.0)

	# Grid wireframe
	for row in range(_rows):
		for col in range(_cols - 1):
			var a: int = row * _cols + col
			var b: int = row * _cols + col + 1
			_pad.draw_line(
				Vector2(_points[a].x * area.x, _points[a].y * area.y),
				Vector2(_points[b].x * area.x, _points[b].y * area.y),
				wc, 1.0, true)
	for col in range(_cols):
		for row in range(_rows - 1):
			var a: int = row * _cols + col
			var b: int = (row + 1) * _cols + col
			_pad.draw_line(
				Vector2(_points[a].x * area.x, _points[a].y * area.y),
				Vector2(_points[b].x * area.x, _points[b].y * area.y),
				wc, 1.0, true)

	# Handles
	for i in range(_points.size()):
		var px := Vector2(_points[i].x * area.x, _points[i].y * area.y)
		var color := hc.lightened(0.3) if i == _dragging else hc
		_pad.draw_circle(px, HANDLE_RADIUS, color)
		_pad.draw_arc(px, HANDLE_RADIUS, 0, TAU, 24, Color(1, 1, 1, 0.4), 1.0, true)

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
	_rebuild_points(4, 4)
	super.destroy_control_node()
