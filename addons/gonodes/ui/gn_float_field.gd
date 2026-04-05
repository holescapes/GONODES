class_name GNFloatField
extends Control
## Houdini-style numeric field with virtual slider drag, ladder multiplier,
## and inline text editing.  Replaces HSlider+SpinBox for all numeric params.
##
## Interaction:
##   Click              → text editing mode (type any value)
##   Ctrl+Click         → reset to default
##   Left drag          → virtual slider (scrub value at current tier)
##   Shift+drag         → fine mode (÷10)
##   Ctrl+drag          → coarse mode (×10)
##   Middle-button drag → ladder tier picker (vertical, no value change)
##   (Mouse wheel nudge disabled)


signal value_changed(new_value: float)


# ═══════════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════════

## Current value.
var value: float = 0.0

## Minimum bound (null = no lower limit).
var min_value: Variant = null

## Maximum bound (null = no upper limit).
var max_value: Variant = null

## Step size for drag sensitivity and display precision.
var step: float = 0.01

## Default value for Ctrl+Click reset.
var default_value: float = 0.0

## When true, rounds all values to integers and shows 0 decimal places.
var integer_mode: bool = false

## Optional suffix appended to the display text (e.g. "°").
var suffix: String = ""


# ═══════════════════════════════════════════════════════════════════════════════
# Constants
# ═══════════════════════════════════════════════════════════════════════════════

const BG_NORMAL          := Color(0.14, 0.14, 0.17)
const BG_NORMAL_RANGELESS := Color(0.13, 0.13, 0.16)
const BG_HOVER           := Color(0.18, 0.18, 0.22)
const BG_DRAG            := Color(0.12, 0.14, 0.18)
const FILL_COLOR         := Color(0.22, 0.38, 0.58, 0.5)
const BORDER_COLOR       := Color(0.30, 0.30, 0.36)
const BORDER_ACTIVE      := Color(0.35, 0.55, 0.80)
const ARROW_COLOR        := Color(0.40, 0.40, 0.48, 0.6)
const TEXT_COLOR          := Color(0.88, 0.88, 0.88)
const VALUE_FONT_SIZE    := 12

## Ladder tiers: multipliers applied to step per pixel of horizontal drag.
const TIERS        := [0.001, 0.01, 0.1, 1.0, 10.0, 100.0]
const TIER_LABELS  := ["×0.001", "×0.01", "×0.1", "×1", "×10", "×100"]
const TIER_CENTER  := 3     # index of ×1 in TIERS
const TIER_ROW_H   := 22   # pixels per tier row in popup
const LADDER_WIDTH := 110   # wider to fit sensitivity info

const DRAG_DEADZONE := 3.0  # pixels before drag engages


# ═══════════════════════════════════════════════════════════════════════════════
# Internal state
# ═══════════════════════════════════════════════════════════════════════════════

enum _S { IDLE, PENDING, DRAGGING, EDITING, LADDER_PICK }

var _state: _S = _S.IDLE
var _hover: bool = false

# Class-level flag: true while ANY GNFloatField has its ladder open.
static var _any_ladder_active: bool = false

# Drag tracking
var _drag_origin: Vector2
var _drag_origin_global_y: float
var _drag_start_value: float
var _active_tier: int = TIER_CENTER

# Middle-button ladder pick tracking
var _ladder_pick_origin_y: float = 0.0

# Sub-controls (created lazily)
var _line_edit: LineEdit = null
var _ladder: Control = null
var _tier_labels: Array[Label] = []
var _sens_label: Label = null
var _input_blocker: Control = null  ## Full-screen overlay that blocks all UI during ladder pick


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	custom_minimum_size = Vector2(80, 24)
	mouse_default_cursor_shape = CURSOR_HSIZE
	focus_mode = FOCUS_CLICK
	mouse_filter = MOUSE_FILTER_STOP


