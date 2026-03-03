class_name GNRampEditor
extends Control
## Custom curve / ramp editor widget for the GONODES parameter inspector.
## Displays a visual curve with draggable keypoints, add/remove support,
## and tangent handles. Operates on an Array of keypoint Dictionaries:
##   [{"pos": float, "value": float, "left_tangent": float, "right_tangent": float}]
##
## Features:
##   - Left-click on empty area to add a keypoint
##   - Left-click + drag a point to move it
##   - Right-click a point to remove it (minimum 2 points)
##   - Ctrl+click a point to toggle between smooth and linear tangents
##   - Tangent handles visible on selected point (drag to adjust)
##   - Real-time curve preview via _draw()

## Emitted when keypoints change (user interaction).
signal ramp_changed(keys: Array)

## The keypoint data — Array of Dicts sorted by "pos".
var keys: Array = []

## Currently dragged point index (-1 = none).
var _drag_idx: int = -1

## Whether we're dragging a tangent handle instead of the point itself.
## 0 = point, -1 = left tangent, +1 = right tangent.
var _drag_tangent: int = 0

## Currently selected point index (-1 = none).
var _selected_idx: int = -1

## Visual constants
const _POINT_RADIUS := 5.0
const _TANGENT_HANDLE_RADIUS := 3.5
const _TANGENT_LINE_LENGTH := 40.0
const _GRID_COLOR := Color(0.2, 0.2, 0.2)
const _CURVE_COLOR := Color(0.8, 0.9, 1.0)
const _CURVE_WIDTH := 2.0
const _POINT_COLOR := Color(1.0, 1.0, 1.0)
const _SELECTED_POINT_COLOR := Color(0.3, 0.9, 0.6)
const _TANGENT_LINE_COLOR := Color(0.6, 0.6, 0.0, 0.7)
const _TANGENT_HANDLE_COLOR := Color(1.0, 0.9, 0.2)
const _BG_COLOR := Color(0.12, 0.12, 0.12)
const _FILL_COLOR := Color(0.2, 0.35, 0.55, 0.15)

## Padding in pixels around the drawing area.
const _PAD := 6.0


func _init() -> void:
	custom_minimum_size = Vector2(0, 100)
	mouse_filter = MOUSE_FILTER_STOP
	focus_mode = FOCUS_ALL


## Sets the keypoints and triggers a redraw.
func set_keys(p_keys: Array) -> void:
	keys = p_keys.duplicate(true)
	_sort_keys()
	_selected_idx = -1
	queue_redraw()


## Returns a deep copy of the current keypoints.
func get_keys() -> Array:
	return keys.duplicate(true)


# ═══════════════════════════════════════════════════════════════════════════════
# Coordinate Mapping
# ═══════════════════════════════════════════════════════════════════════════════

## Maps normalized (0..1, 0..1) ramp coordinates to pixel coordinates.
func _ramp_to_pixel(ramp_pos: float, ramp_val: float) -> Vector2:
	var draw_w := size.x - _PAD * 2.0
	var draw_h := size.y - _PAD * 2.0
	var px := _PAD + ramp_pos * draw_w
	var py := _PAD + (1.0 - ramp_val) * draw_h  # Y is inverted
	return Vector2(px, py)


## Maps pixel coordinates back to normalized ramp coordinates.
func _pixel_to_ramp(px: Vector2) -> Vector2:
	var draw_w := size.x - _PAD * 2.0
	var draw_h := size.y - _PAD * 2.0
	var rp := clampf((px.x - _PAD) / draw_w, 0.0, 1.0)
	var rv := clampf(1.0 - (px.y - _PAD) / draw_h, 0.0, 1.0)
	return Vector2(rp, rv)


# ═══════════════════════════════════════════════════════════════════════════════
# Drawing
# ═══════════════════════════════════════════════════════════════════════════════

