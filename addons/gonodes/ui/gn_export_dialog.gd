class_name GNExportDialog
extends Window
## Export dialog for building standalone GONODES applications.
##
## Presents an output directory picker and kicks off a Quick Build via
## GNPatchExporter.  All runtime settings (renderer, VSync, window layout)
## are automatic — renderer uses Forward+ with OpenGL fallback, and each
## WindowOUT in the patch controls its own display window.
## Displays progress + result.

const _GNPatchExporterScript = preload("res://addons/gonodes/core/gn_patch_exporter.gd")

## Emitted when user confirms the export.  The editor wires this to start the build.
signal export_requested(settings: Dictionary)


# ─── Controls ──────────────────────────────────────────────────────────────────
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
	size = Vector2i(480, 200)
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

	_progress_label.text = ""
	_build_btn.disabled = false
	popup_centered()


## Returns the current settings as a Dictionary.
func get_export_settings() -> Dictionary:
	return {
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