# ═══════════════════════════════════════════════════════════════════════════════
# Drawing
# ═══════════════════════════════════════════════════════════════════════════════

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var rangeless: bool = not _has_range()

	# Background
	var bg: Color
	match _state:
		_S.DRAGGING: bg = BG_DRAG
		_S.EDITING:  bg = BG_NORMAL
		_:
			if _hover:
				bg = BG_HOVER
			elif rangeless:
				bg = BG_NORMAL_RANGELESS
			else:
				bg = BG_NORMAL
	draw_rect(rect, bg)

	# Fill bar (ranged params only)
	if _has_range() and _state != _S.EDITING:
		var range_min: float = float(min_value)
		var range_max: float = float(max_value)
		if range_max > range_min:
			var ratio: float = clampf((value - range_min) / (range_max - range_min), 0.0, 1.0)
			if ratio > 0.0:
				draw_rect(Rect2(Vector2(1, 1), Vector2((size.x - 2) * ratio, size.y - 2)), FILL_COLOR)

	# Rangeless indicator: small ◂ ▸ arrows at left and right edges
	if rangeless and _state != _S.EDITING:
		var mid_y: float = size.y * 0.5
		var arrow_h: float = 5.0
		var arrow_w: float = 4.0
		# Left arrow ◂
		draw_colored_polygon(PackedVector2Array([
			Vector2(arrow_w + 2, mid_y - arrow_h),
			Vector2(2, mid_y),
			Vector2(arrow_w + 2, mid_y + arrow_h),
		]), ARROW_COLOR)
		# Right arrow ▸
		draw_colored_polygon(PackedVector2Array([
			Vector2(size.x - arrow_w - 2, mid_y - arrow_h),
			Vector2(size.x - 2, mid_y),
			Vector2(size.x - arrow_w - 2, mid_y + arrow_h),
		]), ARROW_COLOR)

	# Border
	var show_border: bool = _hover or _state == _S.DRAGGING or _state == _S.LADDER_PICK
	if show_border:
		var bcolor: Color = BORDER_ACTIVE if _state == _S.DRAGGING else BORDER_COLOR
		draw_rect(rect, bcolor, false, 1.0)

	# Value text (hidden in edit mode — the LineEdit handles that)
	if _state != _S.EDITING:
		var font: Font = get_theme_default_font()
		var ascent: float = font.get_ascent(VALUE_FONT_SIZE)
		var text_y: float = (size.y + ascent) * 0.5 - 1.0
		var text_x: float = 6.0 if _has_range() else 10.0  # extra left pad past arrows
		var text_w: float = size.x - (12.0 if _has_range() else 20.0)
		draw_string(font, Vector2(text_x, text_y), _format_value(),
			HORIZONTAL_ALIGNMENT_RIGHT, text_w, VALUE_FONT_SIZE, TEXT_COLOR)


# ═══════════════════════════════════════════════════════════════════════════════
# Input
# ═══════════════════════════════════════════════════════════════════════════════

func _gui_input(event: InputEvent) -> void:
	# ── Mouse button ──
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		# Ctrl+Click: reset to default
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and mb.ctrl_pressed:
			set_value(default_value)
			accept_event()
			return

		# Left press: begin pending (click-or-drag decision)
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if _state == _S.EDITING:
				return  # let the LineEdit handle it
			_state = _S.PENDING
			_drag_origin = mb.position
			_drag_start_value = value
			accept_event()
			return

		# Left release
		if not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if _state == _S.PENDING:
				_enter_edit_mode()
			elif _state == _S.DRAGGING:
				_end_drag()
			accept_event()
			return

		# Middle press: begin ladder tier picker
		if mb.pressed and mb.button_index == MOUSE_BUTTON_MIDDLE:
			if _state == _S.EDITING:
				return
			_ladder_pick_origin_y = mb.global_position.y
			_state = _S.LADDER_PICK
			_any_ladder_active = true
			_show_ladder()
			_show_input_blocker()
			accept_event()
			return

		# Middle release: commit tier selection
		if not mb.pressed and mb.button_index == MOUSE_BUTTON_MIDDLE:
			if _state == _S.LADDER_PICK:
				_end_ladder_pick()
			accept_event()
			return

		# Mouse wheel — disabled for now
		#if mb.pressed:
		#	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		#		_wheel_nudge(1, mb.shift_pressed, mb.ctrl_pressed)
		#		accept_event()
		#		return
		#	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		#		_wheel_nudge(-1, mb.shift_pressed, mb.ctrl_pressed)
		#		accept_event()
		#		return

	# ── Mouse motion ──
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _state == _S.PENDING:
			if mm.position.distance_to(_drag_origin) > DRAG_DEADZONE:
				_begin_drag()
				_process_drag(mm)
		elif _state == _S.DRAGGING:
			_process_drag(mm)
			accept_event()
		elif _state == _S.LADDER_PICK:
			_process_ladder_pick(mm)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		# Suppress hover on other fields while any ladder is open
		if not _any_ladder_active or _state == _S.LADDER_PICK:
			_hover = true
			queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		if _state != _S.DRAGGING and _state != _S.LADDER_PICK:
			_hover = false
			queue_redraw()


