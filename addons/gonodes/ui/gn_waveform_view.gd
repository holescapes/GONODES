class_name GNWaveformView
extends Control
## Custom drawing control that renders CHOP channel data as waveform lines.
##
## Uses Godot's GPU-accelerated _draw() system — no SubViewport needed.
## Supports multi-channel display with per-channel coloring, fixed-scale grid,
## and user-controllable Y/X zoom + pan.
##
## Grid units stay static; the data is plotted within the user's chosen range.
## Scroll wheel zooms Y-axis, Shift+scroll zooms X-axis (time).
## Left-click or middle-click drag to pan.

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

# ─── View state (user-controlled zoom/pan) ────────────────────────────────────

## The visible Y-axis center value (world units).
var _y_center: float = 0.0

## The visible Y-axis half-range (world units). Shows _y_center ± _y_half_range.
var _y_half_range: float = 1.0

## The visible X-axis start sample index (fractional for smooth panning).
var _x_offset: float = 0.0

## The visible X-axis range in samples.  0 = show all samples.
var _x_range: float = 0.0

## Whether the view range has been initialised for the current target node.
var _range_initialised: bool = false

## Whether a pan drag is in progress.
var _dragging: bool = false

## Zoom speed multipliers.
const Y_ZOOM_FACTOR := 0.15
const X_ZOOM_FACTOR := 0.15
const ZOOM_MIN_HALF_RANGE := 0.0001
const ZOOM_MAX_HALF_RANGE := 1e9


func _ready() -> void:
	resized.connect(queue_redraw)


## Resets the view range for a new target node (called by GNViewerPanel.set_target).
func reset_view() -> void:
	_range_initialised = false
	_dragging = false


# ═══════════════════════════════════════════════════════════════════════════════
# Input — zoom and pan
# ═══════════════════════════════════════════════════════════════════════════════

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		# Y zoom — scroll (no modifier)
		if not mb.shift_pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
				_y_half_range = maxf(_y_half_range * (1.0 - Y_ZOOM_FACTOR), ZOOM_MIN_HALF_RANGE)
				queue_redraw()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
				_y_half_range = minf(_y_half_range * (1.0 + Y_ZOOM_FACTOR), ZOOM_MAX_HALF_RANGE)
				queue_redraw()
		# X zoom — Shift + scroll
		if mb.shift_pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
				_x_range = maxf(_x_range * (1.0 - X_ZOOM_FACTOR), 2.0)
				queue_redraw()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
				var max_samples := _get_max_samples()
				_x_range = minf(_x_range * (1.0 + X_ZOOM_FACTOR), max_samples)
				queue_redraw()
		# Pan start/stop — left or middle click
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed

	elif event is InputEventMouseMotion and _dragging:
		var mm: InputEventMouseMotion = event
		var draw_h: float = size.y - padding * 2.0
		var draw_w: float = size.x - padding * 2.0
		if draw_h > 0.0:
			# Vertical drag: convert pixel delta to world units
			var y_per_pixel: float = (_y_half_range * 2.0) / draw_h
			_y_center += mm.relative.y * y_per_pixel  # drag up = increase center
		if draw_w > 0.0 and _x_range > 0.0:
			# Horizontal drag: convert pixel delta to sample units
			var samples_per_pixel: float = _x_range / draw_w
			_x_offset -= mm.relative.x * samples_per_pixel
			_x_offset = maxf(_x_offset, 0.0)
		queue_redraw()


func _get_max_samples() -> int:
	if channel_data == null:
		return 0
	var mx: int = 0
	for ch_name in channel_data.channels:
		var s: PackedFloat32Array = channel_data.channels[ch_name]
		if s.size() > mx:
			mx = s.size()
	return mx


# ═══════════════════════════════════════════════════════════════════════════════
# Drawing
# ═══════════════════════════════════════════════════════════════════════════════

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), bg_color)

	if channel_data == null or channel_data.channels.is_empty():
		var font := ThemeDB.fallback_font
		if font != null:
			var text := "No CHOP data"
			var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
			var text_pos := (size - text_size) * 0.5 + Vector2(0, text_size.y)
			draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
				Color(0.4, 0.4, 0.4))
		return

	# Initialise view range on first data
	if not _range_initialised:
		_initialise_range()

	# Visible Y bounds (world units)
	var y_min: float = _y_center - _y_half_range
	var y_max: float = _y_center + _y_half_range
	var y_range: float = _y_half_range * 2.0

	# Visible X bounds (sample indices)
	var max_samples := _get_max_samples()
	var x_start: float = _x_offset
	var x_end: float = _x_offset + (_x_range if _x_range > 0.0 else float(max_samples - 1))

	# Drawing area
	var draw_x: float = padding
	var draw_y: float = padding
	var draw_w: float = size.x - padding * 2.0
	var draw_h: float = size.y - padding * 2.0
	if draw_w <= 0.0 or draw_h <= 0.0:
		return

	# Grid lines (fixed to current view range)
	if show_grid:
		_draw_grid(draw_x, draw_y, draw_w, draw_h, y_min, y_max, y_range)
		_draw_x_grid(draw_x, draw_y, draw_w, draw_h, x_start, x_end)

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
		var x_span: float = x_end - x_start
		if x_span < 0.001:
			x_span = 1.0

		# Build polyline points — only samples in visible range
		var points := PackedVector2Array()
		var i_start := int(maxf(floorf(x_start), 0.0))
		var i_end := int(minf(ceilf(x_end), float(samples.size() - 1)))

		for i in range(i_start, i_end + 1):
			var x: float = draw_x + ((float(i) - x_start) / x_span) * draw_w
			var y: float = draw_y + draw_h - ((samples[i] - y_min) / y_range) * draw_h
			points.append(Vector2(x, y))

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


