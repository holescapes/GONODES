class_name GNStickyNote
extends Control
## A sticky note annotation on the graph canvas.
## Displays editable text in a colored rectangle.
## Supports drag-move, double-click to edit, right-click menu.

## Emitted when the note is moved or resized.
signal note_changed(ann_id: String, position: Vector2, size: Vector2)

## Emitted when the text is changed.
signal text_changed(ann_id: String, text: String)

## Emitted when the user requests deletion.
signal delete_requested(ann_id: String)

## Emitted when the user changes the color.
signal color_changed(ann_id: String, color: Color)

## Emitted when the user changes the text size.
signal font_size_changed(ann_id: String, font_size: int)

## The annotation ID from GNNetwork.
var ann_id: String = ""

## Note body text.
var note_text: String = ""

## Note background color.
var note_color: Color = Color(0.9, 0.85, 0.4, 0.9)

## Text size in pixels (saved with the patch; default 12).
var note_font_size: int = 12

## Minimum size.
const _MIN_SIZE := Vector2(80, 40)

## Resize handle size.
const _HANDLE_SIZE := 10.0

## Text padding.
const _PAD := 6.0

const _FONT_SIZES: Array[int] = [12, 16, 24, 32]

## Whether the user is dragging.
var _dragging: bool = false

## Whether the user is resizing.
var _resizing: bool = false

## Drag offset.
var _drag_offset: Vector2 = Vector2.ZERO

## Inline text editor (shown on double-click).
var _text_edit: TextEdit = null

## Popup context menu.
var _popup: PopupMenu = null

## Text Size submenu.
var _text_size_sub: PopupMenu = null

## Color picker popup.
var _color_picker_popup: PopupPanel = null


func _init() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	z_index = -9  # Above network boxes (-10), below nodes
	focus_mode = FOCUS_NONE


func setup(p_id: String, p_position: Vector2, p_size: Vector2,
		p_text: String, p_color: Color, p_font_size: int = 12) -> void:
	ann_id = p_id
	note_text = p_text
	note_color = p_color
	note_font_size = p_font_size
	position = p_position
	size = p_size
	scale = Vector2.ONE
	custom_minimum_size = _MIN_SIZE
	tooltip_text = "Sticky Note — double-click to edit, right-click for options"
	call_deferred("refit")


func _zoom() -> float:
	var parent_ctrl := get_parent()
	if parent_ctrl is GraphEdit:
		return (parent_ctrl as GraphEdit).zoom
	return 1.0


func _draw_font_size() -> int:
	return maxi(1, int(round(float(note_font_size) * _zoom())))


func after_sync_transform() -> void:
	scale = Vector2.ONE
	_apply_text_edit_font()
	queue_redraw()


func _line_height() -> float:
	return float(_draw_font_size()) * 1.25


func _inner_width() -> float:
	return maxf(size.x - _PAD * 2.0, 1.0)


func _inner_height() -> float:
	return maxf(size.y - _PAD * 2.0, 1.0)


func _text_for_layout() -> String:
	if _text_edit != null and _text_edit.visible:
		return _text_edit.text
	return note_text


func _max_word_width(text: String, font: Font) -> float:
	var max_w := 0.0
	for line in text.split("\n"):
		if line.is_empty():
			continue
		var parts: PackedStringArray
		if line.find(" ") >= 0:
			parts = line.split(" ", false)
		else:
			parts = PackedStringArray([line])
		for word in parts:
			if word.is_empty():
				continue
			var w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, _draw_font_size()).x
			max_w = maxf(max_w, w)
	return max_w