func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, size), _BG_COLOR)

	# Grid lines (0.25 increments)
	for i in range(1, 4):
		var frac := float(i) / 4.0
		# Vertical
		var vx := _ramp_to_pixel(frac, 0.0).x
		draw_line(Vector2(vx, _PAD), Vector2(vx, size.y - _PAD), _GRID_COLOR, 1.0)
		# Horizontal
		var hy := _ramp_to_pixel(0.0, frac).y
		draw_line(Vector2(_PAD, hy), Vector2(size.x - _PAD, hy), _GRID_COLOR, 1.0)

	# Border
	draw_rect(Rect2(Vector2(_PAD, _PAD),
		Vector2(size.x - _PAD * 2.0, size.y - _PAD * 2.0)), _GRID_COLOR, false)

	if keys.is_empty():
		return

	# Draw filled area under curve
	var fill_points := PackedVector2Array()
	var curve_points := PackedVector2Array()
	var steps := int(size.x - _PAD * 2.0)
	if steps < 2:
		steps = 2
	for s in range(steps + 1):
		var t := float(s) / float(steps)
		var val := GNParameter.sample_ramp(keys, t)
		var pt := _ramp_to_pixel(t, val)
		curve_points.append(pt)
		fill_points.append(pt)

	# Close fill polygon along the bottom
	fill_points.append(_ramp_to_pixel(1.0, 0.0))
	fill_points.append(_ramp_to_pixel(0.0, 0.0))
	if fill_points.size() >= 3:
		draw_colored_polygon(fill_points, _FILL_COLOR)

	# Draw curve line
	if curve_points.size() >= 2:
		draw_polyline(curve_points, _CURVE_COLOR, _CURVE_WIDTH, true)

	# Draw keypoints
	for i in range(keys.size()):
		var k: Dictionary = keys[i]
		var pt := _ramp_to_pixel(float(k.get("pos", 0.0)), float(k.get("value", 0.0)))
		var col := _SELECTED_POINT_COLOR if i == _selected_idx else _POINT_COLOR
		draw_circle(pt, _POINT_RADIUS, col)
		draw_arc(pt, _POINT_RADIUS + 1.0, 0.0, TAU, 24, Color(0, 0, 0, 0.5), 1.0)

	# Draw tangent handles on selected point
	if _selected_idx >= 0 and _selected_idx < keys.size():
		_draw_tangent_handles(_selected_idx)


## Draws tangent handles for the given keypoint index.
func _draw_tangent_handles(idx: int) -> void:
	var k: Dictionary = keys[idx]
	var pt := _ramp_to_pixel(float(k.get("pos", 0.0)), float(k.get("value", 0.0)))

	var left_tan := float(k.get("left_tangent", 0.0))
	var right_tan := float(k.get("right_tangent", 0.0))

	# Left handle (extends to the left)
	if idx > 0:
		var lh_dir := Vector2(-1.0, left_tan).normalized()
		var lh_pt := pt + lh_dir * _TANGENT_LINE_LENGTH
		draw_line(pt, lh_pt, _TANGENT_LINE_COLOR, 1.0)
		draw_circle(lh_pt, _TANGENT_HANDLE_RADIUS, _TANGENT_HANDLE_COLOR)

	# Right handle (extends to the right)
	if idx < keys.size() - 1:
		var rh_dir := Vector2(1.0, -right_tan).normalized()
		var rh_pt := pt + rh_dir * _TANGENT_LINE_LENGTH
		draw_line(pt, rh_pt, _TANGENT_LINE_COLOR, 1.0)
		draw_circle(rh_pt, _TANGENT_HANDLE_RADIUS, _TANGENT_HANDLE_COLOR)


