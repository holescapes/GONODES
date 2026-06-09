class_name FixtureViewerOverlay
extends Control
## Transparent overlay drawn on top of the FIX node's LED layout image.
## Shows per-LED DMX info on mouse hover.

var fixture_data: GNFixtureData = null
var bb_min: Vector2 = Vector2.ZERO
var bb_scale: float = 1.0
var img_size: int = 256

## Current mouse UV in the texture (0-1).
var mouse_uv: Vector2 = Vector2(-1, -1)

const HOVER_RADIUS_UV := 0.04
const TOOLTIP_BG := Color(0.0, 0.0, 0.0, 0.85)
const TOOLTIP_TEXT_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const HIGHLIGHT_COLOR := Color(1.0, 1.0, 0.3, 0.9)


func _draw() -> void:
	if fixture_data == null or fixture_data.led_count == 0:
		return
	if mouse_uv.x < 0:
		return

	# Find nearest LED to mouse position
	# Convert mouse UV (0-1 in the rendered image) to the same space as LED positions
	var mouse_local := Vector2(
		mouse_uv.x * float(img_size) / bb_scale + bb_min.x,
		mouse_uv.y * float(img_size) / bb_scale + bb_min.y
	)

	var best_idx: int = -1
	var best_dist: float = INF
	for i in range(fixture_data.led_count):
		var d: float = mouse_local.distance_to(fixture_data.led_positions[i])
		if d < best_dist:
			best_dist = d
			best_idx = i

	# Check if close enough (scale threshold by view zoom)
	var threshold: float = HOVER_RADIUS_UV * float(img_size) / bb_scale
	if best_idx < 0 or best_dist > threshold:
		return

	# Draw highlight circle on the hovered LED
	var led_px := _local_to_px(fixture_data.led_positions[best_idx])
	draw_arc(led_px, 8.0, 0, TAU, 24, HIGHLIGHT_COLOR, 2.0, true)

	# Compute DMX address for this LED
	var cpl: int = fixture_data.channels_per_led
	var led_ch_offset: int = best_idx * cpl
	var abs_start: int = fixture_data.start_channel + led_ch_offset
	# Channel might span universes
	var uni: int = fixture_data.universe + (abs_start - 1) / 512
	var ch_in_uni: int = ((abs_start - 1) % 512) + 1
	var ch_end: int = ch_in_uni + cpl - 1

	# Build tooltip text
	var lines: PackedStringArray = PackedStringArray()
	lines.append("LED %d" % best_idx)
	lines.append("Uni %d  Ch %d-%d" % [uni, ch_in_uni, ch_end])
	lines.append("%s" % fixture_data.channel_layout.to_upper())

	# Draw tooltip background + text
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 13
	var line_h: float = font.get_height(font_size) + 2
	var max_w: float = 0
	for line in lines:
		max_w = maxf(max_w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var padding := Vector2(8, 4)
	var tooltip_size := Vector2(max_w + padding.x * 2, lines.size() * line_h + padding.y * 2)
	var tooltip_pos := led_px + Vector2(12, -tooltip_size.y * 0.5)
	# Keep on screen
	if tooltip_pos.x + tooltip_size.x > size.x:
		tooltip_pos.x = led_px.x - tooltip_size.x - 12
	tooltip_pos.y = clampf(tooltip_pos.y, 0, size.y - tooltip_size.y)

	draw_rect(Rect2(tooltip_pos, tooltip_size), TOOLTIP_BG)
	for i in range(lines.size()):
		draw_string(font, tooltip_pos + Vector2(padding.x, padding.y + line_h * (i + 0.8)),
			lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TOOLTIP_TEXT_COLOR)


func _local_to_px(local_pos: Vector2) -> Vector2:
	var nx: float = (local_pos.x - bb_min.x) * bb_scale / float(img_size)
	var ny: float = (local_pos.y - bb_min.y) * bb_scale / float(img_size)
	return Vector2(nx * size.x, ny * size.y)
