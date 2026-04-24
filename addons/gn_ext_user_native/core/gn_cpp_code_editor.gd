class_name GNCppCodeEditor
extends "res://addons/gonodes/ui/gn_base_code_editor.gd"
## C++ code editor for UserNative operators.
## Subclasses GNBaseCodeEditor with C++ syntax highlighting,
## build button, preset system (via GNScriptHelper), and compiler output.
##
## Unified architecture: uses the same Presets + Save Preset toolbar
## pattern as GNCodeEditor (GDScript / GLSL / ISF / Shadertoy).
## Language-specific additions: Build button, compiler output panel, error markers.

signal code_committed(text: String)
signal build_requested(source_code: String)
signal check_requested(source_code: String)


# ─── Internal State ───────────────────────────────────────────────────────────

var _owner_node = null
var _family: String = ""  # sop, chop, img, top, dat

# ─── Toolbar Widgets ──────────────────────────────────────────────────────────

var _build_btn: Button = null
var _check_btn: Button = null
var _preset_menu_btn: MenuButton = null
var _save_preset_btn: Button = null
var _ref_label: Label = null

# ─── Compiler Output ─────────────────────────────────────────────────────────

var _output_toggle: Button = null
var _output_panel: RichTextLabel = null

# ─── Presets ──────────────────────────────────────────────────────────────────

var _preset_entries: Array = []

# ─── Error Line Markers ──────────────────────────────────────────────────────

var _error_lines: Array[int] = []




# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	super()
	title = "C++ Editor"
	size = Vector2i(900, 700)
	min_size = Vector2i(600, 400)
	exclusive = false  # non-modal — user can interact with the graph
	process_mode = PROCESS_MODE_ALWAYS  # override parent's PROCESS_MODE_DISABLED


func _ready() -> void:
	super._ready()

	_ok_btn.text = "Done"
	_ok_btn.tooltip_text = "Save code and close (Ctrl+Enter)"

	# Insert compiler output panel between error_label and button row
	var btn_row := _ok_btn.get_parent()
	var btn_row_idx := btn_row.get_index()

	_output_toggle = Button.new()
	_output_toggle.text = "▶ Compiler Output"
	_output_toggle.flat = true
	_output_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_output_toggle.pressed.connect(_toggle_output)
	_vbox.add_child(_output_toggle)
	_vbox.move_child(_output_toggle, btn_row_idx)

	_output_panel = RichTextLabel.new()
	_output_panel.bbcode_enabled = true
	_output_panel.selection_enabled = true
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

	# Build
	_build_btn = Button.new()
	_build_btn.text = "Build (Ctrl+B)"
	_build_btn.tooltip_text = "Compile C++ code"
	_build_btn.custom_minimum_size = Vector2(110, 28)
	_build_btn.pressed.connect(_on_build_pressed)
	toolbar.add_child(_build_btn)

	# Check (syntax only)
	_check_btn = Button.new()
	_check_btn.text = "Check (Ctrl+K)"
	_check_btn.tooltip_text = "Check C++ syntax without building"
	_check_btn.custom_minimum_size = Vector2(120, 28)
	_check_btn.pressed.connect(_on_check_pressed)
	toolbar.add_child(_check_btn)

	toolbar.add_child(VSeparator.new())

	# Preset Load
	_preset_menu_btn = MenuButton.new()
	_preset_menu_btn.text = "Presets \u25be"
	_preset_menu_btn.tooltip_text = "Load a preset script"
	_preset_menu_btn.custom_minimum_size = Vector2(90, 28)
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
	_setup_cpp_highlighting(edit)


func _on_ok() -> void:
	# Done: save code and close editor
	code_committed.emit(_code_edit.text)
	hide()


func _on_cancel() -> void:
	hide()


# ═══════════════════════════════════════════════════════════════════════════════
# Key Bindings — extend base with Ctrl+B
# ═══════════════════════════════════════════════════════════════════════════════

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B and event.ctrl_pressed:
			_on_build_pressed()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_K and event.ctrl_pressed:
			_on_check_pressed()
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
		title = "C++ Editor — %s [%s]" % [node.id, _family.to_upper()]
		_info_label.text = "%s  |  %s  |  %s" % [node.id, _family.to_upper(), node.node_type]
	else:
		title = "C++ Editor"
		_info_label.text = ""

	_update_ref_label()

	_code_edit.text = initial_code
	_code_edit.clear_undo_history()
	_clear_error_marks()
	_set_status("Ctrl+B = Build  |  Ctrl+K = Check  |  Ctrl+Enter = Build & Apply  |  Escape = Cancel")

	_popup_clamped()
	_focus_end()


