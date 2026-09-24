class_name GNExtensionsPanel
extends Window
## Lists discovered GONODES extensions, toggles disable prefs, and loads .pck packs.


signal registry_rescanned


var _scroll: ScrollContainer = null
var _rows: VBoxContainer = null
var _note: Label = null


func _init() -> void:
	title = "GONODES Extensions"
	size = Vector2i(560, 420)
	min_size = Vector2i(440, 320)
	exclusive = false
	transient = true
	wrap_controls = true


func _ready() -> void:
	close_requested.connect(hide)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	_note = Label.new()
	_note.text = "Uncheck to remove GDScript operators and .gnasset files from the palette immediately. Native GDExtension libraries still require a Godot restart."
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_font_size_override("font_size", 11)
	_note.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	root.add_child(_note)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)

	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 4)
	_scroll.add_child(_rows)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	var load_btn := Button.new()
	load_btn.text = "Load Extension Pack (.pck)…"
	load_btn.pressed.connect(_on_load_pck_pressed)
	btn_row.add_child(load_btn)
	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh List"
	refresh_btn.pressed.connect(refresh)
	btn_row.add_child(refresh_btn)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(spacer)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(hide)
	btn_row.add_child(close_btn)
	root.add_child(btn_row)

	refresh()


func refresh() -> void:
	for child in _rows.get_children():
		child.queue_free()

	var reg := GNExtensionRegistry.instance()
	var extensions: Array = reg.discover_extensions()
	if extensions.is_empty():
		var empty := Label.new()
		empty.text = "No extensions found under res://addons/ or user://extensions/."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_rows.add_child(empty)
		return

	for ext in extensions:
		if typeof(ext) != TYPE_DICTIONARY:
			continue
		var folder_name: String = ext.get("folder_name", "")
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var cb := CheckBox.new()
		cb.text = "%s  v%s  [%s]" % [
			ext.get("name", folder_name),
			ext.get("version", "?"),
			ext.get("source", "?"),
		]
		if ext.get("has_native", false):
			cb.text += "  (native)"
		cb.button_pressed = not ext.get("disabled", false)
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.tooltip_text = "Folder: %s\nPath: %s" % [folder_name, ext.get("path", "")]
		cb.toggled.connect(_on_extension_toggled.bind(folder_name, ext))
		row.add_child(cb)
		_rows.add_child(row)


func _on_extension_toggled(enabled: bool, folder_name: String, ext: Dictionary) -> void:
	if folder_name.is_empty():
		return
	var reg := GNExtensionRegistry.instance()
	var disabled := GNExtensionRegistry.load_disabled_extension_folders()
	if enabled:
		disabled.erase(folder_name)
		GNExtensionRegistry.save_disabled_extension_folders(disabled)
		reg.scan_extensions()
		reg.scan_custom_assets()
		registry_rescanned.emit()
		refresh()
		var msg := "Extension '%s' enabled.\nGDScript operators and .gnasset files are available in the palette." % ext.get("name", folder_name)
		if ext.get("has_native", false):
			msg += "\nNative GDExtension libraries still require a Godot restart."
		_show_info(msg)
	else:
		reg.unload_extension_folder(folder_name)
		if not disabled.has(folder_name):
			disabled.append(folder_name)
		GNExtensionRegistry.save_disabled_extension_folders(disabled)
		registry_rescanned.emit()
		refresh()
		var msg := "Extension '%s' disabled.\nGDScript operators and .gnasset files were removed from the palette." % ext.get("name", folder_name)
		if ext.get("has_native", false):
			msg += "\nNative GDExtension libraries still require a Godot restart."
		_show_info(msg)


func _on_load_pck_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.title = "Load Extension Pack"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.pck ; Godot PCK"])
	dialog.file_selected.connect(_on_pck_selected)
	add_child(dialog)
	dialog.popup_centered_ratio(0.6)


func _on_pck_selected(path: String) -> void:
	if not ProjectSettings.load_resource_pack(path, true):
		_show_info("Failed to load pack:\n%s" % path)
		return

	var reg := GNExtensionRegistry.instance()
	reg.scan_extensions()
	reg.scan_custom_assets()
	registry_rescanned.emit()
	refresh()
	_show_info(
		"Loaded extension pack.\n"
		+ "GDScript operators and .gnasset files are available after rescan.\n"
		+ "Native libraries still require a Godot restart.")


func _show_info(text: String) -> void:
	var dlg := AcceptDialog.new()
	dlg.dialog_text = text
	dlg.confirmed.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()
