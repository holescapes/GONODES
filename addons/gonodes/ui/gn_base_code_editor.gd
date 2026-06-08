class_name GNBaseCodeEditor
extends Window
## Abstract base class for modal code-editing windows.
##
## Provides the common layout (CodeEdit with line numbers, info label,
## error / status bar, OK / Cancel buttons, Ctrl+Enter / Escape bindings).
## Subclasses override virtual hooks to add toolbars, customise the
## CodeEdit, and handle confirming / cancelling.
##
## Concrete subclasses:
##   • GNExpressionEditor — expressions with autocomplete, validation, snippets.
##   • GNCodeEditor       — Script operator / CustomShaderTOP code with presets.


# ─── Internal UI (accessible to subclasses) ───────────────────────────────────

## The main CodeEdit widget.
var _code_edit: CodeEdit = null

## One-line info label at the top of the window.
var _info_label: Label = null

## Status / error label below the CodeEdit.
var _error_label: RichTextLabel = null

## OK button (bottom-right).
var _ok_btn: Button = null

## Cancel button (bottom-right, left of OK).
var _cancel_btn: Button = null

## Main VBoxContainer — subclasses may reference for advanced layout.
var _vbox: VBoxContainer = null


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	title = "Code Editor"
	size = Vector2i(640, 480)
	min_size = Vector2i(400, 280)
	unresizable = false
	exclusive = true
	wrap_controls = false
	transient = true


## Clamps the window size to the current screen's usable area, then opens
## centered.  Prevents the window being taller/wider than the display on
## the very first popup (before the OS window-manager has had a chance to
## clamp it).
func _popup_clamped() -> void:
	var scr: int = DisplayServer.get_primary_screen()
	var pw := get_parent()
	while pw and not (pw is Window):
		pw = pw.get_parent()
	if pw is Window:
		scr = (pw as Window).current_screen
	var usable := DisplayServer.screen_get_usable_rect(scr)
	var max_sz := usable.size - Vector2i(20, 20)
	size = Vector2i(mini(size.x, max_sz.x), mini(size.y, max_sz.y))
	popup_centered()


func _ready() -> void:
	# Root margin container
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 8)
	root.add_theme_constant_override("margin_right", 8)
	root.add_theme_constant_override("margin_top", 8)
	root.add_theme_constant_override("margin_bottom", 8)
	add_child(root)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 6)
	root.add_child(_vbox)

	# Info label (param / node context)
	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 12)
	_info_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	_vbox.add_child(_info_label)

	# ── Subclass toolbar hook (between info label and code edit) ──────
	_build_toolbar(_vbox)

	# CodeEdit — the main editing area
	_code_edit = CodeEdit.new()
	_code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_edit.custom_minimum_size = Vector2(0, 200)
	_code_edit.add_theme_font_size_override("font_size", 14)
	_code_edit.gutters_draw_line_numbers = true
	_code_edit.scroll_smooth = true
	_code_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_code_edit.caret_blink = true
	_code_edit.highlight_current_line = true
	_code_edit.draw_tabs = true
	_code_edit.indent_automatic = true
	_code_edit.auto_brace_completion_enabled = true
	_code_edit.indent_size = 4

	# ── Subclass code-edit customisation hook ─────────────────────────
	_setup_code_edit(_code_edit)
	_vbox.add_child(_code_edit)

	# Error / status label (RichTextLabel for text selection)
	_error_label = RichTextLabel.new()
	_error_label.bbcode_enabled = false
	_error_label.scroll_active = false
	_error_label.fit_content = true
	_error_label.selection_enabled = true
	_error_label.add_theme_font_size_override("normal_font_size", 11)
	_error_label.add_theme_color_override("default_color", Color(0.5, 0.5, 0.5))
	_error_label.text = ""
	_error_label.custom_minimum_size = Vector2(0, 20)
	_vbox.add_child(_error_label)

	# Bottom button row
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	_vbox.add_child(btn_row)

	# ── Subclass bottom-bar hook (before the spacer + Cancel / OK) ────
	_build_bottom_bar(btn_row)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(spacer)

	_cancel_btn = Button.new()
	_cancel_btn.text = "Cancel"
	_cancel_btn.custom_minimum_size = Vector2(80, 30)
	_cancel_btn.pressed.connect(_on_cancel)
	btn_row.add_child(_cancel_btn)

	_ok_btn = Button.new()
	_ok_btn.text = "OK"
	_ok_btn.custom_minimum_size = Vector2(80, 30)
	_ok_btn.pressed.connect(_on_ok)
	btn_row.add_child(_ok_btn)

	close_requested.connect(_on_cancel)


# ═══════════════════════════════════════════════════════════════════════════════
# Key Bindings
# ═══════════════════════════════════════════════════════════════════════════════

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER and event.ctrl_pressed:
			_on_ok()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			_on_cancel()
			get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════════════════════
# Virtual Hooks  (override in subclasses)
# ═══════════════════════════════════════════════════════════════════════════════

## Override to add a toolbar between the info label and the CodeEdit.
func _build_toolbar(_parent: VBoxContainer) -> void:
	pass


## Override to customise the CodeEdit after creation (e.g. code completion).
func _setup_code_edit(_edit: CodeEdit) -> void:
	pass


## Override to add widgets (e.g. snippets button) to the bottom bar,
## placed before the spacer + Cancel / OK buttons.
func _build_bottom_bar(_bar: HBoxContainer) -> void:
	pass


## Override to handle the OK action (emit signal, strip text, etc.).
func _on_ok() -> void:
	hide()


## Override to handle the Cancel action.  Default just hides the window.
func _on_cancel() -> void:
	hide()


# ═══════════════════════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Moves the caret to the end of the text and grabs focus.
func _focus_end() -> void:
	_code_edit.grab_focus()
	_code_edit.set_caret_line(_code_edit.get_line_count() - 1)
	_code_edit.set_caret_column(
		_code_edit.get_line(_code_edit.get_line_count() - 1).length())


## Sets the status / error label text and color.
func _set_status(text: String, color: Color = Color(0.5, 0.5, 0.5)) -> void:
	_error_label.text = text
	_error_label.add_theme_color_override("default_color", color)
