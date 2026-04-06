class_name GNNumericField
extends Control
## Base class for Houdini-style numeric fields (float and int).
## Provides the shared state machine, ladder, edit mode, input blocker,
## and drawing infrastructure.  Subclasses override the handful of virtual
## methods that differ between float and integer behaviour.
##
## Interaction:
##   Click              → text editing mode (type any value)
##   Ctrl+Click         → reset to default
##   Left drag          → virtual slider (scrub value at current tier)
##   Shift+drag         → fine mode (÷10)
##   Ctrl+drag          → coarse mode (×10)
##   Middle-button drag → ladder tier picker (vertical, no value change)


# ═══════════════════════════════════════════════════════════════════════════════
# Configuration (shared, type-neutral)
# ═══════════════════════════════════════════════════════════════════════════════

## Minimum bound (null = no lower limit).
var min_value: Variant = null

## Maximum bound (null = no upper limit).
var max_value: Variant = null


# ═══════════════════════════════════════════════════════════════════════════════
# Visual constants
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

const TIER_ROW_H   := 22
const LADDER_WIDTH := 110
const DRAG_DEADZONE := 3.0
const ARROW_HIT_W  := 16.0

## Emitted when Tab (forward=true) or Shift+Tab (forward=false) is pressed
## during edit mode. The parent row uses this to navigate between params.
signal tab_requested(forward: bool)


# ═══════════════════════════════════════════════════════════════════════════════
# Internal state
# ═══════════════════════════════════════════════════════════════════════════════

enum _S { IDLE, PENDING, DRAGGING, EDITING, LADDER_PICK }

var _state: _S = _S.IDLE
var _hover: bool = false

static var _any_ladder_active: bool = false

var _drag_origin: Vector2
var _active_tier: int = 0
var _ladder_pick_origin_y: float = 0.0

var _line_edit: LineEdit = null
var _ladder: Control = null
var _tier_labels: Array[Label] = []
var _sens_label: Label = null
var _input_blocker: Control = null


# ═══════════════════════════════════════════════════════════════════════════════
# Virtual interface — subclasses MUST override these
# ═══════════════════════════════════════════════════════════════════════════════

## Return the tier multiplier array (e.g. [0.001, 0.01, ...]).
func _get_tiers() -> Array:
	return []

## Return the tier label array (e.g. ["×0.001", ...]).
func _get_tier_labels() -> Array:
	return []

## Return the default/center tier index.
func _get_tier_center() -> int:
	return 0

## Reset value to default.
func _reset_to_default() -> void:
	pass

## Called on left-press to begin a pending drag. Subclass stores start value.
func _on_drag_pending(_position: Vector2) -> void:
	pass

## Process one frame of drag motion.
func _on_drag_motion(_mm: InputEventMouseMotion) -> void:
	pass

## Handle left-click in arrow hit zones (int only). Return true if consumed.
func _on_arrow_click(_position: Vector2) -> bool:
	return false

## Parse and apply text from the edit LineEdit.
func _apply_text(_text: String) -> void:
	pass

## Return display text for the current value.
func _get_display_text() -> String:
	return ""

## Return raw text for the edit LineEdit (no suffix).
func _get_edit_text() -> String:
	return ""

## Return the fill ratio (0.0–1.0) for ranged params, or -1.0 if no bar.
func _get_fill_ratio() -> float:
	return -1.0

## Draw any subclass-specific decorations (arrows, etc.) Called during _draw.
func _draw_extras() -> void:
	pass

## Return text padding (left inset, total horizontal inset) for value text.
func _get_text_padding() -> Vector2:
	return Vector2(6.0, 12.0)

## Return background color for the current state.
func _get_bg_color() -> Color:
	return BG_NORMAL

## Format the sensitivity label for the active tier.
func _format_sens_label() -> String:
	return ""


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	custom_minimum_size = Vector2(80, 24)
	mouse_default_cursor_shape = CURSOR_HSIZE
	focus_mode = FOCUS_CLICK
	mouse_filter = MOUSE_FILTER_STOP
	_active_tier = _get_tier_center()


