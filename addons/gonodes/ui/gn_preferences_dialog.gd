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
var _renderer_option: OptionButton = null
var _audio_out_option: OptionButton = null
var _interface_scale_option: OptionButton = null
var _wrap_sticky_notes_check: CheckButton = null
var _side_panel_min_spin: SpinBox = null
var _ref_reads_check: CheckButton = null
var _ref_writes_check: CheckButton = null
var _ref_runtime_check: CheckButton = null
var _ref_wireless_check: CheckButton = null
var _ref_read_color_picker: ColorPickerButton = null
var _ref_write_color_picker: ColorPickerButton = null
var _ref_runtime_color_picker: ColorPickerButton = null
var _ref_wireless_color_picker: ColorPickerButton = null
var _inspector_deps_check: CheckButton = null
var _annotation_manager: GNAnnotationManager = null
const _INTERFACE_SCALE_PERCENTS: Array[int] = [100, 125, 150, 175, 200]
const _ExtensionsPanelScript := preload("res://addons/gonodes/ui/gn_extensions_panel.gd")
const _AssetBrowserScript := preload("res://addons/gonodes/ui/gn_asset_browser.gd")

var _extensions_panel: Window = null
var _asset_browser: Window = null


func set_annotation_manager(mgr: GNAnnotationManager) -> void:
	_annotation_manager = mgr


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
	_build_section_header("Renderer")
	_build_renderer_settings()

	_build_section_header("Interface")
	_build_interface_settings()

	_build_section_header("General")
	_build_general_settings()

	_build_section_header("Preview")
	_build_preview_settings()

	_build_section_header("Graph Editor")
	_build_graph_settings()

	_build_section_header("Graph References")
	_build_graph_reference_settings()

	_build_section_header("Viewer")
	_build_viewer_settings()

	_build_section_header("Logging")
	_build_log_settings()

	_build_section_header("Audio")
	_build_audio_settings()

	_build_section_header("Performance")
	_build_performance_settings()

	_build_section_header("Extensions & Assets")
	_build_extensions_settings()

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


const _RENDERER_IDS := ["forward_plus", "mobile", "gl_compatibility"]
const _RENDERER_LABELS := ["Forward+", "Mobile", "Compatibility (OpenGL)"]

func _build_renderer_settings() -> void:
	var current := GNGpuContext.get_current_renderer()
	var row := _make_row("Rendering method",
		"GPU rendering backend. Requires restart to take effect.")
	_renderer_option = OptionButton.new()
	for i in _RENDERER_LABELS.size():
		_renderer_option.add_item(_RENDERER_LABELS[i], i)
	var cur_idx := _RENDERER_IDS.find(current)
	if cur_idx < 0:
		cur_idx = 0
	_renderer_option.selected = cur_idx
	_renderer_option.custom_minimum_size.x = 180
	_renderer_option.item_selected.connect(func(idx: int):
		var chosen: String = _RENDERER_IDS[idx]
		if chosen != current:
			GNSettings.set_value("renderer", chosen)
			_prompt_renderer_restart(chosen))
	row.add_child(_renderer_option)
	_content.add_child(row)

	var note := Label.new()
	note.text = "Current: %s" % _RENDERER_LABELS[cur_idx]
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_content.add_child(note)


