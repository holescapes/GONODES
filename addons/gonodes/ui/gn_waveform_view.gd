class_name GNWaveformView
extends Control
## Custom drawing control that renders CHOP channel data as waveform lines.
##
## Uses Godot's GPU-accelerated _draw() system — no SubViewport needed.
## Supports multi-channel display with per-channel coloring, auto-scaling,
## grid lines, and channel name legends.

## The current channel data to visualize.
var channel_data: GNChannelData = null

## Per-channel colors (cycles through these if more channels than colors).
var channel_colors: Array[Color] = [
	Color(0.3, 1.0, 0.4),     # Green
	Color(0.3, 0.8, 1.0),     # Cyan
	Color(1.0, 0.9, 0.3),     # Yellow
	Color(1.0, 0.4, 0.7),     # Magenta
	Color(1.0, 0.5, 0.2),     # Orange
	Color(0.6, 0.5, 1.0),     # Lavender
	Color(0.2, 1.0, 0.8),     # Teal
	Color(1.0, 0.3, 0.3),     # Red
]

## Background color.
var bg_color: Color = Color(0.06, 0.06, 0.08, 1.0)

## Grid line color.
var grid_color: Color = Color(0.15, 0.15, 0.2, 1.0)

## Legend font size.
var legend_font_size: int = 11

## Line width for waveforms.
var line_width: float = 1.5

## Whether to show channel name legends.
var show_legend: bool = true

## Whether to show grid lines.
var show_grid: bool = true

## Padding in pixels around the waveform area.
var padding: float = 8.0

## Legend padding from top-left.
var legend_padding: float = 6.0


func _ready() -> void:
	# Redraw when the control resizes
	resized.connect(queue_redraw)


func _draw() -> void:
	# Background fill
	draw_rect(Rect2(Vector2.ZERO, size), bg_color)

	if channel_data == null or channel_data.channels.is_empty():
		# Draw placeholder text
		var font := ThemeDB.fallback_font
		if font != null:
			var text := "No CHOP data"
			var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
			var text_pos := (size - text_size) * 0.5 + Vector2(0, text_size.y)
			draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
				Color(0.4, 0.4, 0.4))
		return

	# Compute global min/max across all channels for unified Y scaling
	var global_min: float = INF
	var global_max: float = -INF
	var max_samples: int = 0
	for ch_name in channel_data.channels:
		var samples: PackedFloat32Array = channel_data.channels[ch_name]
		if samples.is_empty():
			continue
		for s in samples:
			if s < global_min:
				global_min = s
			if s > global_max:
				global_max = s
		if samples.size() > max_samples:
			max_samples = samples.size()

	# Guard against flat signals or empty data
	if max_samples == 0:
		return
	var y_range: float = global_max - global_min
	if y_range < 0.0001:
		y_range = 1.0
		global_min -= 0.5
		global_max += 0.5

	# Drawing area
	var draw_x: float = padding
	var draw_y: float = padding
	var draw_w: float = size.x - padding * 2.0
	var draw_h: float = size.y - padding * 2.0
	if draw_w <= 0.0 or draw_h <= 0.0:
		return

	# Grid lines
	if show_grid:
		_draw_grid(draw_x, draw_y, draw_w, draw_h, global_min, global_max, y_range)

	# Draw each channel
	var ch_index: int = 0
	var legend_y: float = draw_y + legend_padding + 12.0
	var font := ThemeDB.fallback_font

	for ch_name in channel_data.channels:
		var samples: PackedFloat32Array = channel_data.channels[ch_name]
		if samples.is_empty():
			ch_index += 1
			continue

		var color: Color = channel_colors[ch_index % channel_colors.size()]

		# Build polyline points
		var points := PackedVector2Array()
		points.resize(samples.size())
		for i in samples.size():
			var x: float = draw_x + (float(i) / maxf(samples.size() - 1, 1)) * draw_w
			var y: float = draw_y + draw_h - ((samples[i] - global_min) / y_range) * draw_h
			points[i] = Vector2(x, y)

		# For single-sample (scalar) channels, draw a horizontal line
		if points.size() == 1:
			var y_pos: float = points[0].y
			draw_line(Vector2(draw_x, y_pos), Vector2(draw_x + draw_w, y_pos),
				color, line_width, true)
		elif points.size() > 1:
			draw_polyline(points, color, line_width, true)

		# Legend
		if show_legend and font != null:
			var last_val: float = samples[samples.size() - 1]
			var legend_text := "%s: %.3f" % [ch_name, last_val]
			draw_string(font, Vector2(draw_x + legend_padding, legend_y),
				legend_text, HORIZONTAL_ALIGNMENT_LEFT, -1, legend_font_size, color)
			legend_y += legend_font_size + 3.0

		ch_index += 1


## Draws horizontal grid lines with value labels.
func _draw_grid(x: float, y: float, w: float, h: float,
		y_min: float, y_max: float, y_range: float) -> void:
	var font := ThemeDB.fallback_font
	var grid_lines: int = 4  # Number of horizontal divisions
	for i in range(grid_lines + 1):
		var frac: float = float(i) / float(grid_lines)
		var gy: float = y + frac * h
		draw_line(Vector2(x, gy), Vector2(x + w, gy), grid_color, 1.0)

		# Value label on right side
		if font != null:
			var val: float = y_max - frac * y_range
			var label := "%.2f" % val
			var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
			draw_string(font, Vector2(x + w - label_size.x - 2, gy - 2),
				label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, grid_color.lightened(0.3))

	# Zero line (if in range)
	if y_min < 0.0 and y_max > 0.0:
		var zero_y: float = y + h - ((0.0 - y_min) / y_range) * h
		draw_line(Vector2(x, zero_y), Vector2(x + w, zero_y),
			Color(0.3, 0.3, 0.4, 0.6), 1.0)


## Updates the channel data and triggers a redraw.
func set_channel_data(data: GNChannelData) -> void:
	channel_data = data
	queue_redraw()
