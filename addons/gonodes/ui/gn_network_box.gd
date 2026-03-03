class_name GNNetworkBox
extends Control
## A colored rectangle annotation drawn behind graph nodes.
## Used for visually grouping related operators on the canvas.
## Supports drag-move, resize handles, double-click to edit title,
## and right-click to change color or delete.

## Emitted when the box is moved or resized.
signal box_changed(ann_id: String, position: Vector2, size: Vector2)

## Emitted when the title text is changed.
signal text_changed(ann_id: String, text: String)

## Emitted when the user requests deletion.
signal delete_requested(ann_id: String)

## Emitted when the user changes the color.
signal color_changed(ann_id: String, color: Color)

## Emitted each frame while the box is being dragged (delta in canvas coords).
signal box_dragging(ann_id: String, delta: Vector2)

## Emitted when box drag starts.
signal drag_started(ann_id: String)

## Emitted when box drag ends.
signal drag_ended(ann_id: String)

## The annotation ID from GNNetwork.
var ann_id: String = ""

## Title text displayed at the top of the box.
var title_text: String = ""

## Box background color.
var box_color: Color = Color(0.15, 0.35, 0.65, 0.7)

## Minimum box size in pixels.
const _MIN_SIZE := Vector2(100, 60)

## Resize handle size in pixels.
const _HANDLE_SIZE := 12.0

## Title bar height.
const _TITLE_HEIGHT := 24.0

## Whether the user is dragging the box body.
var _dragging: bool = false

## Whether the user is resizing (bottom-right corner).
var _resizing: bool = false

## Drag offset from mouse to box origin.
var _drag_offset: Vector2 = Vector2.ZERO

## Inline title editor (shown on double-click).
var _title_edit: LineEdit = null

## Popup context menu.
var _popup: PopupMenu = null

## Color picker popup.
var _color_picker_popup: PopupPanel = null


func _init() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	# Must be drawn behind GraphNode children (low z-index)
	z_index = -10
	focus_mode = FOCUS_NONE


func setup(p_id: String, p_position: Vector2, p_size: Vector2,
		p_text: String, p_color: Color) -> void:
	ann_id = p_id
	title_text = p_text
	box_color = p_color
	position = p_position
	size = p_size
	custom_minimum_size = _MIN_SIZE
	tooltip_text = "Network Box — double-click to rename, right-click for options"


func _draw() -> void:
	# Background fill
	draw_rect(Rect2(Vector2.ZERO, size), box_color)

	# Border
	var border_color := box_color.lightened(0.3)
	border_color.a = clampf(border_color.a + 0.2, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), border_color, false, 1.5)

	# Title bar background (slightly darker)
	var title_rect := Rect2(Vector2.ZERO, Vector2(size.x, _TITLE_HEIGHT))
	var title_bg := box_color.darkened(0.2)
	title_bg.a = clampf(title_bg.a + 0.15, 0.0, 1.0)
	draw_rect(title_rect, title_bg)

	# Title text
	if not title_text.is_empty() and (_title_edit == null or not _title_edit.visible):
		var font := ThemeDB.fallback_font
		var font_size := 13
		var text_pos := Vector2(6, _TITLE_HEIGHT - 6)
		draw_string(font, text_pos, title_text, HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 12, font_size, Color(0.85, 0.85, 0.85))

	# Resize handle (bottom-right corner triangle)
	var handle_pts := PackedVector2Array([
		Vector2(size.x, size.y),
		Vector2(size.x - _HANDLE_SIZE, size.y),
		Vector2(size.x, size.y - _HANDLE_SIZE),
	])
	draw_colored_polygon(handle_pts, border_color)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.double_click:
					_start_title_edit()
				elif _is_in_resize_handle(mb.position):
					_resizing = true
					_drag_offset = size - mb.position
				else:
					_dragging = true
					_drag_offset = mb.position
					drag_started.emit(ann_id)
				accept_event()
			else:
				if _dragging or _resizing:
					if _dragging:
						drag_ended.emit(ann_id)
					_dragging = false
					_resizing = false
					box_changed.emit(ann_id, position, size)
				accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_show_popup(mb.global_position)
			accept_event()

	elif event is InputEventMouseMotion:
		if _dragging:
			var delta := (event as InputEventMouseMotion).relative
			position += delta
			box_dragging.emit(ann_id, delta)
			accept_event()
		elif _resizing:
			var new_size := (event as InputEventMouseMotion).position + _drag_offset
			size = Vector2(maxf(new_size.x, _MIN_SIZE.x), maxf(new_size.y, _MIN_SIZE.y))
			queue_redraw()
			accept_event()


## Returns true if the position is in the bottom-right resize handle area.
func _is_in_resize_handle(local_pos: Vector2) -> bool:
	return local_pos.x >= size.x - _HANDLE_SIZE and local_pos.y >= size.y - _HANDLE_SIZE


## Opens the inline title editor.
func _start_title_edit() -> void:
	if _title_edit == null:
		_title_edit = LineEdit.new()
		_title_edit.add_theme_font_size_override("font_size", 13)
		_title_edit.placeholder_text = "Box title…"
		add_child(_title_edit)
		_title_edit.text_submitted.connect(_on_title_submitted)
		_title_edit.focus_exited.connect(_on_title_focus_lost)
	_title_edit.text = title_text
	_title_edit.position = Vector2(2, 0)
	_title_edit.size = Vector2(size.x - 4, _TITLE_HEIGHT)
	_title_edit.visible = true
	_title_edit.grab_focus()
	_title_edit.select_all()


func _on_title_submitted(text: String) -> void:
	title_text = text
	_title_edit.visible = false
	text_changed.emit(ann_id, title_text)
	queue_redraw()


func _on_title_focus_lost() -> void:
	if _title_edit != null and _title_edit.visible:
		title_text = _title_edit.text
		_title_edit.visible = false
		text_changed.emit(ann_id, title_text)
		queue_redraw()


## Shows the right-click context menu.
func _show_popup(screen_pos: Vector2) -> void:
	if _popup == null:
		_popup = PopupMenu.new()
		_popup.add_item("Rename", 0)
		_popup.add_item("Change Color…", 1)
		_popup.add_separator()
		_popup.add_item("Delete Box", 2)
		_popup.id_pressed.connect(_on_popup_id)
		add_child(_popup)
	_popup.position = Vector2i(screen_pos)
	_popup.reset_size()
	_popup.popup()


func _on_popup_id(id: int) -> void:
	match id:
		0: _start_title_edit()
		1: _show_color_picker()
		2: delete_requested.emit(ann_id)


## Shows a popup color picker.
func _show_color_picker() -> void:
	if _color_picker_popup == null:
		_color_picker_popup = PopupPanel.new()
		var picker := ColorPicker.new()
		picker.color = box_color
		picker.custom_minimum_size = Vector2(250, 300)
		picker.color_changed.connect(func(c: Color) -> void:
			box_color = c
			queue_redraw()
			color_changed.emit(ann_id, c)
		)
		_color_picker_popup.add_child(picker)
		add_child(_color_picker_popup)
	else:
		var picker: ColorPicker = _color_picker_popup.get_child(0) as ColorPicker
		if picker:
			picker.color = box_color
	_color_picker_popup.popup_centered()