func _prompt_renderer_restart(new_renderer: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Restart Required"
	dialog.dialog_text = "Switching to '%s' requires a restart.\nRestart now?" % new_renderer
	dialog.ok_button_text = "Restart"
	dialog.add_cancel_button("Later")
	dialog.confirmed.connect(func():
		var exe := OS.get_executable_path()
		var args := OS.get_cmdline_args()
		# Remove any existing --rendering-method pair from args
		var clean_args: PackedStringArray = []
		var skip_next := false
		for a in args:
			if skip_next:
				skip_next = false
				continue
			if a == "--rendering-method":
				skip_next = true
				continue
			clean_args.append(a)
		clean_args.append_array(["--rendering-method", new_renderer])
		OS.create_process(exe, clean_args)
		get_tree().quit(0))
	add_child(dialog)
	dialog.popup_centered()


func _build_interface_settings() -> void:
	var row := _make_row("Interface scale",
		"Scale the entire GONODES editor UI. Does not affect the Godot editor chrome.")
	_interface_scale_option = OptionButton.new()
	for i in _INTERFACE_SCALE_PERCENTS.size():
		var pct: int = _INTERFACE_SCALE_PERCENTS[i]
		_interface_scale_option.add_item("%d%%" % pct, i)
	var current_pct: int = GNUiPrefs.get_interface_scale_percent()
	var sel_idx := _INTERFACE_SCALE_PERCENTS.find(current_pct)
	if sel_idx < 0:
		sel_idx = 0
	_interface_scale_option.selected = sel_idx
	_interface_scale_option.custom_minimum_size.x = 120
	_interface_scale_option.item_selected.connect(func(idx: int) -> void:
		var chosen: int = _INTERFACE_SCALE_PERCENTS[idx]
		GNUiPrefs.set_interface_scale_percent(chosen)
		GNUiPrefs.apply_interface_scale(get_tree()))
	row.add_child(_interface_scale_option)
	_content.add_child(row)

	var wrap_row := _make_row("Wrap sticky notes",
		"Notes grow so wrapped text stays inside the box.")
	_wrap_sticky_notes_check = CheckButton.new()
	_wrap_sticky_notes_check.button_pressed = GNUiPrefs.get_wrap_sticky_notes()
	_wrap_sticky_notes_check.toggled.connect(func(val: bool) -> void:
		GNUiPrefs.set_wrap_sticky_notes(val)
		if _annotation_manager != null:
			_annotation_manager.refit_sticky_notes())
	wrap_row.add_child(_wrap_sticky_notes_check)
	_content.add_child(wrap_row)

	var side_row := _make_row("Side panel minimum width",
		"Smallest width of the viewer and parameter column. 260 is the current size. The preset buttons keep their labels and move to the next line if the column is narrower than they are.")
	_side_panel_min_spin = SpinBox.new()
	_side_panel_min_spin.min_value = GNUiPrefs.SIDE_PANEL_MIN_WIDTH_MIN
	_side_panel_min_spin.max_value = GNUiPrefs.SIDE_PANEL_MIN_WIDTH_MAX
	_side_panel_min_spin.step = 10
	_side_panel_min_spin.value = GNUiPrefs.get_side_panel_min_width()
	_side_panel_min_spin.suffix = " px"
	_side_panel_min_spin.custom_minimum_size.x = 100
	_side_panel_min_spin.value_changed.connect(func(v: float) -> void:
		GNUiPrefs.set_side_panel_min_width(int(v))
		if get_tree() == null:
			return
		for node in get_tree().get_nodes_in_group("gn_side_panel_width"):
			if node.has_method("apply_side_panel_min_width"):
				node.apply_side_panel_min_width())
	side_row.add_child(_side_panel_min_spin)
	_content.add_child(side_row)

	var note := Label.new()
	note.text = "Higher scale makes the interface larger and shows less of the graph."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	_content.add_child(note)


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


func _build_graph_reference_settings() -> void:
	_ref_reads_check = _build_ref_toggle_row(
			"Show read references",
			"Cyan dashed lines: expression/script reads (source → consumer).",
			"graph_ref_reads_visible", true)
	_ref_writes_check = _build_ref_toggle_row(
			"Show static write references",
			"Orange dotted lines: set_par(), network_connect(), and # @affects (writer → target).",
			"graph_ref_writes_visible", true)
	_ref_runtime_check = _build_ref_toggle_row(
			"Show runtime write references",
			"Red/orange lines from the last cook's set_par / network_connect side effects.",
			"graph_ref_runtime_writes_visible", true)
	_ref_wireless_check = _build_ref_toggle_row(
			"Show wireless hover references",
			"Amber lines when hovering a node with node_ref parameters.",
			"graph_ref_wireless_hover_visible", true)
	_inspector_deps_check = _build_ref_toggle_row(
			"Show dependency panel in inspector",
			"Reads, writes, wired inputs, and referenced-by list on the selected node.",
			"graph_inspector_deps_visible", true)

	_ref_read_color_picker = _build_ref_color_row(
			"Read line color", "graph_ref_read_color", Color(0.2, 0.85, 0.95, 0.55))
	_ref_write_color_picker = _build_ref_color_row(
			"Static write line color", "graph_ref_write_color", Color(1.0, 0.55, 0.15, 0.55))
	_ref_runtime_color_picker = _build_ref_color_row(
			"Runtime write line color", "graph_ref_runtime_color", Color(1.0, 0.35, 0.2, 0.65))
	_ref_wireless_color_picker = _build_ref_color_row(
			"Wireless hover line color", "graph_ref_wireless_color", Color(1.0, 0.65, 0.1, 0.45))


func _build_ref_toggle_row(label_text: String, tip: String,
		setting_key: String, default_val: bool) -> CheckButton:
	var row := _make_row(label_text, tip)
	var check := CheckButton.new()
	check.button_pressed = GNSettings.get_value(setting_key, default_val)
	check.toggled.connect(func(val: bool) -> void:
		GNSettings.set_value(setting_key, val))
	row.add_child(check)
	_content.add_child(row)
	return check


func _build_ref_color_row(label_text: String, setting_key: String,
		default_color: Color) -> ColorPickerButton:
	var row := _make_row(label_text, "Overlay line color.")
	var picker := ColorPickerButton.new()
	picker.color = GNSettings.get_value(setting_key, default_color)
	picker.custom_minimum_size = Vector2(60, 24)
	picker.edit_alpha = true
	picker.color_changed.connect(func(c: Color) -> void:
		GNSettings.set_value(setting_key, c))
	row.add_child(picker)
	_content.add_child(row)
	return picker


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


func _build_audio_settings() -> void:
	var row := _make_row("Output device",
		"Global speaker/headphones for GONODES. Re-select after plugging a new device — restart is rarely needed if you refresh here.")
	_audio_out_option = OptionButton.new()
	_audio_out_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_populate_audio_out_option()
	_audio_out_option.item_selected.connect(_on_audio_out_selected)
	row.add_child(_audio_out_option)
	_content.add_child(row)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	var tip := Label.new()
	tip.text = "Tip: switching OS default speakers while Godot runs can mute audio until you re-pick the device."
	tip.add_theme_font_size_override("font_size", 11)
	tip.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(tip)
	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.tooltip_text = "Re-scan devices and re-apply the selected output"
	refresh_btn.pressed.connect(_on_audio_refresh_pressed)
	row2.add_child(refresh_btn)
	_content.add_child(row2)


func _populate_audio_out_option() -> void:
	if _audio_out_option == null:
		return
	_audio_out_option.clear()
	var menu := GNAudioDevices.output_menu()
	for i in menu.size():
		_audio_out_option.add_item(menu[i], i)
	var pref: String = str(GNSettings.get_value("audio_output_device", "Default"))
	var sel := 0
	for i in menu.size():
		if menu[i] == pref:
			sel = i
			break
	_audio_out_option.select(sel)


func _on_audio_out_selected(idx: int) -> void:
	var menu := GNAudioDevices.output_menu()
	if idx < 0 or idx >= menu.size():
		return
	GNAudioDevices.set_preferred_output(menu[idx])


func _on_audio_refresh_pressed() -> void:
	_populate_audio_out_option()
	var idx: int = _audio_out_option.selected if _audio_out_option != null else 0
	_on_audio_out_selected(idx)


func _build_extensions_settings() -> void:
	var note := Label.new()
	note.text = "Manage optional extension packs and custom .gnasset operators. Native GDExtension DLLs require a Godot restart."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	_content.add_child(note)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var ext_btn := Button.new()
	ext_btn.text = "Extensions…"
	ext_btn.tooltip_text = "List extensions, load .pck packs, enable or disable folders"
	ext_btn.pressed.connect(_open_extensions_panel)
	row.add_child(ext_btn)
	var asset_btn := Button.new()
	asset_btn.text = "Asset Browser…"
	asset_btn.tooltip_text = "Browse, install, or uninstall .gnasset custom operators"
	asset_btn.pressed.connect(_open_asset_browser)
	row.add_child(asset_btn)
	_content.add_child(row)


func _open_extensions_panel() -> void:
	if _extensions_panel == null:
		_extensions_panel = _ExtensionsPanelScript.new()
		add_child(_extensions_panel)
	_extensions_panel.popup_centered()


func _open_asset_browser() -> void:
	if _asset_browser == null or not is_instance_valid(_asset_browser):
		_asset_browser = _AssetBrowserScript.new()
		# Keep it out of this exclusive dialog. A child of an exclusive window
		# cannot be dismissed while that dialog is holding the screen.
		get_tree().root.add_child(_asset_browser)
	_asset_browser.size = Vector2i(720, 520)
	_asset_browser.popup_centered()


func _notification(what: int) -> void:
	# Refresh device list whenever the dialog is shown (devices may have changed).
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_populate_audio_out_option()


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