# ═══════════════════════════════════════════════════════════════════════════════
# Drag
# ═══════════════════════════════════════════════════════════════════════════════

func _begin_drag() -> void:
	_state = _S.DRAGGING
	queue_redraw()


func _process_drag(mm: InputEventMouseMotion) -> void:
	# Horizontal movement → value change using the active tier
	var delta_x: float = mm.relative.x
	var multiplier: float = TIERS[_active_tier]
	if mm.shift_pressed:
		multiplier *= 0.1
	elif mm.ctrl_pressed:
		multiplier *= 10.0
	set_value(value + delta_x * step * multiplier)


func _end_drag() -> void:
	_state = _S.IDLE
	_hover = get_global_rect().has_point(get_global_mouse_position())
	queue_redraw()


## Middle-button vertical drag updates the ladder tier (no value change).
func _process_ladder_pick(mm: InputEventMouseMotion) -> void:
	var offset_y: float = _ladder_pick_origin_y - mm.global_position.y
	var tier_offset: int = roundi(offset_y / float(TIER_ROW_H))
	var new_tier: int = clampi(TIER_CENTER + tier_offset, 0, TIERS.size() - 1)
	if new_tier != _active_tier:
		_active_tier = new_tier
		if _ladder:
			_update_ladder_labels()
			_ladder.queue_redraw()


func _end_ladder_pick() -> void:
	_state = _S.IDLE
	_any_ladder_active = false
	_hide_ladder()
	_hide_input_blocker()
	_hover = get_global_rect().has_point(get_global_mouse_position())
	queue_redraw()


## Full-screen transparent overlay that intercepts all mouse events during
## ladder pick, preventing buttons, sliders, and other UI from highlighting.
func _show_input_blocker() -> void:
	if _input_blocker == null:
		_input_blocker = Control.new()
		_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
		_input_blocker.z_index = 99  # just below the ladder (z_index 100)
		_input_blocker.gui_input.connect(_on_blocker_input)
		get_tree().root.add_child(_input_blocker)
		tree_exiting.connect(_cleanup_input_blocker)
	_input_blocker.position = Vector2.ZERO
	_input_blocker.size = get_tree().root.size
	_input_blocker.visible = true


func _hide_input_blocker() -> void:
	if _input_blocker:
		_input_blocker.visible = false


func _cleanup_input_blocker() -> void:
	if _input_blocker and is_instance_valid(_input_blocker):
		_input_blocker.queue_free()
		_input_blocker = null


func _on_blocker_input(event: InputEvent) -> void:
	# Forward middle-release and mouse motion to ladder pick logic
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed and mb.button_index == MOUSE_BUTTON_MIDDLE:
			if _state == _S.LADDER_PICK:
				_end_ladder_pick()
			_input_blocker.accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _state == _S.LADDER_PICK:
			_process_ladder_pick(mm)
			_input_blocker.accept_event()


#func _wheel_nudge(direction: int, shift_held: bool, ctrl_held: bool) -> void:
#	var s: float = step
#	if shift_held:
#		s *= 0.1
#	elif ctrl_held:
#		s *= 10.0
#	set_value(value + s * direction)


# ═══════════════════════════════════════════════════════════════════════════════
# Edit mode (inline text input)
# ═══════════════════════════════════════════════════════════════════════════════