func set_compile_status(success: bool, output: String) -> void:
	_clear_error_marks()
	if success:
		_set_status("\u2713 Build succeeded", Color(0.3, 1.0, 0.4))
	else:
		var first_err := _extract_first_error(output)
		_set_status("\u2717 Build failed \u2014 %s" % first_err, Color(1.0, 0.35, 0.3))
		_mark_error_lines(output)

	_output_panel.text = ""
	_output_panel.append_text("[code]%s[/code]" % output)
	if not success:
		_output_panel.visible = true
		_output_toggle.text = "\u25BC Compiler Output"


# ═══════════════════════════════════════════════════════════════════════════════
# C++ Syntax Highlighting — Consistent GONODES colour palette
# ═══════════════════════════════════════════════════════════════════════════════

func _setup_cpp_highlighting(edit: CodeEdit) -> void:
	var h := CodeHighlighter.new()
	h.number_color = Color(0.72, 0.86, 0.56)

	# Strings
	h.add_color_region("\"", "\"", Color(0.87, 0.72, 0.45))
	h.add_color_region("'", "'", Color(0.87, 0.72, 0.45))

	# Comments
	h.add_color_region("//", "", Color(0.45, 0.45, 0.45), true)
	h.add_color_region("/*", "*/", Color(0.45, 0.45, 0.45))

	# Preprocessor directives (unique to C++ — purple)
	h.add_color_region("#", "", Color(0.7, 0.5, 0.8), true)

	# C++ keywords — control flow (pink, matches GLSL / GDScript editors)
	for kw in ["auto", "break", "case", "catch", "class", "const", "constexpr",
			"continue", "default", "delete", "do", "else", "enum", "explicit",
			"extern", "for", "friend", "goto", "if", "inline", "mutable",
			"namespace", "new", "noexcept", "operator", "override", "private",
			"protected", "public", "return", "short", "signed", "sizeof",
			"static", "static_cast", "dynamic_cast", "reinterpret_cast",
			"const_cast", "struct", "switch", "template", "this", "throw",
			"try", "typedef", "typename", "union", "unsigned", "using",
			"virtual", "void", "volatile", "while",
			"nullptr", "true", "false", "GDCLASS"]:
		h.add_keyword_color(kw, Color(0.95, 0.5, 0.6))

	# C++ / Godot types (cyan, matches all editors)
	for kw in ["int", "float", "double", "long", "bool", "char", "char32_t",
			"int8_t", "int16_t", "int32_t", "int64_t",
			"uint8_t", "uint16_t", "uint32_t", "uint64_t", "size_t",
			"Ref", "RefCounted", "Image", "ArrayMesh", "SurfaceTool",
			"PackedFloat32Array", "PackedVector3Array", "PackedVector2Array",
			"PackedColorArray", "PackedStringArray", "PackedInt32Array",
			"PackedByteArray",
			"Vector2", "Vector2i", "Vector3", "Vector4", "Color", "String",
			"Dictionary", "Array", "Variant",
			"ShaderMaterial", "Transform3D", "Basis", "AABB", "Quaternion",
			"StringName", "NodePath", "Callable", "Signal"]:
		h.add_keyword_color(kw, Color(0.5, 0.85, 0.95))

	# GONODES SDK base class (green, like shader stage keywords)
	h.add_keyword_color("GNUserNode", Color(0.6, 0.85, 0.4))

	# Godot / C++ built-in constants (light blue, matches context vars)
	for kw in ["Math_PI", "Math_TAU", "CLAMP", "MAX", "MIN",
			"Math_INF", "Math_NAN", "CMP_EPSILON"]:
		h.add_keyword_color(kw, Color(0.55, 0.8, 1.0))

	# GONODES SDK helpers (green, matches par/chop/op helpers in GDScript editor)
	for kw in ["parf", "pari", "parb", "pars", "parc", "parv3",
			"make_sop_result", "make_point_cloud",
			"make_chop_single", "make_chop_result",
			"get_input_channel", "get_input_value",
			"make_img_result", "get_input_image", "create_like",
			"make_top_shader_result", "make_top_image_result",
			"make_dat_table", "make_dat_text",
			"get_input_table", "get_input_text",
			"native_cook", "native_setup",
			"get_node_type", "get_node_description",
			"get_port_definitions", "get_param_definitions"]:
		h.add_keyword_color(kw, Color(0.4, 0.9, 0.5))

	# Math / std lib functions (blue, matches all editors)
	for kw in ["sin", "cos", "tan", "asin", "acos", "atan", "atan2",
			"sinf", "cosf", "tanf", "asinf", "acosf", "atanf", "atan2f",
			"abs", "fabs", "fabsf", "floor", "floorf", "ceil", "ceilf",
			"round", "roundf", "sqrt", "sqrtf", "pow", "powf",
			"fmod", "fmodf", "fmax", "fmaxf", "fmin", "fminf",
			"exp", "expf", "log", "logf", "log2", "log2f",
			"lerp", "clamp"]:
		h.add_keyword_color(kw, Color(0.6, 0.7, 0.95))

	h.symbol_color = Color(0.7, 0.7, 0.7)
	h.function_color = Color(0.5, 0.85, 0.95)
	h.member_variable_color = Color(0.85, 0.85, 0.75)
	edit.syntax_highlighter = h


