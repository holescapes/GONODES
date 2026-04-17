class_name GNPreferencesDialog
extends Window
## Modal preferences dialog for GONODES editor settings.
##
## Reads from / writes to GNSettings.  Each control is wired to
## live-update the setting on change.  More settings will be added
## over time — the layout uses a VBoxContainer for easy extension.


var _content: VBoxContainer = null
var _scroll: ScrollContainer = null
var _first_section: bool = true

# ─── Controls ────────────────────────────────────────────────────────────────
var _preview_height_spin: SpinBox = null
var _preview_on_create_check: CheckButton = null
var _snap_distance_spin: SpinBox = null
var _wire_style_option: OptionButton = null
var _confirm_delete_check: CheckButton = null
var _viewer_bg_picker: ColorPickerButton = null
var _default_res_x_spin: SpinBox = null
var _default_res_y_spin: SpinBox = null
var _log_level_option: OptionButton = null
var _log_to_file_check: CheckButton = null
var _parallel_cook_check: CheckButton = null
var _max_cooks_spin: SpinBox = null
var _recent_count_spin: SpinBox = null
var _auto_save_spin: SpinBox = null


func _init() -> void:
	title = "GONODES Preferences"
	size = Vector2i(460, 640)
	min_size = Vector2i(400, 500)
	exclusive = true
	unresizable = false
	transient = true
	wrap_controls = true


func _ready() -> void:
	# Close on X button
	close_requested.connect(hide)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 6)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)

	_first_section = true
	_build_section_header("General")
	_build_general_settings()

	_build_section_header("Preview")
	_build_preview_settings()

	_build_section_header("Graph Editor")
	_build_graph_settings()

	_build_section_header("Viewer")
	_build_viewer_settings()

	_build_section_header("Logging")
	_build_log_settings()

	_build_section_header("Performance")
	_build_performance_settings()

	# Close button at the bottom
	_content.add_child(_make_spacer(12))
	var btn_row := HBoxContainer.new()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(spacer)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size.x = 80
	close_btn.pressed.connect(hide)
	btn_row.add_child(close_btn)
	_content.add_child(btn_row)


func _build_section_header(label_text: String) -> void:
	# Add vertical gap before every section except the first
	if _first_section:
		_first_section = false
	else:
		_content.add_child(_make_spacer(10))

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	_content.add_child(label)
	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.3)
	_content.add_child(sep)


func _build_general_settings() -> void:
	# Auto-save interval
	var row1 := _make_row("Auto-save interval",
		"Periodically save the current patch. 0 = disabled.")
	_auto_save_spin = SpinBox.new()
	_auto_save_spin.min_value = 0
	_auto_save_spin.max_value = 600
	_auto_save_spin.step = 30
	_auto_save_spin.value = GNSettings.get_value("auto_save_interval", 0)
	_auto_save_spin.suffix = " s"
	_auto_save_spin.tooltip_text = "0 = disabled"
	_auto_save_spin.custom_minimum_size.x = 100
	_auto_save_spin.value_changed.connect(func(v: float):
		GNSettings.set_value("auto_save_interval", int(v)))
	row1.add_child(_auto_save_spin)
	_content.add_child(row1)

	# Recent patches count
	var row2 := _make_row("Max recent patches",
		"Number of entries kept in the Open Recent menu.")
	_recent_count_spin = SpinBox.new()
	_recent_count_spin.min_value = 1
	_recent_count_spin.max_value = 50
	_recent_count_spin.step = 1
	_recent_count_spin.value = GNSettings.get_value("recent_patches_count", 10)
	_recent_count_spin.custom_minimum_size.x = 100
	_recent_count_spin.value_changed.connect(func(v: float):
		GNSettings.set_value("recent_patches_count", int(v)))
	row2.add_child(_recent_count_spin)
	_content.add_child(row2)

	# Default resolution
	var row3 := _make_row("Default TOP resolution",
		"Default width × height for new TOP operators.")
	var res_box := HBoxContainer.new()
	res_box.add_theme_constant_override("separation", 4)
	_default_res_x_spin = SpinBox.new()
	_default_res_x_spin.min_value = 1
	_default_res_x_spin.max_value = 8192
	_default_res_x_spin.step = 1
	_default_res_x_spin.value = GNSettings.get_value("default_resolution_x", 512)
	_default_res_x_spin.custom_minimum_size.x = 70
	_default_res_x_spin.value_changed.connect(func(v: float):
		GNSettings.set_value("default_resolution_x", int(v)))
	res_box.add_child(_default_res_x_spin)
	var x_label := Label.new()
	x_label.text = "×"
	res_box.add_child(x_label)
	_default_res_y_spin = SpinBox.new()
	_default_res_y_spin.min_value = 1
	_default_res_y_spin.max_value = 8192
	_default_res_y_spin.step = 1
	_default_res_y_spin.value = GNSettings.get_value("default_resolution_y", 512)
	_default_res_y_spin.custom_minimum_size.x = 70
	_default_res_y_spin.value_changed.connect(func(v: float):
		GNSettings.set_value("default_resolution_y", int(v)))
	res_box.add_child(_default_res_y_spin)
	row3.add_child(res_box)
	_content.add_child(row3)


