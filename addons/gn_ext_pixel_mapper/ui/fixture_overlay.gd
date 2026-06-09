class_name FixtureOverlay
extends Control
## Interactive overlay for FixtureSamplerTOP.
## Draws fixture handles on top of the source texture in the viewer panel.
## Supports strip (2 endpoints), grid/matrix (4 corners), and custom (group translate).
##
## Coordinate space: all positions are in UV (0-1) mapped to this Control's size.

const HANDLE_RADIUS := 6.0
const LED_DOT_RADIUS := 2.5
const HANDLE_COLOR := Color(1.0, 0.35, 0.15, 0.9)
const HANDLE_HOVER_COLOR := Color(1.0, 0.7, 0.2, 0.95)
const HANDLE_ACTIVE_COLOR := Color(1.0, 1.0, 0.3, 1.0)
const WIRE_WIDTH := 1.5
const LABEL_COLOR := Color(1.0, 1.0, 1.0, 0.85)
const LABEL_BG := Color(0.0, 0.0, 0.0, 0.6)

## Per-fixture colour palette for visual distinction.
const FIXTURE_COLORS: Array[Color] = [
	Color(0.0, 0.9, 0.9, 0.7),   # cyan
	Color(0.9, 0.2, 0.8, 0.7),   # magenta
	Color(0.95, 0.9, 0.1, 0.7),  # yellow
	Color(0.2, 0.9, 0.3, 0.7),   # green
	Color(0.3, 0.5, 1.0, 0.7),   # blue
	Color(1.0, 0.5, 0.2, 0.7),   # orange
]

## Array of fixture draw entries, each is a Dictionary:
##   shape: StringName ("strip", "grid", "matrix", "custom")
##   name: String
##   handles: PackedVector2Array (UV positions of control handles)
##   leds: PackedVector2Array (final UV positions of all LEDs)
##   color_index: int
##   cols: int (for grid/matrix wireframe)
##   rows: int (for grid/matrix wireframe)
var fixtures: Array[Dictionary] = []

## Currently hovered handle: [fixture_idx, handle_idx] or [-1, -1].
var hovered: Vector2i = Vector2i(-1, -1)

## Currently dragged handle: [fixture_idx, handle_idx] or [-1, -1].
var active: Vector2i = Vector2i(-1, -1)

## Tooltip text (shown near mouse on hover). Named fixture_tooltip to avoid shadowing Control.tooltip_text.
var fixture_tooltip: String = ""
var tooltip_pos: Vector2 = Vector2.ZERO


func _draw() -> void:
	for fi in range(fixtures.size()):
		var fix: Dictionary = fixtures[fi]
		var col: Color = FIXTURE_COLORS[fix.get("color_index", fi) % FIXTURE_COLORS.size()]
		var handles: PackedVector2Array = fix.get("handles", PackedVector2Array())
		var leds: PackedVector2Array = fix.get("leds", PackedVector2Array())
		var shape: StringName = fix.get("shape", &"custom")

		# Draw wireframe
		if shape == &"strip" and handles.size() >= 2:
			draw_line(_uv_to_px(handles[0]), _uv_to_px(handles[1]), col, WIRE_WIDTH, true)
		elif (shape == &"grid" or shape == &"matrix") and handles.size() >= 4:
			_draw_rect_wireframe(handles, col)

		# Draw LED dots
		for led_uv in leds:
			draw_circle(_uv_to_px(led_uv), LED_DOT_RADIUS, col)

		# Draw handles
		for hi in range(handles.size()):
			var px := _uv_to_px(handles[hi])
			var hcol: Color
			if Vector2i(fi, hi) == active:
				hcol = HANDLE_ACTIVE_COLOR
			elif Vector2i(fi, hi) == hovered:
				hcol = HANDLE_HOVER_COLOR
			else:
				hcol = HANDLE_COLOR
			draw_circle(px, HANDLE_RADIUS, hcol)
			draw_arc(px, HANDLE_RADIUS, 0, TAU, 24, Color(1, 1, 1, 0.6), 1.0, true)

		# Draw fixture name label near first handle
		if handles.size() > 0:
			var label_px := _uv_to_px(handles[0]) + Vector2(10, -10)
			var fix_name: String = fix.get("name", "")
			if not fix_name.is_empty():
				var font: Font = ThemeDB.fallback_font
				var fs: int = 12
				var tw: float = font.get_string_size(fix_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_rect(Rect2(label_px + Vector2(-2, -fs), Vector2(tw + 4, fs + 4)), LABEL_BG)
				draw_string(font, label_px, fix_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

	# Draw tooltip
	if not fixture_tooltip.is_empty():
		var font: Font = ThemeDB.fallback_font
		var fs: int = 12
		var tw: float = font.get_string_size(fixture_tooltip, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tp := tooltip_pos + Vector2(14, 0)
		draw_rect(Rect2(tp + Vector2(-2, -fs), Vector2(tw + 4, fs + 4)), LABEL_BG)
		draw_string(font, tp, fixture_tooltip, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, LABEL_COLOR)


func _draw_rect_wireframe(corners: PackedVector2Array, col: Color) -> void:
	# TL, TR, BL, BR -> TL-TR, TR-BR, BR-BL, BL-TL
	var order := [0, 1, 3, 2]
	for i in range(4):
		draw_line(_uv_to_px(corners[order[i]]), _uv_to_px(corners[order[(i + 1) % 4]]),
			col, WIRE_WIDTH, true)


## Hit-tests all fixture handles. Returns Vector2i(fixture_idx, handle_idx)
## or Vector2i(-1, -1) if nothing hit.
func hit_test_uv(uv: Vector2, grab_radius_uv: float) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist: float = grab_radius_uv
	for fi in range(fixtures.size()):
		var handles: PackedVector2Array = fixtures[fi].get("handles", PackedVector2Array())
		for hi in range(handles.size()):
			var d: float = uv.distance_to(handles[hi])
			if d < best_dist:
				best_dist = d
				best = Vector2i(fi, hi)
	return best


## Converts normalized UV (0-1) to pixel position within this Control's rect.
func _uv_to_px(uv: Vector2) -> Vector2:
	return Vector2(uv.x * size.x, uv.y * size.y)
