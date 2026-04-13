class_name MapperOverlay
extends Control
## Shared overlay drawing for projection mapping TOPs.
## Draws control point handles + wireframe in texture pixel space.
## Owned by the TOP node, reparented into the viewer via set_texture_overlay().

const HANDLE_RADIUS := 6.0
const HANDLE_COLOR := Color(1.0, 0.35, 0.15, 0.9)
const HANDLE_HOVER_COLOR := Color(1.0, 0.7, 0.2, 0.95)
const HANDLE_ACTIVE_COLOR := Color(1.0, 1.0, 0.3, 1.0)
const WIRE_COLOR := Color(0.6, 0.85, 1.0, 0.5)
const WIRE_WIDTH := 1.5

## Points in normalized UV space (0-1). Updated by the owning TOP.
var points: PackedVector2Array = PackedVector2Array()

## Index of the currently hovered / dragged handle (-1 = none).
var hovered_index: int = -1
var active_index: int = -1

## Optional edge connections for wireframe drawing.
## Each entry is [from_idx, to_idx].
var edges: Array[Vector2i] = []

## If true, draw a closed quad outline connecting the first 4 points.
var draw_quad_outline: bool = false

## Grid dimensions for grid-mode wireframe (draws NxM grid lines).
var grid_cols: int = 0
var grid_rows: int = 0


func _draw() -> void:
	if points.is_empty():
		return

	# Draw edge wireframe
	if draw_quad_outline and points.size() >= 4:
		_draw_quad_wireframe()
	elif grid_cols > 0 and grid_rows > 0:
		_draw_grid_wireframe()
	else:
		for edge in edges:
			if edge.x < points.size() and edge.y < points.size():
				draw_line(_uv_to_px(points[edge.x]), _uv_to_px(points[edge.y]),
					WIRE_COLOR, WIRE_WIDTH, true)

	# Draw handles
	for i in range(points.size()):
		var px := _uv_to_px(points[i])
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
	var order := [0, 1, 3, 2]  # TL → TR → BR → BL
	for i in range(4):
		var a := _uv_to_px(points[order[i]])
		var b := _uv_to_px(points[order[(i + 1) % 4]])
		draw_line(a, b, WIRE_COLOR, WIRE_WIDTH, true)


func _draw_grid_wireframe() -> void:
	# Draw horizontal lines
	for row in range(grid_rows):
		for col in range(grid_cols - 1):
			var idx_a: int = row * grid_cols + col
			var idx_b: int = row * grid_cols + col + 1
			if idx_a < points.size() and idx_b < points.size():
				draw_line(_uv_to_px(points[idx_a]), _uv_to_px(points[idx_b]),
					WIRE_COLOR, WIRE_WIDTH, true)
	# Draw vertical lines
	for col in range(grid_cols):
		for row in range(grid_rows - 1):
			var idx_a: int = row * grid_cols + col
			var idx_b: int = (row + 1) * grid_cols + col
			if idx_a < points.size() and idx_b < points.size():
				draw_line(_uv_to_px(points[idx_a]), _uv_to_px(points[idx_b]),
					WIRE_COLOR, WIRE_WIDTH, true)


## Converts normalized UV (0-1) to pixel position within this Control's rect.
func _uv_to_px(uv: Vector2) -> Vector2:
	return Vector2(uv.x * size.x, uv.y * size.y)


## Returns the index of the point nearest to [param uv] if within grab radius,
## or -1 if nothing is close enough.
func hit_test_uv(uv: Vector2, grab_radius_uv: float) -> int:
	var best_idx := -1
	var best_dist := grab_radius_uv
	for i in range(points.size()):
		var d: float = uv.distance_to(points[i])
		if d < best_dist:
			best_dist = d
			best_idx = i
	return best_idx