func _build_preview_settings() -> void:
	# Preview max height
	var row1 := _make_row("Max Preview Height",
		"Maximum height of inline node preview thumbnails in the graph.")
	_preview_height_spin = SpinBox.new()
	_preview_height_spin.min_value = 80
	_preview_height_spin.max_value = 600
	_preview_height_spin.step = 10
	_preview_height_spin.value = GNSettings.get_value("preview_max_height", 80.0)
	_preview_height_spin.suffix = " px"
	_preview_height_spin.custom_minimum_size.x = 100
	_preview_height_spin.value_changed.connect(func(v: float):
		GNSettings.set_value("preview_max_height", v))
	row1.add_child(_preview_height_spin)
	_content.add_child(row1)

	# Preview on create
	var row2 := _make_row("Show preview on new nodes",
		"Automatically enable the inline preview when a node is created.")
	_preview_on_create_check = CheckButton.new()
	_preview_on_create_check.button_pressed = GNSettings.get_value("preview_enabled_on_create", true)
	_preview_on_create_check.toggled.connect(func(val: bool):
		GNSettings.set_value("preview_enabled_on_create", val))
	row2.add_child(_preview_on_create_check)
	_content.add_child(row2)


func _build_graph_settings() -> void:
	# Snap distance
	var row1 := _make_row("Snap Distance",
		"Grid snap spacing for node placement. 0 = snap disabled.")
	_snap_distance_spin = SpinBox.new()
	_snap_distance_spin.min_value = 0
	_snap_distance_spin.max_value = 100
	_snap_distance_spin.step = 5
	_snap_distance_spin.value = GNSettings.get_value("graph_snap_distance", 20)
	_snap_distance_spin.suffix = " px"
	_snap_distance_spin.custom_minimum_size.x = 100
	_snap_distance_spin.value_changed.connect(func(v: float):
		GNSettings.set_value("graph_snap_distance", int(v)))
	row1.add_child(_snap_distance_spin)
	_content.add_child(row1)

	# Wire style
	var row2 := _make_row("Wire Style",
		"Connection line shape. Also toggled with W key.")
	_wire_style_option = OptionButton.new()
	_wire_style_option.add_item("Curved", 0)
	_wire_style_option.add_item("Straight", 1)
	_wire_style_option.add_item("Right-Angle", 2)
	_wire_style_option.selected = GNSettings.get_value("wire_style", 0)
	_wire_style_option.custom_minimum_size.x = 120
	_wire_style_option.item_selected.connect(func(idx: int):
		GNSettings.set_value("wire_style", idx))
	row2.add_child(_wire_style_option)
	_content.add_child(row2)

	# Confirm on delete
	var row3 := _make_row("Confirm node deletion",
		"Show a confirmation dialog before deleting selected nodes.")
	_confirm_delete_check = CheckButton.new()
	_confirm_delete_check.button_pressed = GNSettings.get_value("confirm_on_delete", false)
	_confirm_delete_check.toggled.connect(func(val: bool):
		GNSettings.set_value("confirm_on_delete", val))
	row3.add_child(_confirm_delete_check)
	_content.add_child(row3)


