class_name GNExportDialog
extends Window
## Export dialog for building standalone GONODES applications.
##
## Presents a form with output settings (renderer, window size, fullscreen,
## VSync, FPS limit) and an output directory picker.  Kicks off a Quick Build
## via GNPatchExporter and displays progress + result.

const _GNPatchExporterScript = preload("res://addons/gonodes/core/gn_patch_exporter.gd")

## Emitted when user confirms the export.  The editor wires this to start the build.
signal export_requested(settings: Dictionary)


# ─── Renderer constants (same as gn_editor.gd) ─────────────────────────────
const _RENDERER_KEYS: PackedStringArray = ["forward_plus", "mobile", "gl_compatibility"]
const _RENDERER_LABELS: PackedStringArray = ["Forward+", "Mobile", "Compatibility"]

# ─── Controls ──────────────────────────────────────────────────────────────────
var _renderer_option: OptionButton
var _width_spin: SpinBox
var _height_spin: SpinBox
var _fullscreen_check: CheckButton
var _vsync_check: CheckButton
var _fps_spin: SpinBox
var _title_edit: LineEdit
var _output_dir_edit: LineEdit
var _browse_btn: Button
var _build_btn: Button
var _cancel_btn: Button
var _progress_label: Label
var _dir_dialog: FileDialog

## Currently active exporter (null when idle).
var _exporter: RefCounted = null

## Patch path set by the editor before showing.
var patch_path: String = ""


func _ready() -> void:
	title = "Export Patch — Quick Build"
	size = Vector2i(480, 460)
	exclusive = true
	unresizable = false

	var margin := MarginContainer.new()
	margin.anchors_preset = Control.PRESET_FULL_RECT
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# ── Renderer ─────────────────────────────────────────────────────────
	vbox.add_child(_make_label("Renderer"))
	_renderer_option = OptionButton.new()
	for lbl in _RENDERER_LABELS:
		_renderer_option.add_item(lbl)
	_renderer_option.selected = 0
	vbox.add_child(_renderer_option)

	# ── Window Title ─────────────────────────────────────────────────────
	vbox.add_child(_make_label("Window Title"))
	_title_edit = LineEdit.new()
	_title_edit.text = "GONODES Output"
	_title_edit.placeholder_text = "Window title for the exported app"
	vbox.add_child(_title_edit)

	# ── Resolution ───────────────────────────────────────────────────────
	vbox.add_child(_make_label("Resolution"))
	var res_hbox := HBoxContainer.new()
	res_hbox.add_theme_constant_override("separation", 6)
	_width_spin = _make_int_spin(1920, 128, 7680, "Width")
	_height_spin = _make_int_spin(1080, 128, 4320, "Height")
	res_hbox.add_child(_width_spin)
	var x_label := Label.new()
	x_label.text = "×"
	res_hbox.add_child(x_label)
	res_hbox.add_child(_height_spin)
	vbox.add_child(res_hbox)

	# ── Toggles row ──────────────────────────────────────────────────────
	var toggle_hbox := HBoxContainer.new()
	toggle_hbox.add_theme_constant_override("separation", 20)
	_fullscreen_check = CheckButton.new()
	_fullscreen_check.text = "Fullscreen"
	toggle_hbox.add_child(_fullscreen_check)
	_vsync_check = CheckButton.new()
	_vsync_check.text = "VSync"
	_vsync_check.button_pressed = true
	toggle_hbox.add_child(_vsync_check)
	vbox.add_child(toggle_hbox)

	# ── FPS Limit ────────────────────────────────────────────────────────
	var fps_hbox := HBoxContainer.new()
	fps_hbox.add_theme_constant_override("separation", 6)
	fps_hbox.add_child(_make_label("FPS Limit (0 = unlimited)"))
	_fps_spin = _make_int_spin(0, 0, 240, "FPS")
	fps_hbox.add_child(_fps_spin)
	vbox.add_child(fps_hbox)

	# ── Output Directory ─────────────────────────────────────────────────
	vbox.add_child(_make_label("Output Directory"))
	var dir_hbox := HBoxContainer.new()
	dir_hbox.add_theme_constant_override("separation", 4)
	_output_dir_edit = LineEdit.new()
	_output_dir_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output_dir_edit.placeholder_text = "Choose output folder..."
	dir_hbox.add_child(_output_dir_edit)
	_browse_btn = Button.new()
	_browse_btn.text = "Browse…"
	_browse_btn.pressed.connect(_on_browse_pressed)
	dir_hbox.add_child(_browse_btn)
	vbox.add_child(dir_hbox)

	# ── Progress ─────────────────────────────────────────────────────────
	_progress_label = Label.new()
	_progress_label.text = ""
	_progress_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_progress_label)

	# ── Buttons ──────────────────────────────────────────────────────────
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 10)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_END
	_cancel_btn = Button.new()
	_cancel_btn.text = "Cancel"
	_cancel_btn.pressed.connect(func(): hide())
	btn_hbox.add_child(_cancel_btn)
	_build_btn = Button.new()
	_build_btn.text = "Build"
	_build_btn.pressed.connect(_on_build_pressed)
	btn_hbox.add_child(_build_btn)
	vbox.add_child(btn_hbox)

	# ── Directory picker dialog ──────────────────────────────────────────
	_dir_dialog = FileDialog.new()
	_dir_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_dir_dialog.title = "Choose Output Directory"
	_dir_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dir_dialog.dir_selected.connect(_on_dir_selected)
	add_child(_dir_dialog)

	# Close button
	close_requested.connect(func(): hide())