func _needed_box_size(text: String, from_content: bool = false) -> Vector2:
	var font := ThemeDB.fallback_font
	var draw_fs := _draw_font_size()
	var max_word_w := _max_word_width(text, font)
	var inner_w: float
	if from_content:
		inner_w = max_word_w
		if not text.is_empty():
			var natural := font.get_multiline_string_size(
				text, HORIZONTAL_ALIGNMENT_LEFT, -1, draw_fs)
			inner_w = maxf(max_word_w, natural.x)
	else:
		inner_w = _inner_width()
	var wrapped := font.get_multiline_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, inner_w, draw_fs)
	if max_word_w > inner_w:
		inner_w = max_word_w
		wrapped = font.get_multiline_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, inner_w, draw_fs)
	return Vector2(
		maxf(inner_w + _PAD * 2.0, _MIN_SIZE.x),
		maxf(wrapped.y + _PAD * 2.0, _MIN_SIZE.y))


## Grows the note to fit wrapped text when the wrap preference is enabled.
func refit() -> void:
	if not GNUiPrefs.get_wrap_sticky_notes():
		queue_redraw()
		return
	if _resizing:
		queue_redraw()
		return
	var needed := _needed_box_size(_text_for_layout())
	var new_size := size
	var changed := false
	if needed.x > size.x:
		new_size.x = needed.x
		changed = true
	if needed.y > size.y:
		new_size.y = needed.y
		changed = true
	if changed:
		size = new_size
		if _text_edit != null and _text_edit.visible:
			_text_edit.size = Vector2(_inner_width(), _inner_height())
		note_changed.emit(ann_id, position, size)
	queue_redraw()


func _apply_text_edit_font() -> void:
	if _text_edit == null:
		return
	var draw_fs := _draw_font_size()
	_text_edit.add_theme_font_size_override("font_size", draw_fs)
	_text_edit.add_theme_constant_override("line_spacing", int(maxf(2.0, float(draw_fs) * 0.2)))


func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, size), note_color)

	# Border (darker tint)
	var border_col := note_color.darkened(0.3)
	border_col.a = 1.0
	draw_rect(Rect2(Vector2.ZERO, size), border_col, false, 1.0)

	# Text (only if editor not visible)
	if not note_text.is_empty() and (_text_edit == null or not _text_edit.visible):
		var font := ThemeDB.fallback_font
		var text_color := Color(0.1, 0.1, 0.1)
		var max_width := _inner_width()
		var draw_fs := _draw_font_size()
		if GNUiPrefs.get_wrap_sticky_notes():
			var text_y := _PAD + font.get_ascent(draw_fs)
			draw_multiline_string(font, Vector2(_PAD, text_y), note_text,
				HORIZONTAL_ALIGNMENT_LEFT, max_width, draw_fs, -1, text_color)
		else:
			var line_h := _line_height()
			var lines := note_text.split("\n")
			var y_offset := _PAD + float(draw_fs)
			for line in lines:
				if y_offset > size.y - _PAD:
					break
				draw_string(font, Vector2(_PAD, y_offset), line,
					HORIZONTAL_ALIGNMENT_LEFT, max_width, draw_fs, text_color)
				y_offset += line_h

	# Resize handle (bottom-right corner)
	var handle_pts := PackedVector2Array([
		Vector2(size.x, size.y),
		Vector2(size.x - _HANDLE_SIZE, size.y),
		Vector2(size.x, size.y - _HANDLE_SIZE),
	])
	draw_colored_polygon(handle_pts, note_color.darkened(0.3))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.double_click:
					_start_text_edit()
				elif _is_in_resize_handle(mb.position):
					_resizing = true
					_drag_offset = size - mb.position
				else:
					_dragging = true
					_drag_offset = mb.position
				accept_event()
			else:
				if _dragging or _resizing:
					var was_resizing := _resizing
					_dragging = false
					_resizing = false
					note_changed.emit(ann_id, position, size)
					if was_resizing:
						refit()
				accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_show_popup(mb.global_position)
			accept_event()

	elif event is InputEventMouseMotion:
		if _dragging:
			position += (event as InputEventMouseMotion).relative
			accept_event()
		elif _resizing:
			var new_size := (event as InputEventMouseMotion).position + _drag_offset
			size = Vector2(maxf(new_size.x, _MIN_SIZE.x), maxf(new_size.y, _MIN_SIZE.y))
			queue_redraw()
			accept_event()