# ═══════════════════════════════════════════════════════════════════════════════
# Build
# ═══════════════════════════════════════════════════════════════════════════════

func _on_build_pressed() -> void:
	_set_status("Building\u2026", Color(1.0, 0.8, 0.2))
	_build_btn.disabled = true
	code_committed.emit(_code_edit.text)
	build_requested.emit(_code_edit.text)
	get_tree().create_timer(0.5).timeout.connect(
		func(): _build_btn.disabled = false, CONNECT_ONE_SHOT)


func _on_check_pressed() -> void:
	_set_status("Checking\u2026", Color(1.0, 0.8, 0.2))
	_check_btn.disabled = true
	code_committed.emit(_code_edit.text)
	check_requested.emit(_code_edit.text)
	get_tree().create_timer(0.5).timeout.connect(
		func(): _check_btn.disabled = false, CONNECT_ONE_SHOT)


# ═══════════════════════════════════════════════════════════════════════════════
# Error Line Markers
# ═══════════════════════════════════════════════════════════════════════════════

func _clear_error_marks() -> void:
	for line_idx in _error_lines:
		if line_idx < _code_edit.get_line_count():
			_code_edit.set_line_background_color(line_idx, Color(0, 0, 0, 0))
	_error_lines.clear()


func _mark_error_lines(output: String) -> void:
	# GCC / Clang:  user_code.h:42:5: error: expected ';'
	var gcc_re := RegEx.new()
	gcc_re.compile(":(\\d+):\\d+:\\s*(?:error|warning)")
	# MSVC:  user_code.h(42): error C2143: syntax error
	var msvc_re := RegEx.new()
	msvc_re.compile("\\((\\d+)\\)\\s*:\\s*(?:error|warning)")

	var error_bg := Color(0.5, 0.15, 0.15, 0.3)
	for line in output.split("\n"):
		var m := gcc_re.search(line)
		if m == null:
			m = msvc_re.search(line)
		if m != null:
			var line_num := int(m.get_string(1))
			if line_num > 0 and line_num <= _code_edit.get_line_count():
				var idx := line_num - 1
				if idx not in _error_lines:
					_code_edit.set_line_background_color(idx, error_bg)
					_error_lines.append(idx)

	# Jump to first error
	if not _error_lines.is_empty():
		_code_edit.set_caret_line(_error_lines[0])


func _extract_first_error(output: String) -> String:
	for line in output.split("\n"):
		var lower := line.to_lower()
		if "error:" in lower or "error " in lower:
			return line.strip_edges()
	return "See compiler output below."


# ═══════════════════════════════════════════════════════════════════════════════
# Compiler Output Panel
# ═══════════════════════════════════════════════════════════════════════════════

func _toggle_output() -> void:
	_output_panel.visible = not _output_panel.visible
	_output_toggle.text = ("\u25BC " if _output_panel.visible else "\u25B6 ") + "Compiler Output"


# ═══════════════════════════════════════════════════════════════════════════════
# Preset System (via GNScriptHelper)
# ═══════════════════════════════════════════════════════════════════════════════

func _get_preset_folder() -> String:
	return "cpp"


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


func _on_preset_selected(id: int) -> void:
	if id < 0 or id >= _preset_entries.size():
		return
	var entry: Dictionary = _preset_entries[id]
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
	name_edit.placeholder_text = "my_cpp_preset"
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
		var ok := GNScriptHelper.save_preset(_get_preset_folder(), sanitized, captured_code, ".h")
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

func _detect_family(node) -> String:
	if node == null:
		return "sop"
	var nt: String = node.node_type if "node_type" in node else ""
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
			_ref_label.text = "SDK: make_sop_result() | make_point_cloud() | parf/pari/parb/pars/parc/parv3"
		"chop":
			_ref_label.text = "SDK: make_chop_result() | make_chop_single() | get_input_channel/value | parf/pari"
		"img":
			_ref_label.text = "SDK: make_img_result() | get_input_image() | create_like() | parf/pari/parb"
		"top":
			_ref_label.text = "SDK: make_top_shader_result(code, uniforms) | make_top_image_result() | parf/parc"
		"dat":
			_ref_label.text = "SDK: make_dat_table() | make_dat_text() | get_input_table/text | parf/pari"
		_:
			_ref_label.text = "SDK: parf/pari/parb/pars/parc/parv3 | native_cook(params, inputs, context)"