func _enter_edit_mode() -> void:
	if _line_edit == null:
		_create_line_edit()
	_line_edit.text = _format_value_raw()
	_line_edit.position = Vector2(4, 2)
	_line_edit.size = Vector2(size.x - 8, size.y - 4)
	_line_edit.visible = true
	_line_edit.grab_focus()
	_line_edit.select_all()
	_state = _S.EDITING
	queue_redraw()


func _exit_edit_mode() -> void:
	if _state != _S.EDITING:
		return
	_state = _S.IDLE
	if _line_edit:
		_line_edit.visible = false
		_line_edit.release_focus()
	queue_redraw()


func _create_line_edit() -> void:
	_line_edit = LineEdit.new()
	_line_edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_line_edit.add_theme_font_size_override("font_size", VALUE_FONT_SIZE)
	_line_edit.add_theme_color_override("font_color", Color(1, 1, 1))
	# Transparent background so the field's own _draw() shows through
	var empty := StyleBoxEmpty.new()
	_line_edit.add_theme_stylebox_override("normal", empty)
	_line_edit.add_theme_stylebox_override("focus", empty)
	_line_edit.text_submitted.connect(_on_text_submitted)
	_line_edit.focus_exited.connect(_on_text_focus_lost)
	_line_edit.gui_input.connect(_on_text_gui_input)
	_line_edit.visible = false
	add_child(_line_edit)


func _on_text_submitted(_text: String) -> void:
	_apply_text(_line_edit.text)
	_exit_edit_mode()


func _on_text_focus_lost() -> void:
	if _state == _S.EDITING:
		_apply_text(_line_edit.text)
		_exit_edit_mode()


func _on_text_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_exit_edit_mode()
			accept_event()


func _apply_text(text: String) -> void:
	text = text.strip_edges()
	if text.is_valid_float():
		set_value(text.to_float())
	elif integer_mode and text.is_valid_int():
		set_value(float(text.to_int()))


# ═══════════════════════════════════════════════════════════════════════════════
# Ladder popup
# ═══════════════════════════════════════════════════════════════════════════════

func _show_ladder() -> void:
	if _ladder == null:
		_create_ladder()
	# Position the ladder to the LEFT of the field, ×1 tier row centered on click Y
	var field_rect: Rect2 = get_global_rect()
	var ladder_x: float = field_rect.position.x - LADDER_WIDTH - 4
	if ladder_x < 0:
		ladder_x = field_rect.end.x + 4  # fall back to right side if no room
	var center_visual_row: int = TIERS.size() - 1 - TIER_CENTER
	var center_row_center_y: float = (center_visual_row + 0.5) * TIER_ROW_H
	var ladder_y: float = _ladder_pick_origin_y - center_row_center_y
	_ladder.position = Vector2(ladder_x, ladder_y)
	_ladder.visible = true
	_update_ladder_labels()
	_ladder.queue_redraw()


func _hide_ladder() -> void:
	if _ladder:
		_ladder.visible = false


func _create_ladder() -> void:
	_ladder = Control.new()
	_ladder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ladder.z_index = 100
	_ladder.size = Vector2(LADDER_WIDTH, TIER_ROW_H * TIERS.size())
	_ladder.draw.connect(_draw_ladder)
	_ladder.visible = false
	# Add to viewport root so no ancestor ScrollContainer can clip the labels
	get_tree().root.add_child(_ladder)
	tree_exiting.connect(_cleanup_ladder)

	# Create Label nodes for each tier row
	_tier_labels.clear()
	for i in range(TIERS.size()):
		var tier_idx: int = TIERS.size() - 1 - i  # top row = coarsest tier
		var lbl := Label.new()
		lbl.text = TIER_LABELS[tier_idx]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.position = Vector2(6, i * TIER_ROW_H)
		lbl.size = Vector2(LADDER_WIDTH * 0.5, TIER_ROW_H)
		lbl.add_theme_font_size_override(&"font_size", 11)
		lbl.add_theme_color_override(&"font_color", Color(0.50, 0.50, 0.50))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ladder.add_child(lbl)
		_tier_labels.append(lbl)

	# Sensitivity label (shown on active tier row)
	_sens_label = Label.new()
	_sens_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sens_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sens_label.add_theme_font_size_override(&"font_size", 11)
	_sens_label.add_theme_color_override(&"font_color", Color(0.7, 0.85, 1.0))
	_sens_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ladder.add_child(_sens_label)