## Compute a "nice" initial range from the data and lock it.
func _initialise_range() -> void:
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

	if max_samples == 0:
		_y_center = 0.0
		_y_half_range = 1.0
		_x_range = 0.0
		_range_initialised = true
		return

	# Compute nice Y range — add 10% headroom
	var data_range: float = global_max - global_min
	if data_range < 0.0001:
		data_range = 1.0
	var headroom: float = data_range * 0.1
	_y_center = (global_min + global_max) * 0.5
	_y_half_range = (data_range + headroom * 2.0) * 0.5

	# Snap to a "nice" number for clean grid labels
	_y_half_range = _snap_to_nice(_y_half_range)

	# X: show all samples by default
	_x_offset = 0.0
	_x_range = 0.0  # 0 means "show all"

	_range_initialised = true


## Rounds a value up to a "nice" number (1, 2, 5 × 10^n) for clean grid labels.
func _snap_to_nice(value: float) -> float:
	if value <= 0.0:
		return 1.0
	var exponent := floorf(log(value) / log(10.0))
	var fraction := value / pow(10.0, exponent)
	var nice: float
	if fraction <= 1.0:
		nice = 1.0
	elif fraction <= 2.0:
		nice = 2.0
	elif fraction <= 5.0:
		nice = 5.0
	else:
		nice = 10.0
	return nice * pow(10.0, exponent)


## Draws horizontal grid lines with static value labels based on the current view range.
func _draw_grid(x: float, y: float, w: float, h: float,
		y_min: float, y_max: float, y_range: float) -> void:
	var font := ThemeDB.fallback_font

	# Pick a nice grid spacing based on the current Y range
	var raw_step := y_range / 5.0  # Aim for ~5 grid lines
	var step := _snap_to_nice(raw_step)
	if step <= 0.0:
		step = 1.0

	# First grid value at or above y_min, snapped to step
	var first_val := ceilf(y_min / step) * step

	var val := first_val
	while val <= y_max:
		var frac: float = (val - y_min) / y_range
		var gy: float = y + h - frac * h  # bottom = y_min, top = y_max

		# Grid line
		var line_color := grid_color
		if absf(val) < step * 0.01:
			line_color = Color(0.3, 0.3, 0.4, 0.6)  # Highlight zero line
		draw_line(Vector2(x, gy), Vector2(x + w, gy), line_color, 1.0)

		# Value label on right side
		if font != null:
			var label := _format_value(val)
			var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
			draw_string(font, Vector2(x + w - label_size.x - 2, gy - 2),
				label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, grid_color.lightened(0.3))

		val += step


## Formats a grid value label — avoids noise like "0.00" for zero.
func _format_value(val: float) -> String:
	if absf(val) < 1e-10:
		return "0"
	if absf(val) >= 1000.0:
		return "%.0f" % val
	if absf(val) >= 1.0:
		return "%.1f" % val
	return "%.3f" % val


## Draws vertical grid lines with sample index labels along the X axis.
func _draw_x_grid(x: float, y: float, w: float, h: float,
		x_start: float, x_end: float) -> void:
	var font := ThemeDB.fallback_font
	var x_span: float = x_end - x_start
	if x_span < 1.0:
		return

	var raw_step := x_span / 6.0
	var step := _snap_to_nice(raw_step)
	if step < 1.0:
		step = 1.0

	var first_val := ceilf(x_start / step) * step
	var val := first_val
	while val <= x_end:
		var frac: float = (val - x_start) / x_span
		var gx: float = x + frac * w
		draw_line(Vector2(gx, y), Vector2(gx, y + h), grid_color, 1.0)
		if font != null:
			var label := "%d" % int(val)
			draw_string(font, Vector2(gx + 2, y + h - 2),
				label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, grid_color.lightened(0.3))
		val += step


## Updates the channel data and triggers a redraw.
## Does NOT reset view range — preserves user's zoom/pan.
func set_channel_data(data: GNChannelData) -> void:
	channel_data = data
	queue_redraw()