# ═══════════════════════════════════════════════════════════════════════════════
# Drawing
# ═══════════════════════════════════════════════════════════════════════════════

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)

	# Background
	draw_rect(rect, _get_bg_color())

	# Fill bar
	if _state != _S.EDITING:
		var ratio: float = _get_fill_ratio()
		if ratio > 0.0:
			draw_rect(Rect2(Vector2(1, 1), Vector2((size.x - 2) * ratio, size.y - 2)), FILL_COLOR)

	# Subclass extras (arrows, etc.)
	if _state != _S.EDITING:
		_draw_extras()

	# Border
	var show_border: bool = _hover or _state == _S.DRAGGING or _state == _S.LADDER_PICK
	if show_border:
		var bcolor: Color = BORDER_ACTIVE if _state == _S.DRAGGING else BORDER_COLOR
		draw_rect(rect, bcolor, false, 1.0)

	# Value text
	if _state != _S.EDITING:
		var font: Font = get_theme_default_font()
		var ascent: float = font.get_ascent(VALUE_FONT_SIZE)
		var text_y: float = (size.y + ascent) * 0.5 - 1.0
		var pad: Vector2 = _get_text_padding()
		draw_string(font, Vector2(pad.x, text_y), _get_display_text(),
			HORIZONTAL_ALIGNMENT_RIGHT, size.x - pad.y, VALUE_FONT_SIZE, TEXT_COLOR)


# ═══════════════════════════════════════════════════════════════════════════════
# Input
# ═══════════════════════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if _state != _S.EDITING:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and not get_global_rect().has_point(mb.global_position):
			_apply_text(_line_edit.text)
			_exit_edit_mode()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		# Ctrl+Click: reset to default
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and mb.ctrl_pressed:
			_reset_to_default()
			accept_event()
			return

		# Left press
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if _state == _S.EDITING:
				return
			if _on_arrow_click(mb.position):
				accept_event()
				return
			_state = _S.PENDING
			_drag_origin = mb.position
			_on_drag_pending(mb.position)
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

	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _state == _S.PENDING:
			if mm.position.distance_to(_drag_origin) > DRAG_DEADZONE:
				_begin_drag()
				_on_drag_motion(mm)
		elif _state == _S.DRAGGING:
			_on_drag_motion(mm)
			accept_event()
		elif _state == _S.LADDER_PICK:
			_process_ladder_pick(mm)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
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


func _end_drag() -> void:
	_state = _S.IDLE
	_hover = get_global_rect().has_point(get_global_mouse_position())
	queue_redraw()


func _process_ladder_pick(mm: InputEventMouseMotion) -> void:
	var offset_y: float = _ladder_pick_origin_y - mm.global_position.y
	var tier_offset: int = roundi(offset_y / float(TIER_ROW_H))
	var tiers: Array = _get_tiers()
	var new_tier: int = clampi(_get_tier_center() + tier_offset, 0, tiers.size() - 1)
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


# ═══════════════════════════════════════════════════════════════════════════════
# Input blocker
# ═══════════════════════════════════════════════════════════════════════════════

func _show_input_blocker() -> void:
	if _input_blocker == null:
		_input_blocker = Control.new()
		_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
		_input_blocker.z_index = 99
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


# ═══════════════════════════════════════════════════════════════════════════════
# Edit mode (inline text input)
# ═══════════════════════════════════════════════════════════════════════════════

func _enter_edit_mode() -> void:
	if _line_edit == null:
		_create_line_edit()
	_line_edit.text = _get_edit_text()
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
		var key := event as InputEventKey
		if key.keycode == KEY_ESCAPE:
			_exit_edit_mode()
			accept_event()
		elif key.keycode == KEY_TAB:
			_apply_text(_line_edit.text)
			_exit_edit_mode()
			tab_requested.emit(not key.shift_pressed)
			accept_event()