func _is_in_resize_handle(local_pos: Vector2) -> bool:
	return local_pos.x >= size.x - _HANDLE_SIZE and local_pos.y >= size.y - _HANDLE_SIZE


## Opens the inline text editor.
func _start_text_edit() -> void:
	if _text_edit == null:
		_text_edit = TextEdit.new()
		_text_edit.placeholder_text = "Type a note…"
		_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		add_child(_text_edit)
		_text_edit.focus_exited.connect(_on_text_focus_lost)
		_text_edit.text_changed.connect(_on_text_edit_changed)
	_apply_text_edit_font()
	_text_edit.text = note_text
	_text_edit.position = Vector2(_PAD, _PAD)
	_text_edit.size = size - Vector2(_PAD * 2.0, _PAD * 2.0)
	_text_edit.visible = true
	_text_edit.grab_focus()


func _on_text_edit_changed() -> void:
	refit()


func _on_text_focus_lost() -> void:
	if _text_edit != null and _text_edit.visible:
		note_text = _text_edit.text
		_text_edit.visible = false
		text_changed.emit(ann_id, note_text)
		refit()


## Shows the right-click context menu.
func _show_popup(screen_pos: Vector2) -> void:
	if _popup == null:
		_popup = PopupMenu.new()
		_popup.add_item("Edit Text", 0)
		_popup.add_item("Change Color…", 1)
		_text_size_sub = PopupMenu.new()
		_text_size_sub.name = "TextSizeMenu"
		for sz in _FONT_SIZES:
			_text_size_sub.add_radio_check_item(str(sz), sz)
		_text_size_sub.id_pressed.connect(_on_text_size_selected)
		_popup.add_child(_text_size_sub)
		_popup.add_submenu_item("Text Size", "TextSizeMenu")
		_popup.add_separator()
		_popup.add_item("Delete Note", 2)
		_popup.id_pressed.connect(_on_popup_id)
		add_child(_popup)
	if _text_size_sub != null:
		for i in _text_size_sub.item_count:
			var item_id: int = _text_size_sub.get_item_id(i)
			_text_size_sub.set_item_checked(i, item_id == note_font_size)
	_popup.position = Vector2i(screen_pos)
	_popup.reset_size()
	_popup.popup()


func _on_popup_id(id: int) -> void:
	match id:
		0: _start_text_edit()
		1: _show_color_picker()
		2: delete_requested.emit(ann_id)


func _on_text_size_selected(size_id: int) -> void:
	if size_id == note_font_size:
		return
	note_font_size = size_id
	_apply_text_edit_font()
	font_size_changed.emit(ann_id, note_font_size)
	if GNUiPrefs.get_wrap_sticky_notes() and not _resizing:
		var needed := _needed_box_size(_text_for_layout(), true)
		size = Vector2(
			maxf(needed.x, _MIN_SIZE.x),
			maxf(needed.y, _MIN_SIZE.y))
		if _text_edit != null and _text_edit.visible:
			_text_edit.size = Vector2(_inner_width(), _inner_height())
		note_changed.emit(ann_id, position, size)
	else:
		refit()
	queue_redraw()


## Shows a popup color picker.
func _show_color_picker() -> void:
	if _color_picker_popup == null:
		_color_picker_popup = PopupPanel.new()
		var picker := ColorPicker.new()
		picker.color = note_color
		picker.custom_minimum_size = Vector2(250, 300)
		picker.color_changed.connect(func(c: Color) -> void:
			note_color = c
			queue_redraw()
			color_changed.emit(ann_id, c)
		)
		_color_picker_popup.add_child(picker)
		add_child(_color_picker_popup)
	else:
		var picker: ColorPicker = _color_picker_popup.get_child(0) as ColorPicker
		if picker:
			picker.color = note_color
	_color_picker_popup.popup_centered()
