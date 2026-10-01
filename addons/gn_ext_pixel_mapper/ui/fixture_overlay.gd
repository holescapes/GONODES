class_name FixtureOverlay
extends GNInteractivePanel
## Interactive overlay for FixtureSamplerTOP.
## Draws fixture handles, LED dots, and labels in normalized UV space.

const HANDLE_RADIUS := 6.0
const LED_DOT_RADIUS := 2.5
const HANDLE_COLOR := Color(1.0, 0.35, 0.15, 0.9)
const HANDLE_HOVER_COLOR := Color(1.0, 0.7, 0.2, 0.95)
const HANDLE_ACTIVE_COLOR := Color(1.0, 1.0, 0.3, 1.0)
const WIRE_WIDTH := 1.5
const LABEL_COLOR := Color(1.0, 1.0, 1.0, 0.85)
const LABEL_BG := Color(0.0, 0.0, 0.0, 0.6)

const FIXTURE_COLORS: Array[Color] = [
	Color(0.0, 0.9, 0.9, 0.7),
	Color(0.9, 0.2, 0.8, 0.7),
	Color(0.95, 0.9, 0.1, 0.7),
	Color(0.2, 0.9, 0.3, 0.7),
	Color(0.3, 0.5, 1.0, 0.7),
	Color(1.0, 0.5, 0.2, 0.7),
]

## Each entry: shape, name, handles, leds, color_index, cols, rows.
var fixtures: Array[Dictionary] = []

var hovered: Vector2i = Vector2i(-1, -1)
var active: Vector2i = Vector2i(-1, -1)
var _dragging: Vector2i = Vector2i(-1, -1)

var fixture_tooltip: String = ""
var tooltip_pos: Vector2 = Vector2.ZERO

signal handle_moved(fixture_idx: int, handle_idx: int, uv: Vector2)


func handle_pointer(uv: Vector2, event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var hit: Vector2i = hit_test_uv(uv, grab_radius_uv)
				if hit.x >= 0:
					_dragging = hit
					active = hit
					queue_redraw()
					return true
			elif _dragging.x >= 0:
				_dragging = Vector2i(-1, -1)
				active = Vector2i(-1, -1)
				queue_redraw()
				return true

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _dragging.x >= 0:
			if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
				_dragging = Vector2i(-1, -1)
				active = Vector2i(-1, -1)
				queue_redraw()
				return true
			handle_moved.emit(_dragging.x, _dragging.y, uv)
			queue_redraw()
			_emit_interaction_changed()
			return true
		var hit: Vector2i = hit_test_uv(uv, grab_radius_uv)
		if hit != hovered:
			hovered = hit
			if hit.x >= 0 and hit.x < fixtures.size():
				var fix: Dictionary = fixtures[hit.x]
				fixture_tooltip = fix.get("name", "")
				tooltip_pos = uv_to_px(uv)
			else:
				fixture_tooltip = ""
			queue_redraw()
			return hit.x >= 0

	return false


func _draw() -> void:
	for fi in range(fixtures.size()):
		var fix: Dictionary = fixtures[fi]
		var col: Color = FIXTURE_COLORS[fix.get("color_index", fi) % FIXTURE_COLORS.size()]
		var handles: PackedVector2Array = fix.get("handles", PackedVector2Array())
		var leds: PackedVector2Array = fix.get("leds", PackedVector2Array())
		var shape: StringName = fix.get("shape", &"custom")

		if shape == &"strip" and handles.size() >= 2:
			draw_line(uv_to_px(handles[0]), uv_to_px(handles[1]), col, WIRE_WIDTH, true)
		elif (shape == &"grid" or shape == &"matrix") and handles.size() >= 4:
			_draw_rect_wireframe(handles, col)

		for led_uv in leds:
			draw_circle(uv_to_px(led_uv), LED_DOT_RADIUS, col)

		for hi in range(handles.size()):
			var px := uv_to_px(handles[hi])
			var hcol: Color
			if Vector2i(fi, hi) == active:
				hcol = HANDLE_ACTIVE_COLOR
			elif Vector2i(fi, hi) == hovered:
				hcol = HANDLE_HOVER_COLOR
			else:
				hcol = HANDLE_COLOR
			draw_circle(px, HANDLE_RADIUS, hcol)
			draw_arc(px, HANDLE_RADIUS, 0, TAU, 24, Color(1, 1, 1, 0.6), 1.0, true)

		if handles.size() > 0:
			var label_px := uv_to_px(handles[0]) + Vector2(10, -10)
			var fix_name: String = fix.get("name", "")
			if not fix_name.is_empty():
				var font: Font = ThemeDB.fallback_font
				var fs: int = 12
				var tw: float = font.get_string_size(fix_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_rect(Rect2(label_px + Vector2(-2, -fs), Vector2(tw + 4, fs + 4)), LABEL_BG)
				draw_string(font, label_px, fix_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

	if not fixture_tooltip.is_empty():
		var font: Font = ThemeDB.fallback_font
		var fs: int = 12
		var tw: float = font.get_string_size(fixture_tooltip, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tp := tooltip_pos + Vector2(14, 0)
		draw_rect(Rect2(tp + Vector2(-2, -fs), Vector2(tw + 4, fs + 4)), LABEL_BG)
		draw_string(font, tp, fixture_tooltip, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, LABEL_COLOR)


func _draw_rect_wireframe(corners: PackedVector2Array, col: Color) -> void:
	var order := [0, 1, 3, 2]
	for i in range(4):
		draw_line(uv_to_px(corners[order[i]]), uv_to_px(corners[order[(i + 1) % 4]]),
			col, WIRE_WIDTH, true)


func hit_test_uv(uv: Vector2, radius_uv: float) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist: float = radius_uv
	for fi in range(fixtures.size()):
		var handles: PackedVector2Array = fixtures[fi].get("handles", PackedVector2Array())
		for hi in range(handles.size()):
			var d: float = uv.distance_to(handles[hi])
			if d < best_dist:
				best_dist = d
				best = Vector2i(fi, hi)
	return best