# ═══════════════════════════════════════════════════════════════════════════════
# Ladder popup
# ═══════════════════════════════════════════════════════════════════════════════

func _show_ladder() -> void:
	if _ladder == null:
		_create_ladder()
	var field_rect: Rect2 = get_global_rect()
	var ladder_x: float = field_rect.position.x - LADDER_WIDTH - 4
	if ladder_x < 0:
		ladder_x = field_rect.end.x + 4
	var tiers: Array = _get_tiers()
	var center_visual_row: int = tiers.size() - 1 - _get_tier_center()
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
	var tiers: Array = _get_tiers()
	var tier_labels_arr: Array = _get_tier_labels()
	_ladder = Control.new()
	_ladder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ladder.z_index = 100
	_ladder.size = Vector2(LADDER_WIDTH, TIER_ROW_H * tiers.size())
	_ladder.draw.connect(_draw_ladder)
	_ladder.visible = false
	get_tree().root.add_child(_ladder)
	tree_exiting.connect(_cleanup_ladder)

	_tier_labels.clear()
	for i in range(tiers.size()):
		var tier_idx: int = tiers.size() - 1 - i
		var lbl := Label.new()
		lbl.text = tier_labels_arr[tier_idx]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.position = Vector2(6, i * TIER_ROW_H)
		lbl.size = Vector2(LADDER_WIDTH * 0.5, TIER_ROW_H)
		lbl.add_theme_font_size_override(&"font_size", 11)
		lbl.add_theme_color_override(&"font_color", Color(0.50, 0.50, 0.50))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ladder.add_child(lbl)
		_tier_labels.append(lbl)

	_sens_label = Label.new()
	_sens_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sens_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sens_label.add_theme_font_size_override(&"font_size", 11)
	_sens_label.add_theme_color_override(&"font_color", Color(0.7, 0.85, 1.0))
	_sens_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ladder.add_child(_sens_label)


func _draw_ladder() -> void:
	var tiers: Array = _get_tiers()
	var panel_rect := Rect2(Vector2.ZERO, _ladder.size)
	_ladder.draw_rect(panel_rect, Color(0.10, 0.10, 0.13, 0.95))

	for i in range(tiers.size()):
		var tier_idx: int = tiers.size() - 1 - i
		if tier_idx == _active_tier:
			var row_rect := Rect2(Vector2(0, i * TIER_ROW_H), Vector2(LADDER_WIDTH, TIER_ROW_H))
			_ladder.draw_rect(row_rect, Color(0.25, 0.42, 0.65, 0.85))

	_ladder.draw_rect(panel_rect, Color(0.30, 0.30, 0.36), false, 1.0)


func _update_ladder_labels() -> void:
	var tiers: Array = _get_tiers()
	for i in range(_tier_labels.size()):
		var tier_idx: int = tiers.size() - 1 - i
		var is_active: bool = tier_idx == _active_tier
		var col: Color = Color(1.0, 1.0, 1.0) if is_active else Color(0.50, 0.50, 0.50)
		_tier_labels[i].add_theme_color_override(&"font_color", col)

	var active_visual_row: int = tiers.size() - 1 - _active_tier
	_sens_label.text = _format_sens_label()
	_sens_label.position = Vector2(LADDER_WIDTH * 0.5, active_visual_row * TIER_ROW_H)
	_sens_label.size = Vector2(LADDER_WIDTH * 0.5 - 6, TIER_ROW_H)


func _cleanup_ladder() -> void:
	if _ladder and is_instance_valid(_ladder):
		_ladder.queue_free()
		_ladder = null
		_tier_labels.clear()
		_sens_label = null


# ═══════════════════════════════════════════════════════════════════════════════
# Utilities
# ═══════════════════════════════════════════════════════════════════════════════

func _has_range() -> bool:
	return min_value != null and max_value != null