func _draw_ladder() -> void:
	var panel_rect := Rect2(Vector2.ZERO, _ladder.size)

	# Panel background
	_ladder.draw_rect(panel_rect, Color(0.10, 0.10, 0.13, 0.95))

	for i in range(TIERS.size()):
		var tier_idx: int = TIERS.size() - 1 - i
		var is_active: bool = tier_idx == _active_tier

		# Highlight active tier
		if is_active:
			var row_rect := Rect2(Vector2(0, i * TIER_ROW_H), Vector2(LADDER_WIDTH, TIER_ROW_H))
			_ladder.draw_rect(row_rect, Color(0.25, 0.42, 0.65, 0.85))

	# Border
	_ladder.draw_rect(panel_rect, Color(0.30, 0.30, 0.36), false, 1.0)


func _update_ladder_labels() -> void:
	for i in range(_tier_labels.size()):
		var tier_idx: int = TIERS.size() - 1 - i
		var is_active: bool = tier_idx == _active_tier
		var col: Color = Color(1.0, 1.0, 1.0) if is_active else Color(0.50, 0.50, 0.50)
		_tier_labels[i].add_theme_color_override(&"font_color", col)

	# Position and populate sensitivity label on the active tier's visual row
	var active_visual_row: int = TIERS.size() - 1 - _active_tier
	var per_px: float = step * TIERS[_active_tier]
	var sens_text: String
	if per_px >= 1.0:
		sens_text = "%d/px" % int(per_px)
	elif per_px >= 0.1:
		sens_text = "%.1f/px" % per_px
	elif per_px >= 0.01:
		sens_text = "%.2f/px" % per_px
	elif per_px >= 0.001:
		sens_text = "%.3f/px" % per_px
	else:
		sens_text = "%.4f/px" % per_px
	_sens_label.text = sens_text
	_sens_label.position = Vector2(LADDER_WIDTH * 0.5, active_visual_row * TIER_ROW_H)
	_sens_label.size = Vector2(LADDER_WIDTH * 0.5 - 6, TIER_ROW_H)


func _cleanup_ladder() -> void:
	if _ladder and is_instance_valid(_ladder):
		_ladder.queue_free()
		_ladder = null
		_tier_labels.clear()
		_sens_label = null


# ═══════════════════════════════════════════════════════════════════════════════
# Value management
# ═══════════════════════════════════════════════════════════════════════════════

## Sets value with signal emission. Use for user-initiated changes.
func set_value(v: float) -> void:
	v = _clamp_value(v)
	if integer_mode:
		v = roundf(v)
	if not is_equal_approx(v, value):
		value = v
		queue_redraw()
		value_changed.emit(v)


## Sets value without emitting signal. Use for external/programmatic updates.
func set_value_no_signal(v: float) -> void:
	v = _clamp_value(v)
	if integer_mode:
		v = roundf(v)
	value = v
	queue_redraw()


func _clamp_value(v: float) -> float:
	if min_value != null and v < float(min_value):
		v = float(min_value)
	if max_value != null and v > float(max_value):
		v = float(max_value)
	return v


func _has_range() -> bool:
	return min_value != null and max_value != null


# ═══════════════════════════════════════════════════════════════════════════════
# Formatting
# ═══════════════════════════════════════════════════════════════════════════════

## Formatted value for display (includes suffix).
func _format_value() -> String:
	var text: String = _format_value_raw()
	if not suffix.is_empty():
		text += suffix
	return text


## Raw numeric text (no suffix) — used for the edit LineEdit.
func _format_value_raw() -> String:
	if integer_mode:
		return str(int(value))
	var prec: int = _auto_precision()
	return ("%." + str(prec) + "f") % value


func _auto_precision() -> int:
	if step >= 1.0:
		return 0
	if step >= 0.1:
		return 1
	if step >= 0.01:
		return 2
	return 3