# ═══════════════════════════════════════════════════════════════════════════════
# Public
# ═══════════════════════════════════════════════════════════════════════════════

## Shows the dialog, pre-filling a default output directory based on the patch.
func show_for_patch(p_patch_path: String) -> void:
	patch_path = p_patch_path
	if not patch_path.is_empty():
		var stem := patch_path.get_file().get_basename()
		var default_dir := patch_path.get_base_dir().path_join(stem + "_build")
		_output_dir_edit.text = default_dir

	# Sync renderer dropdown to current project setting
	var current: String = ProjectSettings.get_setting(
		"rendering/renderer/rendering_method", "forward_plus")
	var idx := _RENDERER_KEYS.find(current)
	if idx >= 0:
		_renderer_option.selected = idx

	_progress_label.text = ""
	_build_btn.disabled = false
	popup_centered()


## Returns the current settings as a Dictionary.
func get_export_settings() -> Dictionary:
	return {
		"renderer": _RENDERER_KEYS[_renderer_option.selected],
		"window_title": _title_edit.text,
		"window_size": Vector2i(int(_width_spin.value), int(_height_spin.value)),
		"fullscreen": _fullscreen_check.button_pressed,
		"vsync": _vsync_check.button_pressed,
		"fps_limit": int(_fps_spin.value),
		"output_dir": _output_dir_edit.text,
	}


# ═══════════════════════════════════════════════════════════════════════════════
# Callbacks
# ═══════════════════════════════════════════════════════════════════════════════

func _on_browse_pressed() -> void:
	if not _output_dir_edit.text.is_empty():
		_dir_dialog.current_dir = _output_dir_edit.text
	_dir_dialog.popup_centered(Vector2i(600, 400))


func _on_dir_selected(dir: String) -> void:
	_output_dir_edit.text = dir


func _on_build_pressed() -> void:
	var out_dir: String = _output_dir_edit.text.strip_edges()
	if out_dir.is_empty():
		_progress_label.text = "⚠ Please choose an output directory."
		_progress_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2))
		return
	if patch_path.is_empty():
		_progress_label.text = "⚠ No patch file loaded. Save your patch first."
		_progress_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2))
		return

	_build_btn.disabled = true
	_progress_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	_progress_label.text = "Starting build..."

	# Configure exporter
	_exporter = _GNPatchExporterScript.new()
	_exporter.patch_path = patch_path
	_exporter.output_dir = out_dir

	var settings := get_export_settings()
	_exporter.renderer = settings["renderer"]
	_exporter.window_title = settings["window_title"]
	_exporter.window_size = settings["window_size"]
	_exporter.fullscreen = settings["fullscreen"]
	_exporter.vsync = settings["vsync"]
	_exporter.fps_limit = settings["fps_limit"]

	_exporter.progress.connect(_on_export_progress)
	_exporter.completed.connect(_on_export_completed)

	# Run the build
	var err: int = _exporter.quick_build()
	if err != OK and _progress_label.text.begins_with("Starting"):
		# _fail already set a message via completed signal
		pass


func _on_export_progress(message: String) -> void:
	_progress_label.text = message


func _on_export_completed(success: bool, message: String) -> void:
	_build_btn.disabled = false
	if success:
		_progress_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		_progress_label.text = "✓ " + message
	else:
		_progress_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		_progress_label.text = "✗ " + message
	_exporter = null


# ═══════════════════════════════════════════════════════════════════════════════
# UI Helpers
# ═══════════════════════════════════════════════════════════════════════════════

func _make_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	return lbl


func _make_int_spin(default: int, min_val: int, max_val: int, tip: String) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.value = default
	spin.step = 1
	spin.rounded = true
	spin.tooltip_text = tip
	spin.custom_minimum_size.x = 80
	return spin
