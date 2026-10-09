class_name GNTakePanel
extends PanelContainer
## Editor panel for managing Takes — named parameter layer presets.
##
## Shows a list of takes with buttons to capture, apply, revert, blend, delete,
## and save/load .gntake files.

var take_manager: GNTakeManager = null

var _take_list: ItemList = null
var _blend_slider: HSlider = null
var _blend_label: Label = null
var _status_label: Label = null
var _name_edit: LineEdit = null


func _ready() -> void:
	custom_minimum_size = Vector2(0, 160)
	_build_ui()
	if take_manager != null:
		take_manager.takes_changed.connect(_refresh_list)
		take_manager.active_take_changed.connect(_on_active_changed)


func setup(mgr: GNTakeManager) -> void:
	take_manager = mgr
	if is_inside_tree():
		take_manager.takes_changed.connect(_refresh_list)
		take_manager.active_take_changed.connect(_on_active_changed)
		_refresh_list()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	add_child(vbox)

	# Header row
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "Takes"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(spacer)

	_status_label = Label.new()
	_status_label.text = "No base captured"
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	header.add_child(_status_label)

	# Capture row
	var capture_row := HBoxContainer.new()
	vbox.add_child(capture_row)

	var base_btn := Button.new()
	base_btn.text = "Capture Base"
	base_btn.tooltip_text = "Snapshot all current parameter values as the Base layer"
	base_btn.pressed.connect(_on_capture_base)
	capture_row.add_child(base_btn)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Take name…"
	_name_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	_name_edit.custom_minimum_size.x = 100
	capture_row.add_child(_name_edit)

	var cap_btn := Button.new()
	cap_btn.text = "Capture Take"
	cap_btn.tooltip_text = "Capture current param values as a named Take (only stores differences from Base)"
	cap_btn.pressed.connect(_on_capture_take)
	capture_row.add_child(cap_btn)

	# Take list
	_take_list = ItemList.new()
	_take_list.size_flags_vertical = SIZE_EXPAND_FILL
	_take_list.custom_minimum_size.y = 60
	_take_list.allow_reselect = true
	_take_list.item_activated.connect(_on_take_activated)
	vbox.add_child(_take_list)

	# Action row
	var action_row := HBoxContainer.new()
	vbox.add_child(action_row)

	var apply_btn := Button.new()
	apply_btn.text = "Apply"
	apply_btn.tooltip_text = "Apply the selected take"
	apply_btn.pressed.connect(_on_apply)
	action_row.add_child(apply_btn)

	var revert_btn := Button.new()
	revert_btn.text = "Revert to Base"
	revert_btn.tooltip_text = "Restore all parameters to base state"
	revert_btn.pressed.connect(_on_revert)
	action_row.add_child(revert_btn)

	var del_btn := Button.new()
	del_btn.text = "Delete"
	del_btn.tooltip_text = "Delete the selected take"
	del_btn.pressed.connect(_on_delete)
	action_row.add_child(del_btn)

	var save_btn := Button.new()
	save_btn.text = "Save…"
	save_btn.tooltip_text = "Save all takes to a .gntake file"
	save_btn.pressed.connect(_on_save)
	action_row.add_child(save_btn)

	var load_btn := Button.new()
	load_btn.text = "Load…"
	load_btn.tooltip_text = "Load takes from a .gntake file"
	load_btn.pressed.connect(_on_load)
	action_row.add_child(load_btn)

	# Blend row
	var blend_row := HBoxContainer.new()
	vbox.add_child(blend_row)

	var blend_title := Label.new()
	blend_title.text = "Blend:"
	blend_title.add_theme_font_size_override("font_size", 12)
	blend_row.add_child(blend_title)

	_blend_slider = HSlider.new()
	_blend_slider.min_value = 0.0
	_blend_slider.max_value = 1.0
	_blend_slider.step = 0.01
	_blend_slider.value = 0.0
	_blend_slider.size_flags_horizontal = SIZE_EXPAND_FILL
	_blend_slider.value_changed.connect(_on_blend_changed)
	blend_row.add_child(_blend_slider)

	_blend_label = Label.new()
	_blend_label.text = "0%"
	_blend_label.custom_minimum_size.x = 40
	_blend_label.add_theme_font_size_override("font_size", 12)
	blend_row.add_child(_blend_label)


func _refresh_list() -> void:
	if not visible or _take_list == null or take_manager == null:
		return
	_take_list.clear()
	for tname in take_manager.get_take_names():
		var count: int = take_manager.get_take_override_count(tname)
		var label_text := "%s (%d overrides)" % [tname, count]
		_take_list.add_item(label_text)

	_status_label.text = "Base: %d params" % take_manager._base.size() if take_manager.has_base() else "No base captured"


func _on_active_changed(take_name: String) -> void:
	if take_name.is_empty():
		_status_label.text = "Active: Base"
	else:
		_status_label.text = "Active: %s" % take_name


func _on_capture_base() -> void:
	if take_manager:
		take_manager.capture_base()
		_refresh_list()


func _on_capture_take() -> void:
	if take_manager == null:
		return
	var tname: String = _name_edit.text.strip_edges()
	if tname.is_empty():
		tname = "Take %d" % (take_manager.get_take_names().size() + 1)
	take_manager.capture_take(tname)
	_name_edit.text = ""


func _on_take_activated(idx: int) -> void:
	_on_apply()


func _get_selected_take() -> String:
	var sel: PackedInt32Array = _take_list.get_selected_items()
	if sel.is_empty() or take_manager == null:
		return ""
	var names := take_manager.get_take_names()
	if sel[0] < names.size():
		return names[sel[0]]
	return ""


func _on_apply() -> void:
	var tname := _get_selected_take()
	if not tname.is_empty() and take_manager:
		take_manager.apply_take(tname)
		_blend_slider.value = 1.0


func _on_revert() -> void:
	if take_manager:
		take_manager.revert_to_base()
		_blend_slider.value = 0.0


func _on_delete() -> void:
	var tname := _get_selected_take()
	if not tname.is_empty() and take_manager:
		take_manager.delete_take(tname)


func _on_blend_changed(value: float) -> void:
	_blend_label.text = "%d%%" % int(value * 100.0)
	var tname := _get_selected_take()
	if not tname.is_empty() and take_manager:
		take_manager.blend_take(tname, value)


func _on_save() -> void:
	if take_manager == null:
		return
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.gntake", "GONODES Take File")
	dialog.current_dir = "res://"
	dialog.file_selected.connect(func(path: String) -> void:
		take_manager.save_to_file(path)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(600, 400))


func _on_load() -> void:
	if take_manager == null:
		return
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.gntake", "GONODES Take File")
	dialog.current_dir = "res://"
	dialog.file_selected.connect(func(path: String) -> void:
		take_manager.load_from_file(path)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(600, 400))
