class_name GNPreferencesDialog
extends Window
## Modal preferences dialog for GONODES editor settings.
##
## Reads from / writes to GNSettings.  Each control is wired to
## live-update the setting on change.  More settings will be added
## over time — the layout uses a VBoxContainer for easy extension.


var _content: VBoxContainer = null

# ─── Controls ────────────────────────────────────────────────────────────────
var _preview_height_spin: SpinBox = null
var _preview_on_create_check: CheckButton = null
var _snap_distance_spin: SpinBox = null
var _log_level_option: OptionButton = null


func _init() -> void:
	title = "GONODES Preferences"
	size = Vector2i(420, 340)
	min_size = Vector2i(360, 280)
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

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	margin.add_child(_content)

	_build_section_header("Preview")
	_build_preview_settings()

	_build_section_header("Graph Editor")
	_build_graph_settings()

	_build_section_header("Logging")
	_build_log_settings()

	# Close button at the bottom
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
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	_content.add_child(label)
	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.3)
	_content.add_child(sep)


func _build_preview_settings() -> void:
	# Preview max height
	var row1 := _make_row("Max Preview Height (px)")
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
	var row2 := _make_row("Show preview on new nodes")
	_preview_on_create_check = CheckButton.new()
	_preview_on_create_check.button_pressed = GNSettings.get_value("preview_enabled_on_create", true)
	_preview_on_create_check.toggled.connect(func(val: bool):
		GNSettings.set_value("preview_enabled_on_create", val))
	row2.add_child(_preview_on_create_check)
	_content.add_child(row2)


func _build_graph_settings() -> void:
	var row := _make_row("Snap Distance (px)")
	_snap_distance_spin = SpinBox.new()
	_snap_distance_spin.min_value = 0
	_snap_distance_spin.max_value = 100
	_snap_distance_spin.step = 5
	_snap_distance_spin.value = GNSettings.get_value("graph_snap_distance", 20)
	_snap_distance_spin.suffix = " px"
	_snap_distance_spin.custom_minimum_size.x = 100
	_snap_distance_spin.value_changed.connect(func(v: float):
		GNSettings.set_value("graph_snap_distance", int(v)))
	row.add_child(_snap_distance_spin)
	_content.add_child(row)


func _build_log_settings() -> void:
	var row := _make_row("Log Level")
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


func _make_row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 12)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row
