class_name GNPythonCodeEditor
extends "res://addons/gonodes/ui/gn_base_code_editor.gd"
## Python code editor for UserPython operators.
## Subclasses GNBaseCodeEditor with Python syntax highlighting,
## reload button, template/example menus, and error display.

signal code_committed(text: String)
signal reload_requested(source_code: String)


# ─── Internal State ───────────────────────────────────────────────────────────

var _owner_node = null
var _family: String = ""

# ─── Toolbar Widgets ──────────────────────────────────────────────────────────

var _reload_btn: Button = null
var _template_menu_btn: MenuButton = null
var _examples_menu_btn: MenuButton = null
var _preset_menu_btn: MenuButton = null
var _save_preset_btn: Button = null
var _help_btn: Button = null
var _ref_label: Label = null

# ─── Output Panel ────────────────────────────────────────────────────────────

var _output_toggle: Button = null
var _output_panel: RichTextLabel = null
var _apply_btn: Button = null

# ─── Presets ──────────────────────────────────────────────────────────────────

var _preset_entries: Array = []

# ─── Error Line Markers ──────────────────────────────────────────────────────

var _error_lines: Array[int] = []

# ─── Paths ────────────────────────────────────────────────────────────────────

const _TEMPLATES_DIR := "res://addons/gn_ext_user_python/templates/"
const _EXAMPLES_DIR := "res://addons/gn_ext_user_python/examples/"
const _HELP_DOC := "res://addons/gn_ext_user_python/help/user_python.md"


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	super()
	title = "Python Editor"
	size = Vector2i(900, 700)
	min_size = Vector2i(600, 400)
	exclusive = false


func _ready() -> void:
	super._ready()

	_ok_btn.text = "Reload & Apply"
	_ok_btn.tooltip_text = "Apply code and reload Python (Ctrl+Enter)"

	_apply_btn = Button.new()
	_apply_btn.text = "Apply"
	_apply_btn.custom_minimum_size = Vector2(80, 30)
	_apply_btn.tooltip_text = "Apply code without reloading"
	_apply_btn.pressed.connect(_on_apply)
	var btn_row := _ok_btn.get_parent()
	btn_row.add_child(_apply_btn)
	btn_row.move_child(_apply_btn, _ok_btn.get_index())

	var btn_row_idx := btn_row.get_index()

	_output_toggle = Button.new()
	_output_toggle.text = "\u25B6 Python Output"
	_output_toggle.flat = true
	_output_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_output_toggle.pressed.connect(_toggle_output)
	_vbox.add_child(_output_toggle)
	_vbox.move_child(_output_toggle, btn_row_idx)

	_output_panel = RichTextLabel.new()
	_output_panel.bbcode_enabled = true
	_output_panel.fit_content = false
	_output_panel.custom_minimum_size = Vector2(0, 120)
	_output_panel.scroll_following = true
	_output_panel.visible = false
	_output_panel.add_theme_font_size_override("normal_font_size", 12)
	_vbox.add_child(_output_panel)
	_vbox.move_child(_output_panel, btn_row_idx + 1)


# ═══════════════════════════════════════════════════════════════════════════════
# GNBaseCodeEditor Overrides
# ═══════════════════════════════════════════════════════════════════════════════

