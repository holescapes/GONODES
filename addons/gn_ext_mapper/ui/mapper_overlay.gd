class_name MapperOverlay
extends GNInteractivePanel
## Shared interactive overlay for projection mapping TOPs.
## Draws control point handles + wireframe in normalized UV space.

const HANDLE_RADIUS := 6.0
const HANDLE_COLOR := Color(1.0, 0.35, 0.15, 0.9)
const HANDLE_HOVER_COLOR := Color(1.0, 0.7, 0.2, 0.95)
const HANDLE_ACTIVE_COLOR := Color(1.0, 1.0, 0.3, 1.0)
const WIRE_COLOR := Color(0.6, 0.85, 1.0, 0.5)
const WIRE_WIDTH := 1.5

## Points in normalized UV space (0-1). Synced from owning TOP parameters.
var points: PackedVector2Array = PackedVector2Array()

var hovered_index: int = -1
var active_index: int = -1
var _dragging_index: int = -1

## Optional edge connections for wireframe drawing — each [from_idx, to_idx].
var edges: Array[Vector2i] = []

var draw_quad_outline: bool = false
var grid_cols: int = 0
var grid_rows: int = 0


func handle_pointer(uv: Vector2, event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var hit := hit_test_uv(uv, grab_radius_uv)
				if hit >= 0:
					_dragging_index = hit
					active_index = hit
					queue_redraw()
					return true
			elif _dragging_index >= 0:
				_dragging_index = -1
				active_index = -1
				queue_redraw()
				return true

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _dragging_index >= 0:
			if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
				_dragging_index = -1
				active_index = -1
				queue_redraw()
				return true
			if _dragging_index < points.size():
				points[_dragging_index] = uv
			queue_redraw()
			_emit_interaction_changed()
			return true
		var hit := hit_test_uv(uv, grab_radius_uv)
		if hit != hovered_index:
			hovered_index = hit
			queue_redraw()
			return hit >= 0

	return false


func _draw() -> void:
	if points.is_empty():
		return

	if draw_quad_outline and points.size() >= 4:
		_draw_quad_wireframe()
	elif grid_cols > 0 and grid_rows > 0:
		_draw_grid_wireframe()
	else:
		for edge in edges:
			if edge.x < points.size() and edge.y < points.size():
				draw_line(uv_to_px(points[edge.x]), uv_to_px(points[edge.y]),
					WIRE_COLOR, WIRE_WIDTH, true)

	for i in range(points.size()):
		var px := uv_to_px(points[i])
		var color: Color
		if i == active_index:
			color = HANDLE_ACTIVE_COLOR
		elif i == hovered_index:
			color = HANDLE_HOVER_COLOR
		else:
			color = HANDLE_COLOR
		draw_circle(px, HANDLE_RADIUS, color)
		draw_arc(px, HANDLE_RADIUS, 0, TAU, 24, Color(1, 1, 1, 0.6), 1.0, true)


func _draw_quad_wireframe() -> void:
	var order := [0, 1, 3, 2]
	for i in range(4):
		var a := uv_to_px(points[order[i]])
		var b := uv_to_px(points[order[(i + 1) % 4]])
		draw_line(a, b, WIRE_COLOR, WIRE_WIDTH, true)


func _draw_grid_wireframe() -> void:
	for row in range(grid_rows):
		for col in range(grid_cols - 1):
			var idx_a: int = row * grid_cols + col
			var idx_b: int = row * grid_cols + col + 1
			if idx_a < points.size() and idx_b < points.size():
				draw_line(uv_to_px(points[idx_a]), uv_to_px(points[idx_b]),
					WIRE_COLOR, WIRE_WIDTH, true)
	for col in range(grid_cols):
		for row in range(grid_rows - 1):
			var idx_a: int = row * grid_cols + col
			var idx_b: int = (row + 1) * grid_cols + col
			if idx_a < points.size() and idx_b < points.size():
				draw_line(uv_to_px(points[idx_a]), uv_to_px(points[idx_b]),
					WIRE_COLOR, WIRE_WIDTH, true)


func hit_test_uv(uv: Vector2, radius_uv: float) -> int:
	var best_idx := -1
	var best_dist := radius_uv
	for i in range(points.size()):
		var d: float = uv.distance_to(points[i])
		if d < best_dist:
			best_dist = d
			best_idx = i
	return best_idx