# ═══════════════════════════════════════════════════════════════════════════════
# Input Handling
# ═══════════════════════════════════════════════════════════════════════════════

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _drag_idx >= 0:
		_handle_mouse_motion(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	var mb := event as InputEventMouseButton

	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			# Check tangent handles first (if a point is selected)
			if _selected_idx >= 0:
				var tangent_hit := _hit_test_tangent(mb.position)
				if tangent_hit != 0:
					_drag_idx = _selected_idx
					_drag_tangent = tangent_hit
					accept_event()
					return

			# Check keypoints
			var hit := _hit_test_point(mb.position)
			if hit >= 0:
				_selected_idx = hit
				_drag_idx = hit
				_drag_tangent = 0

				# Ctrl+click toggles tangent smoothness
				if mb.ctrl_pressed:
					_toggle_tangent_mode(hit)
					_drag_idx = -1
			else:
				# Click on empty area — add a new keypoint
				var ramp_coord := _pixel_to_ramp(mb.position)
				_add_keypoint(ramp_coord.x, ramp_coord.y)
		else:
			# Release
			if _drag_idx >= 0:
				_drag_idx = -1
				_drag_tangent = 0
				_emit_changed()

		accept_event()
		queue_redraw()

	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		# Right-click removes a point (if hit, and at least 2 points remain)
		var hit := _hit_test_point(mb.position)
		if hit >= 0 and keys.size() > 2:
			keys.remove_at(hit)
			if _selected_idx == hit:
				_selected_idx = -1
			elif _selected_idx > hit:
				_selected_idx -= 1
			_emit_changed()
			queue_redraw()
		accept_event()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _drag_idx < 0 or _drag_idx >= keys.size():
		return

	var ramp_coord := _pixel_to_ramp(event.position)

	if _drag_tangent == 0:
		# Dragging the point itself
		var k: Dictionary = keys[_drag_idx]
		# Clamp position: don't cross neighbors
		var min_pos := 0.0
		var max_pos := 1.0
		if _drag_idx > 0:
			min_pos = float(keys[_drag_idx - 1].get("pos", 0.0)) + 0.001
		if _drag_idx < keys.size() - 1:
			max_pos = float(keys[_drag_idx + 1].get("pos", 1.0)) - 0.001
		k["pos"] = clampf(ramp_coord.x, min_pos, max_pos)
		k["value"] = clampf(ramp_coord.y, 0.0, 1.0)
	else:
		# Dragging a tangent handle
		var k: Dictionary = keys[_drag_idx]
		var pt := _ramp_to_pixel(float(k.get("pos", 0.0)), float(k.get("value", 0.0)))
		var delta := event.position - pt
		if _drag_tangent == -1:
			# Left tangent: direction is negative X
			if absf(delta.x) > 1.0:
				k["left_tangent"] = clampf(delta.y / delta.x, -10.0, 10.0)
		elif _drag_tangent == 1:
			# Right tangent: direction is positive X
			if absf(delta.x) > 1.0:
				k["right_tangent"] = clampf(-delta.y / delta.x, -10.0, 10.0)

	accept_event()
	queue_redraw()


# ═══════════════════════════════════════════════════════════════════════════════
# Hit Testing
# ═══════════════════════════════════════════════════════════════════════════════

## Returns the index of the keypoint at the given pixel position, or -1.
func _hit_test_point(pixel_pos: Vector2) -> int:
	var hit_radius := _POINT_RADIUS + 4.0
	for i in range(keys.size()):
		var k: Dictionary = keys[i]
		var pt := _ramp_to_pixel(float(k.get("pos", 0.0)), float(k.get("value", 0.0)))
		if pixel_pos.distance_to(pt) <= hit_radius:
			return i
	return -1


## Returns -1 for left tangent hit, +1 for right tangent hit, 0 for no hit.
func _hit_test_tangent(pixel_pos: Vector2) -> int:
	if _selected_idx < 0 or _selected_idx >= keys.size():
		return 0
	var k: Dictionary = keys[_selected_idx]
	var pt := _ramp_to_pixel(float(k.get("pos", 0.0)), float(k.get("value", 0.0)))
	var hit_radius := _TANGENT_HANDLE_RADIUS + 5.0

	# Left handle
	if _selected_idx > 0:
		var left_tan := float(k.get("left_tangent", 0.0))
		var lh_dir := Vector2(-1.0, left_tan).normalized()
		var lh_pt := pt + lh_dir * _TANGENT_LINE_LENGTH
		if pixel_pos.distance_to(lh_pt) <= hit_radius:
			return -1

	# Right handle
	if _selected_idx < keys.size() - 1:
		var right_tan := float(k.get("right_tangent", 0.0))
		var rh_dir := Vector2(1.0, -right_tan).normalized()
		var rh_pt := pt + rh_dir * _TANGENT_LINE_LENGTH
		if pixel_pos.distance_to(rh_pt) <= hit_radius:
			return 1

	return 0


# ═══════════════════════════════════════════════════════════════════════════════
# Key Manipulation
# ═══════════════════════════════════════════════════════════════════════════════

## Adds a keypoint at the given ramp position/value.
func _add_keypoint(pos: float, val: float) -> void:
	pos = clampf(pos, 0.0, 1.0)
	val = clampf(val, 0.0, 1.0)
	var new_key := {
		"pos": pos,
		"value": val,
		"left_tangent": 0.0,
		"right_tangent": 0.0,
	}
	keys.append(new_key)
	_sort_keys()
	# Select the newly added point
	for i in range(keys.size()):
		if is_equal_approx(float(keys[i].get("pos", -1.0)), pos):
			_selected_idx = i
			break
	_emit_changed()


## Toggles a keypoint between linear (tangents=0) and auto-smooth tangents.
func _toggle_tangent_mode(idx: int) -> void:
	var k: Dictionary = keys[idx]
	var lt := float(k.get("left_tangent", 0.0))
	var rt := float(k.get("right_tangent", 0.0))
	if is_zero_approx(lt) and is_zero_approx(rt):
		# Compute auto tangent from neighbors
		var auto_tan := _compute_auto_tangent(idx)
		k["left_tangent"] = auto_tan
		k["right_tangent"] = auto_tan
	else:
		# Reset to linear
		k["left_tangent"] = 0.0
		k["right_tangent"] = 0.0
	_emit_changed()
	queue_redraw()


## Computes an automatic tangent based on neighbor keypoints (Catmull-Rom style).
func _compute_auto_tangent(idx: int) -> float:
	if keys.size() < 2:
		return 0.0
	if idx == 0:
		# Use slope to next point
		var k0: Dictionary = keys[0]
		var k1: Dictionary = keys[1]
		var dp := float(k1.get("pos", 1.0)) - float(k0.get("pos", 0.0))
		if dp < 1e-6:
			return 0.0
		return (float(k1.get("value", 0.0)) - float(k0.get("value", 0.0))) / dp
	if idx == keys.size() - 1:
		# Use slope from previous point
		var k0: Dictionary = keys[idx - 1]
		var k1: Dictionary = keys[idx]
		var dp := float(k1.get("pos", 1.0)) - float(k0.get("pos", 0.0))
		if dp < 1e-6:
			return 0.0
		return (float(k1.get("value", 0.0)) - float(k0.get("value", 0.0))) / dp
	# Interior point: average slopes to neighbors
	var kp: Dictionary = keys[idx - 1]
	var kc: Dictionary = keys[idx]
	var kn: Dictionary = keys[idx + 1]
	var dp_left := float(kc.get("pos", 0.5)) - float(kp.get("pos", 0.0))
	var dp_right := float(kn.get("pos", 1.0)) - float(kc.get("pos", 0.5))
	var slope_left := (float(kc.get("value", 0.5)) - float(kp.get("value", 0.0))) / maxf(dp_left, 1e-6)
	var slope_right := (float(kn.get("value", 1.0)) - float(kc.get("value", 0.5))) / maxf(dp_right, 1e-6)
	return (slope_left + slope_right) * 0.5


## Sorts keypoints by position.
func _sort_keys() -> void:
	keys.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("pos", 0.0)) < float(b.get("pos", 0.0))
	)


## Emits the ramp_changed signal with a deep copy of the current keys.
func _emit_changed() -> void:
	ramp_changed.emit(keys.duplicate(true))