func _build_toolbar(parent: VBoxContainer) -> void:
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 4)
	parent.add_child(toolbar)

	# Reload
	_reload_btn = Button.new()
	_reload_btn.text = "Reload (Ctrl+R)"
	_reload_btn.tooltip_text = "Reload Python script"
	_reload_btn.custom_minimum_size = Vector2(120, 28)
	_reload_btn.pressed.connect(_on_reload_pressed)
	toolbar.add_child(_reload_btn)

	toolbar.add_child(VSeparator.new())

	# Templates
	_template_menu_btn = MenuButton.new()
	_template_menu_btn.text = "Templates \u25BE"
	_template_menu_btn.tooltip_text = "Load a minimal starter template"
	_template_menu_btn.custom_minimum_size = Vector2(95, 28)
	_template_menu_btn.flat = false
	_template_menu_btn.get_popup().index_pressed.connect(_on_template_selected)
	toolbar.add_child(_template_menu_btn)

	# Examples
	_examples_menu_btn = MenuButton.new()
	_examples_menu_btn.text = "Examples \u25BE"
	_examples_menu_btn.tooltip_text = "Load a fully-worked example"
	_examples_menu_btn.custom_minimum_size = Vector2(90, 28)
	_examples_menu_btn.flat = false
	_examples_menu_btn.get_popup().index_pressed.connect(_on_example_selected)
	toolbar.add_child(_examples_menu_btn)

	toolbar.add_child(VSeparator.new())

	# Preset Load
	_preset_menu_btn = MenuButton.new()
	_preset_menu_btn.text = "Presets \u25BE"
	_preset_menu_btn.tooltip_text = "Load a saved preset"
	_preset_menu_btn.custom_minimum_size = Vector2(85, 28)
	_preset_menu_btn.flat = false
	_preset_menu_btn.get_popup().about_to_popup.connect(_build_preset_menu)
	_preset_menu_btn.get_popup().id_pressed.connect(_on_preset_selected)
	toolbar.add_child(_preset_menu_btn)

	# Preset Save
	_save_preset_btn = Button.new()
	_save_preset_btn.text = "Save Preset\u2026"
	_save_preset_btn.tooltip_text = "Save current code as a user preset"
	_save_preset_btn.custom_minimum_size = Vector2(100, 28)
	_save_preset_btn.pressed.connect(_on_save_preset_pressed)
	toolbar.add_child(_save_preset_btn)

	toolbar.add_child(VSeparator.new())

	# Help
	_help_btn = Button.new()
	_help_btn.text = "Help \u2753"
	_help_btn.tooltip_text = "Open Python SDK reference and editor help"
	_help_btn.custom_minimum_size = Vector2(70, 28)
	_help_btn.pressed.connect(_on_help_pressed)
	toolbar.add_child(_help_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	# SDK quick-reference
	_ref_label = Label.new()
	_ref_label.add_theme_font_size_override("font_size", 10)
	_ref_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_ref_label.text = ""
	toolbar.add_child(_ref_label)


func _setup_code_edit(edit: CodeEdit) -> void:
	edit.minimap_draw = true
	edit.minimap_width = 80
	_setup_python_highlighting(edit)


func _on_ok() -> void:
	code_committed.emit(_code_edit.text)
	_on_reload_pressed()


func _on_cancel() -> void:
	hide()


# ═══════════════════════════════════════════════════════════════════════════════
# Key Bindings — Ctrl+R = Reload
# ═══════════════════════════════════════════════════════════════════════════════

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and event.ctrl_pressed:
			_on_reload_pressed()
			get_viewport().set_input_as_handled()
			return
	super._unhandled_key_input(event)


# ═══════════════════════════════════════════════════════════════════════════════
# Public API
# ═══════════════════════════════════════════════════════════════════════════════

func open(node, initial_code: String) -> void:
	_owner_node = node
	_family = _detect_family(node)

	if node:
		title = "Python Editor \u2014 %s [%s]" % [node.id, _family.to_upper()]
		_info_label.text = "%s  |  %s  |  %s" % [node.id, _family.to_upper(), node.node_type]
	else:
		title = "Python Editor"
		_info_label.text = ""

	_update_ref_label()
	_populate_template_menu()
	_populate_examples_menu()

	_code_edit.text = initial_code
	_code_edit.clear_undo_history()
	_clear_error_marks()
	_set_status("Ctrl+R = Reload  |  Ctrl+Enter = Reload & Apply  |  Escape = Cancel")

	popup_centered()
	_focus_end()


func set_error(error_text: String) -> void:
	_clear_error_marks()
	if error_text.is_empty():
		_set_status("\u2713 Script loaded", Color(0.3, 1.0, 0.4))
	else:
		_set_status("\u2717 Error \u2014 %s" % error_text.get_slice("\n", 0),
			Color(1.0, 0.35, 0.3))
		_mark_python_error_lines(error_text)
		_output_panel.text = ""
		_output_panel.append_text("[code]%s[/code]" % error_text)
		_output_panel.visible = true
		_output_toggle.text = "\u25BC Python Output"


# ═══════════════════════════════════════════════════════════════════════════════
# Python Syntax Highlighting — Consistent GONODES colour palette
# ═══════════════════════════════════════════════════════════════════════════════

func _setup_python_highlighting(edit: CodeEdit) -> void:
	var h := CodeHighlighter.new()
	h.number_color = Color(0.72, 0.86, 0.56)

	# Strings
	h.add_color_region("\"\"\"", "\"\"\"", Color(0.87, 0.72, 0.45))
	h.add_color_region("'''", "'''", Color(0.87, 0.72, 0.45))
	h.add_color_region("\"", "\"", Color(0.87, 0.72, 0.45))
	h.add_color_region("'", "'", Color(0.87, 0.72, 0.45))

	# Comments
	h.add_color_region("#", "", Color(0.45, 0.45, 0.45), true)

	# Python keywords — control flow (pink)
	for kw in ["and", "as", "assert", "async", "await", "break", "class",
			"continue", "def", "del", "elif", "else", "except", "finally",
			"for", "from", "global", "if", "import", "in", "is", "lambda",
			"nonlocal", "not", "or", "pass", "raise", "return", "try",
			"while", "with", "yield"]:
		h.add_keyword_color(kw, Color(0.95, 0.5, 0.6))

	# Python built-in types (cyan)
	for kw in ["int", "float", "str", "bool", "list", "dict", "tuple", "set",
			"bytes", "bytearray", "None", "True", "False", "type", "object",
			"range", "enumerate", "zip", "map", "filter", "sorted", "reversed",
			"len", "abs", "min", "max", "sum", "round", "print"]:
		h.add_keyword_color(kw, Color(0.5, 0.85, 0.95))

	# NumPy (green — like GONODES SDK helpers)
	for kw in ["np", "numpy", "ndarray", "array", "zeros", "ones", "empty",
			"linspace", "arange", "meshgrid", "reshape", "ravel", "flatten",
			"ascontiguousarray", "astype", "dtype", "float32", "uint8", "int32",
			"clip", "where", "concatenate", "stack", "hstack", "vstack"]:
		h.add_keyword_color(kw, Color(0.4, 0.9, 0.5))

	# GONODES SDK functions (green)
	for kw in ["make_sop_result", "make_point_cloud", "get_input_positions",
			"get_input_normals",
			"make_chop_result", "make_chop_single", "get_input_channel",
			"get_input_value",
			"make_img_result", "get_input_image",
			"make_top_result",
			"make_dat_result", "get_input_table", "get_input_text",
			"port", "input_port", "output_port",
			"param", "float_param", "int_param", "bool_param",
			"string_param", "color_param", "enum_param",
			"get_port_definitions", "get_param_definitions",
			"setup", "cook"]:
		h.add_keyword_color(kw, Color(0.4, 0.9, 0.5))

	# Math functions (blue)
	for kw in ["sin", "cos", "tan", "arcsin", "arccos", "arctan", "arctan2",
			"sqrt", "exp", "log", "log2", "log10", "floor", "ceil",
			"pi", "tau", "inf", "nan", "cross", "dot", "norm"]:
		h.add_keyword_color(kw, Color(0.6, 0.7, 0.95))

	# Decorators (purple — like C++ preprocessor)
	h.add_color_region("@", "", Color(0.7, 0.5, 0.8), true)

	h.symbol_color = Color(0.7, 0.7, 0.7)
	h.function_color = Color(0.5, 0.85, 0.95)
	h.member_variable_color = Color(0.85, 0.85, 0.75)
	edit.syntax_highlighter = h


# ═══════════════════════════════════════════════════════════════════════════════
# Reload
# ═══════════════════════════════════════════════════════════════════════════════

func _on_reload_pressed() -> void:
	_set_status("Reloading\u2026", Color(1.0, 0.8, 0.2))
	_reload_btn.disabled = true
	reload_requested.emit(_code_edit.text)
	get_tree().create_timer(0.3).timeout.connect(
		func():
			_reload_btn.disabled = false
			if _owner_node != null and _owner_node._load_error.is_empty():
				set_error("")
			elif _owner_node != null:
				set_error(_owner_node._load_error),
		CONNECT_ONE_SHOT)


func _on_apply() -> void:
	code_committed.emit(_code_edit.text)
	_set_status("Applied", Color(0.4, 0.9, 0.5))


# ═══════════════════════════════════════════════════════════════════════════════
# Error Line Markers — Python traceback format
# ═══════════════════════════════════════════════════════════════════════════════

func _clear_error_marks() -> void:
	for line_idx in _error_lines:
		if line_idx < _code_edit.get_line_count():
			_code_edit.set_line_background_color(line_idx, Color(0, 0, 0, 0))
	_error_lines.clear()


func _mark_python_error_lines(output: String) -> void:
	# Python traceback:  File "script.py", line 42, in cook
	var re := RegEx.new()
	re.compile("line\\s+(\\d+)")

	var error_bg := Color(0.5, 0.15, 0.15, 0.3)
	for line in output.split("\n"):
		var m := re.search(line)
		if m != null:
			var line_num := int(m.get_string(1))
			if line_num > 0 and line_num <= _code_edit.get_line_count():
				var idx := line_num - 1
				if idx not in _error_lines:
					_code_edit.set_line_background_color(idx, error_bg)
					_error_lines.append(idx)

	if not _error_lines.is_empty():
		_code_edit.set_caret_line(_error_lines[_error_lines.size() - 1])


# ═══════════════════════════════════════════════════════════════════════════════
# Output Panel
# ═══════════════════════════════════════════════════════════════════════════════

func _toggle_output() -> void:
	_output_panel.visible = not _output_panel.visible
	_output_toggle.text = ("\u25BC " if _output_panel.visible else "\u25B6 ") + "Python Output"


# ═══════════════════════════════════════════════════════════════════════════════
# Templates & Examples — family-first sorting with separators
# ═══════════════════════════════════════════════════════════════════════════════

func _populate_template_menu() -> void:
	var popup := _template_menu_btn.get_popup()
	popup.clear()
	if not DirAccess.dir_exists_absolute(_TEMPLATES_DIR):
		popup.add_item("(no templates)", 0)
		popup.set_item_disabled(0, true)
		return

	var dir := DirAccess.open(_TEMPLATES_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var family_first: Array[String] = []
	var others: Array[String] = []
	var fname := dir.get_next()
	while not fname.is_empty():
		if fname.ends_with(".py"):
			if _family in fname:
				family_first.append(fname)
			else:
				others.append(fname)
		fname = dir.get_next()

	if family_first.is_empty() and others.is_empty():
		popup.add_item("(no templates)", 0)
		popup.set_item_disabled(0, true)
		return

	var idx := 0
	if not family_first.is_empty():
		popup.add_separator(_family.to_upper() + " Templates")
		for f in family_first:
			popup.add_item(f.get_basename().capitalize(), idx)
			popup.set_item_metadata(idx, _TEMPLATES_DIR + f)
			idx += 1
	if not others.is_empty():
		popup.add_separator("Other Families")
		for f in others:
			popup.add_item(f.get_basename().capitalize(), idx)
			popup.set_item_metadata(idx, _TEMPLATES_DIR + f)
			idx += 1


func _populate_examples_menu() -> void:
	var popup := _examples_menu_btn.get_popup()
	popup.clear()
	if not DirAccess.dir_exists_absolute(_EXAMPLES_DIR):
		popup.add_item("(no examples)", 0)
		popup.set_item_disabled(0, true)
		return

	var dir := DirAccess.open(_EXAMPLES_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var family_first: Array[String] = []
	var others: Array[String] = []
	var fname := dir.get_next()
	while not fname.is_empty():
		if fname.ends_with(".py"):
			if _family in fname:
				family_first.append(fname)
			else:
				others.append(fname)
		fname = dir.get_next()

	if family_first.is_empty() and others.is_empty():
		popup.add_item("(no examples)", 0)
		popup.set_item_disabled(0, true)
		return

	var idx := 0
	if not family_first.is_empty():
		popup.add_separator(_family.to_upper() + " Examples")
		for f in family_first:
			popup.add_item(f.get_basename().capitalize(), idx)
			popup.set_item_metadata(idx, _EXAMPLES_DIR + f)
			idx += 1
	if not others.is_empty():
		popup.add_separator("Other Families")
		for f in others:
			popup.add_item(f.get_basename().capitalize(), idx)
			popup.set_item_metadata(idx, _EXAMPLES_DIR + f)
			idx += 1


func _on_template_selected(idx: int) -> void:
	var popup := _template_menu_btn.get_popup()
	if idx >= popup.get_item_count():
		return
	var path = popup.get_item_metadata(idx)
	if path == null or str(path).is_empty():
		return
	var code := _load_file(str(path))
	if code.is_empty():
		_set_status("Failed to load template", Color(1.0, 0.35, 0.3))
		return
	_code_edit.text = code
	_code_edit.clear_undo_history()
	_clear_error_marks()
	_set_status("Loaded template: %s" % str(path).get_file().get_basename(),
		Color(0.4, 0.9, 0.5))


func _on_example_selected(idx: int) -> void:
	var popup := _examples_menu_btn.get_popup()
	if idx >= popup.get_item_count():
		return
	var path = popup.get_item_metadata(idx)
	if path == null or str(path).is_empty():
		return
	var code := _load_file(str(path))
	if code.is_empty():
		_set_status("Failed to load example", Color(1.0, 0.35, 0.3))
		return
	_code_edit.text = code
	_code_edit.clear_undo_history()
	_clear_error_marks()
	_set_status("Loaded example: %s" % str(path).get_file().get_basename(),
		Color(0.4, 0.9, 0.5))


# ═══════════════════════════════════════════════════════════════════════════════
# Presets — via GNScriptHelper
# ═══════════════════════════════════════════════════════════════════════════════
# Preset System (via GNScriptHelper)
# ═══════════════════════════════════════════════════════════════════════════════

func _get_preset_folder() -> String:
	return "python"


func _build_preset_menu() -> void:
	var popup := _preset_menu_btn.get_popup()
	popup.clear()
	_preset_entries.clear()

	var presets := GNScriptHelper.get_preset_list(_get_preset_folder())
	if presets.is_empty():
		popup.add_item("(no presets \u2014 use Save Preset\u2026)", 0)
		popup.set_item_disabled(0, true)
		return

	var factory_items: Array = []
	var user_items: Array = []
	for entry in presets:
		if entry["is_factory"]:
			factory_items.append(entry)
		else:
			user_items.append(entry)

	var idx := 0
	if not factory_items.is_empty():
		popup.add_separator("Factory")
		for entry in factory_items:
			popup.add_item(entry["name"], idx)
			_preset_entries.append(entry)
			idx += 1
	if not user_items.is_empty():
		popup.add_separator("User")
		for entry in user_items:
			popup.add_item(entry["name"], idx)
			_preset_entries.append(entry)
			idx += 1


func _on_preset_selected(id_val: int) -> void:
	if id_val < 0 or id_val >= _preset_entries.size():
		return
	var entry: Dictionary = _preset_entries[id_val]
	var code := GNScriptHelper.load_preset(entry["path"])
	if code.is_empty():
		_set_status("Failed to load preset: %s" % entry["path"], Color(1.0, 0.35, 0.3))
		return
	_code_edit.text = code
	_code_edit.clear_undo_history()
	_clear_error_marks()
	_set_status("Loaded preset: %s" % entry["name"], Color(0.4, 0.9, 0.5))


func _on_save_preset_pressed() -> void:
	var code := _code_edit.text.strip_edges()
	if code.is_empty():
		_set_status("Nothing to save \u2014 editor is empty.", Color(1.0, 0.7, 0.3))
		return

	var dlg := AcceptDialog.new()
	dlg.title = "Save Preset"
	dlg.size = Vector2i(360, 130)
	dlg.exclusive = true
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = "Preset name:"
	lbl.add_theme_font_size_override("font_size", 13)
	vb.add_child(lbl)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "my_python_preset"
	name_edit.custom_minimum_size = Vector2(300, 0)
	vb.add_child(name_edit)
	dlg.add_child(vb)
	dlg.ok_button_text = "Save"
	var captured_code := code
	dlg.confirmed.connect(func() -> void:
		var preset_name := name_edit.text.strip_edges()
		if preset_name.is_empty():
			return
		var sanitized := ""
		for ch in preset_name:
			if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") \
					or (ch >= "0" and ch <= "9") or ch == "_":
				sanitized += ch
			else:
				sanitized += "_"
		if sanitized.is_empty():
			return
		var ok := GNScriptHelper.save_preset(_get_preset_folder(), sanitized, captured_code, ".py")
		if ok:
			_set_status("Saved preset: %s" % sanitized, Color(0.4, 0.9, 0.5))
		else:
			_set_status("Failed to save preset.", Color(1.0, 0.35, 0.3))
		dlg.queue_free()
	)
	dlg.canceled.connect(func() -> void: dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()
	name_edit.grab_focus()


# ═══════════════════════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════════════════════

func _load_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text


func _detect_family(node) -> String:
	if node == null:
		return "sop"
	var nt: String = node.node_type if node.has("node_type") else ""
	if "sop" in nt: return "sop"
	if "chop" in nt: return "chop"
	if "img" in nt: return "img"
	if "top" in nt: return "top"
	if "dat" in nt: return "dat"
	return "sop"


func _update_ref_label() -> void:
	if _ref_label == null:
		return
	match _family:
		"sop":
			_ref_label.text = "SDK: gonodes.sop | make_sop_result(positions, normals, uvs, colors)"
		"chop":
			_ref_label.text = "SDK: gonodes.chop | make_chop_result(channels, sample_rate)"
		"img":
			_ref_label.text = "SDK: gonodes.img | make_img_result(pixels, width, height)"
		"top":
			_ref_label.text = "SDK: gonodes.top | make_top_result(pixels, width, height)"
		"dat":
			_ref_label.text = "SDK: gonodes.dat | make_dat_result(rows, header) or text"
		_:
			_ref_label.text = ""


func _focus_end() -> void:
	_code_edit.grab_focus()
	_code_edit.set_caret_line(_code_edit.get_line_count() - 1)


# ═══════════════════════════════════════════════════════════════════════════════
# Help Window — shows user_python.md in a scrollable window
# ═══════════════════════════════════════════════════════════════════════════════

func _on_help_pressed() -> void:
	var content := _load_file(_HELP_DOC)
	if content.is_empty():
		_set_status("Help doc not found: %s" % _HELP_DOC, Color(1.0, 0.7, 0.3))
		return

	var win := Window.new()
	win.title = "Python Extension — Help & SDK Reference"
	win.size = Vector2i(720, 640)
	win.min_size = Vector2i(400, 300)
	win.unresizable = false
	win.exclusive = false
	win.transient = true
	win.wrap_controls = true

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	win.add_child(margin)

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = false
	rtl.scroll_active = true
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rtl.add_theme_font_size_override("normal_font_size", 14)
	rtl.add_theme_font_size_override("bold_font_size", 15)
	rtl.add_theme_font_size_override("mono_font_size", 13)
	margin.add_child(rtl)

	# Convert Markdown headings, bold, code blocks, and inline code to BBCode
	rtl.text = _md_to_bbcode(content)

	win.close_requested.connect(func() -> void: win.queue_free())
	add_child(win)
	win.popup_centered()


## Lightweight Markdown → BBCode converter for the help viewer.
func _md_to_bbcode(md: String) -> String:
	var lines := md.split("\n")
	var bb := ""
	var in_code := false
	for line in lines:
		if line.begins_with("```"):
			if in_code:
				bb += "[/code]\n"
				in_code = false
			else:
				bb += "[code]"
				in_code = true
			continue
		if in_code:
			bb += line + "\n"
			continue

		# Headings
		if line.begins_with("### "):
			bb += "[font_size=16][b]%s[/b][/font_size]\n" % line.substr(4)
		elif line.begins_with("## "):
			bb += "\n[font_size=18][b]%s[/b][/font_size]\n" % line.substr(3)
		elif line.begins_with("# "):
			bb += "\n[font_size=22][b][color=#78C8E8]%s[/color][/b][/font_size]\n" % line.substr(2)
		elif line.begins_with("---"):
			bb += "[color=#444444]────────────────────────────────────[/color]\n"
		else:
			# Inline code: `text`
			var converted := ""
			var parts := line.split("`")
			for i in range(parts.size()):
				if i % 2 == 1:
					converted += "[code]%s[/code]" % parts[i]
				else:
					# Bold: **text**
					var bold_parts := parts[i].split("**")
					for j in range(bold_parts.size()):
						if j % 2 == 1:
							converted += "[b]%s[/b]" % bold_parts[j]
						else:
							converted += bold_parts[j]
			bb += converted + "\n"
	if in_code:
		bb += "[/code]\n"
	return bb