func _build_viewer_settings() -> void:
	var row := _make_row("Background Color",
		"Background color of the viewer panel and floating viewer windows.")
	_viewer_bg_picker = ColorPickerButton.new()
	_viewer_bg_picker.color = GNSettings.get_value("viewer_bg_color", Color(0.06, 0.06, 0.08))
	_viewer_bg_picker.custom_minimum_size = Vector2(60, 24)
	_viewer_bg_picker.edit_alpha = false
	_viewer_bg_picker.color_changed.connect(func(c: Color):
		GNSettings.set_value("viewer_bg_color", c))
	row.add_child(_viewer_bg_picker)
	_content.add_child(row)


func _build_log_settings() -> void:
	var row := _make_row("Log Level",
		"Minimum severity shown in the log panel. 0 = Debug, 1 = Info, 2 = Warn, 3 = Error.")
	_log_level_option = OptionButton.new()
	_log_level_option.add_item("Debug", 0)
	_log_level_option.add_item("Info", 1)
	_log_level_option.add_item("Warn", 2)
	_log_level_option.add_item("Error", 3)
	_log_level_option.selected = GNSettings.get_value("log_level", 1)
	_log_level_option.custom_minimum_size.x = 100
	_log_level_option.item_selected.connect(func(idx: int):
		GNSettings.set_value("log_level", idx))
	row.add_child(_log_level_option)
	_content.add_child(row)

	# Log to file
	var row2 := _make_row("Write log to file",
		"Append all log output to user://gonodes.log. Useful for diagnosing exported apps.")
	_log_to_file_check = CheckButton.new()
	_log_to_file_check.button_pressed = GNSettings.get_value("log_to_file", false)
	_log_to_file_check.toggled.connect(func(val: bool):
		GNSettings.set_value("log_to_file", val))
	row2.add_child(_log_to_file_check)
	_content.add_child(row2)


func _build_performance_settings() -> void:
	# Parallel cook
	var row1 := _make_row("Parallel cooking",
		"Cook independent CPU-family nodes in parallel using worker threads. Experimental — may cause instability.")
	_parallel_cook_check = CheckButton.new()
	_parallel_cook_check.button_pressed = GNSettings.get_value("parallel_cook_enabled", false)
	_parallel_cook_check.toggled.connect(func(val: bool):
		GNSettings.set_value("parallel_cook_enabled", val))
	row1.add_child(_parallel_cook_check)
	_content.add_child(row1)

	# Max cooks per frame
	var row2 := _make_row("Max cooks per frame",
		"Throttle how many nodes cook each frame. 0 = unlimited.")
	_max_cooks_spin = SpinBox.new()
	_max_cooks_spin.min_value = 0
	_max_cooks_spin.max_value = 1000
	_max_cooks_spin.step = 1
	_max_cooks_spin.value = GNSettings.get_value("max_cooks_per_frame", 0)
	_max_cooks_spin.tooltip_text = "0 = unlimited"
	_max_cooks_spin.custom_minimum_size.x = 100
	_max_cooks_spin.value_changed.connect(func(v: float):
		GNSettings.set_value("max_cooks_per_frame", int(v)))
	row2.add_child(_max_cooks_spin)
	_content.add_child(row2)


func _make_spacer(height: int) -> Control:
	var sp := Control.new()
	sp.custom_minimum_size.y = height
	return sp


func _make_row(label_text: String, tip: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.tooltip_text = tip
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 12)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(label)
	return row
