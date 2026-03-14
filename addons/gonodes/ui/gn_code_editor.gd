class_name GNCodeEditor
extends "res://addons/gonodes/ui/gn_base_code_editor.gd"
## A modal multi-line code editor window for Script operators and
## CustomShaderTOP.  Provides a CodeEdit with syntax highlighting,
## preset load/save integration (via GNScriptHelper), and OK/Cancel buttons.
##
## Extends GNBaseCodeEditor for shared Window / CodeEdit / button-row layout.
##
## Usage:
##   var editor := GNCodeEditor.new()
##   add_child(editor)
##   editor.code_committed.connect(_handle_code)
##   editor.open(node, "code")  # or "shader_code"

## Emitted when the user confirms the code (OK or Ctrl+Enter).
signal code_committed(text: String, param_name: String)

# ─── Internal State ───────────────────────────────────────────────────────────

## The GNNode owning this code parameter.
var _owner_node: GNNode = null

## The parameter name being edited ("code" or "shader_code").
var _param_name: String = ""

## Whether this editor is in shader mode (GLSL-like highlighting).
var _shader_mode: bool = false
var _isf_mode: bool = false

# ─── Preset UI ────────────────────────────────────────────────────────────────

var _preset_menu_btn: MenuButton = null
var _save_btn: Button = null
var _ref_label: Label = null
var _preset_entries: Array = []


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle Overrides
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	super()
	title = "Code Editor"
	size = Vector2i(720, 560)
	min_size = Vector2i(480, 320)


## Adds the preset toolbar between info label and CodeEdit.
func _build_toolbar(parent: VBoxContainer) -> void:
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 4)
	parent.add_child(toolbar)

	_preset_menu_btn = MenuButton.new()
	_preset_menu_btn.text = "Presets \u25be"
	_preset_menu_btn.tooltip_text = "Load a preset script"
	_preset_menu_btn.custom_minimum_size = Vector2(90, 28)
	_preset_menu_btn.flat = false
	var popup := _preset_menu_btn.get_popup()
	popup.about_to_popup.connect(_build_preset_menu)
	popup.id_pressed.connect(_on_preset_selected)
	toolbar.add_child(_preset_menu_btn)

	_save_btn = Button.new()
	_save_btn.text = "Save Preset\u2026"
	_save_btn.tooltip_text = "Save current code as a user preset"
	_save_btn.custom_minimum_size = Vector2(100, 28)
	_save_btn.pressed.connect(_on_save_preset_pressed)
	toolbar.add_child(_save_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	_ref_label = Label.new()
	_ref_label.add_theme_font_size_override("font_size", 10)
	_ref_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_ref_label.text = "Vars: me, inputs, op, time, frame, dt  |  par(name)"
	toolbar.add_child(_ref_label)


func _on_ok() -> void:
	code_committed.emit(_code_edit.text, _param_name)
	hide()


# ═══════════════════════════════════════════════════════════════════════════════
# Public API
# ═══════════════════════════════════════════════════════════════════════════════

## Opens the editor for a code parameter on a given node.
## [param node] — the GNNode owning the parameter.
## [param param_name] — "code" for Script operators, "shader_code" for CustomShaderTOP.
func open(node: GNNode, param_name: String) -> void:
	_owner_node = node
	_param_name = param_name
	_shader_mode = (param_name == "shader_code")
	_isf_mode = (param_name == "isf_code")

	# Configure window title
	var family_name := GNFamily.get_family_name(node.family)
	title = "Code Editor \u2014 %s [%s]" % [node.id, family_name]

	# Info label
	_info_label.text = "%s  |  %s  |  %s" % [node.id, family_name, node.node_type]

	# Update reference label
	if _ref_label:
		if _isf_mode:
			_ref_label.text = "ISF: TIME, RENDERSIZE, isf_FragNormCoord, gl_FragColor | IMG_PIXEL, IMG_NORM_PIXEL, IMG_THIS_PIXEL, IMG_SIZE"
		elif _shader_mode:
			_ref_label.text = "Uniforms: gn_time, gn_resolution, gn_tex0..7 | Built-in: UV, COLOR, SCREEN_UV"
		else:
			_ref_label.text = "Vars: me, inputs, op, time, frame, dt  |  par(name)"

	# Show/hide preset controls depending on whether presets make sense
	var has_presets := not _get_preset_folder().is_empty()
	_preset_menu_btn.visible = has_presets
	_save_btn.visible = has_presets

	# Apply syntax highlighting
	if _isf_mode:
		_setup_isf_highlighter()
	elif _shader_mode:
		_setup_shader_highlighter()
	else:
		_setup_gdscript_highlighter()

	# Load current param value
	var param := node.get_parameter(param_name)
	_code_edit.text = str(param.value) if param else ""

	_set_status("Ctrl+Enter to confirm  |  Escape to cancel")

	popup_centered()
	_focus_end()


# ═══════════════════════════════════════════════════════════════════════════════
# Syntax Highlighting
# ═══════════════════════════════════════════════════════════════════════════════

## GDScript highlighting for Script operators.
func _setup_gdscript_highlighter() -> void:
	var h := CodeHighlighter.new()

	# Numbers
	h.number_color = Color(0.72, 0.86, 0.56)

	# Strings
	h.add_color_region("\"", "\"", Color(0.87, 0.72, 0.45))
	h.add_color_region("'", "'", Color(0.87, 0.72, 0.45))
	h.add_color_region("\"\"\"", "\"\"\"", Color(0.87, 0.72, 0.45))

	# Comments
	h.add_color_region("#", "", Color(0.45, 0.45, 0.45), true)

	# Annotation keywords (@param, @input, @output)
	h.add_keyword_color("@param", Color(0.6, 0.85, 0.4))
	h.add_keyword_color("@input", Color(0.6, 0.85, 0.4))
	h.add_keyword_color("@output", Color(0.6, 0.85, 0.4))

	# GONODES context variables
	for kw in ["me", "inputs", "op", "outputs", "time", "frame", "dt",
			"target", "event", "event_param"]:
		h.add_keyword_color(kw, Color(0.55, 0.8, 1.0))

	# GONODES helper functions
	for fn in ["par", "chop", "op_ref", "top", "sop", "dat", "set_par",
			"network_add_node", "network_remove_node", "network_connect",
			"network_disconnect", "network_node_ids", "network_node_info"]:
		h.add_keyword_color(fn, Color(0.4, 0.9, 0.5))

	# GDScript keywords
	for kw in ["func", "var", "const", "if", "elif", "else", "for", "while",
			"return", "pass", "break", "continue", "class", "extends",
			"true", "false", "null", "and", "or", "not", "in", "is",
			"self", "super", "enum", "signal", "static", "await",
			"match", "when", "class_name"]:
		h.add_keyword_color(kw, Color(0.95, 0.5, 0.6))

	# Built-in types
	for kw in ["int", "float", "bool", "String", "Vector2", "Vector2i",
			"Vector3", "Vector4", "Color", "Array", "Dictionary",
			"Image", "PackedFloat32Array", "PackedVector3Array",
			"PackedStringArray", "Transform3D", "AABB"]:
		h.add_keyword_color(kw, Color(0.5, 0.85, 0.95))

	# Math functions
	for fn in ["sin", "cos", "tan", "abs", "floor", "ceil", "round",
			"clamp", "clampf", "lerp", "lerpf", "sqrt", "pow",
			"min", "max", "minf", "maxf", "fmod", "sign",
			"randf", "randi", "randf_range", "randi_range",
			"deg_to_rad", "rad_to_deg", "PI", "TAU", "INF",
			"snapped", "wrap", "wrapf", "pingpong", "ease", "log", "exp",
			"maxi", "mini", "remap"]:
		h.add_keyword_color(fn, Color(0.6, 0.7, 0.95))

	# Symbols
	h.symbol_color = Color(0.7, 0.7, 0.7)
	h.function_color = Color(0.5, 0.85, 0.95)
	h.member_variable_color = Color(0.85, 0.85, 0.75)

	_code_edit.syntax_highlighter = h


## ISF (Interactive Shader Format) highlighting.
## JSON header block + GLSL body with ISF built-ins and functions.
func _setup_isf_highlighter() -> void:
	var h := CodeHighlighter.new()

	# Numbers
	h.number_color = Color(0.72, 0.86, 0.56)

	# Strings
	h.add_color_region('"', '"', Color(0.87, 0.72, 0.45))

	# ISF JSON header block /*{ ... }*/ — coloured distinctly from code comments
	h.add_color_region("/*", "*/", Color(0.78, 0.68, 0.45))

	# Line comments
	h.add_color_region("//", "", Color(0.45, 0.45, 0.45), true)

	# ISF JSON metadata keys (highlighted even inside the comment block)
	for kw in ["DESCRIPTION", "CREDIT", "ISFVSN", "CATEGORIES",
			"INPUTS", "PASSES", "IMPORTED",
			"NAME", "LABEL", "TYPE", "DEFAULT", "MIN", "MAX",
			"VALUES", "LABELS",
			"TARGET", "PERSISTENT", "FLOAT", "WIDTH", "HEIGHT",
			"PATH", "MIPMAP"]:
		h.add_keyword_color(kw, Color(0.9, 0.78, 0.42))

	# ISF input type strings
	for kw in ["float", "bool", "long", "point2D", "color",
			"image", "event", "audio", "audioFFT"]:
		h.add_keyword_color(kw, Color(0.5, 0.85, 0.95))

	# ISF GLSL built-in variables
	for kw in ["RENDERSIZE", "TIMEDELTA", "DATE", "FRAMEINDEX", "PASSINDEX",
			"isf_FragNormCoord", "gl_FragColor", "gl_FragCoord",
			"TIME", "PI", "TAU"]:
		h.add_keyword_color(kw, Color(0.55, 0.8, 1.0))

	# ISF image functions
	for fn in ["IMG_PIXEL", "IMG_NORM_PIXEL", "IMG_THIS_PIXEL",
			"IMG_THIS_NORM_PIXEL", "IMG_SIZE"]:
		h.add_keyword_color(fn, Color(0.4, 0.9, 0.55))

	# GLSL keywords
	for kw in ["void", "if", "else", "for", "while", "return", "discard",
			"true", "false", "const", "struct", "in", "out", "inout",
			"uniform", "varying", "precision", "mediump", "highp", "lowp"]:
		h.add_keyword_color(kw, Color(0.95, 0.5, 0.6))

	# GLSL types
	for kw in ["int", "vec2", "vec3", "vec4",
			"ivec2", "ivec3", "ivec4", "mat2", "mat3", "mat4",
			"sampler2D", "sampler3D", "samplerCube"]:
		h.add_keyword_color(kw, Color(0.5, 0.85, 0.95))

	# GLSL math functions
	for fn in ["sin", "cos", "tan", "abs", "floor", "ceil", "round",
			"clamp", "mix", "step", "smoothstep", "length", "normalize",
			"dot", "cross", "reflect", "refract", "pow", "sqrt",
			"min", "max", "mod", "fract", "sign", "texture",
			"distance", "atan", "asin", "acos", "exp", "log",
			"inversesqrt", "radians", "degrees"]:
		h.add_keyword_color(fn, Color(0.6, 0.7, 0.95))

	h.symbol_color = Color(0.7, 0.7, 0.7)
	h.function_color = Color(0.5, 0.85, 0.95)
	h.member_variable_color = Color(0.85, 0.85, 0.75)

	_code_edit.syntax_highlighter = h


## GLSL / Godot shader highlighting for CustomShaderTOP.
func _setup_shader_highlighter() -> void:
	var h := CodeHighlighter.new()

	# Numbers
	h.number_color = Color(0.72, 0.86, 0.56)

	# Strings (shader strings are rare, but support them)
	h.add_color_region("\"", "\"", Color(0.87, 0.72, 0.45))

	# Comments
	h.add_color_region("//", "", Color(0.45, 0.45, 0.45), true)
	h.add_color_region("/*", "*/", Color(0.45, 0.45, 0.45))

	# Shader keywords
	for kw in ["shader_type", "render_mode", "uniform", "varying",
			"void", "if", "else", "for", "while", "return", "discard",
			"true", "false", "const", "struct", "in", "out", "inout"]:
		h.add_keyword_color(kw, Color(0.95, 0.5, 0.6))

	# Shader types
	for kw in ["float", "int", "bool", "vec2", "vec3", "vec4",
			"ivec2", "ivec3", "ivec4", "mat2", "mat3", "mat4",
			"sampler2D", "sampler3D", "samplerCube"]:
		h.add_keyword_color(kw, Color(0.5, 0.85, 0.95))

	# Godot shader stages
	for kw in ["vertex", "fragment", "light", "canvas_item", "spatial",
			"particles", "sky", "fog"]:
		h.add_keyword_color(kw, Color(0.6, 0.85, 0.4))

	# Built-in variables
	for kw in ["UV", "COLOR", "FRAGCOORD", "SCREEN_UV", "SCREEN_TEXTURE",
			"VERTEX", "NORMAL", "TIME", "PI", "TAU",
			"TEXTURE", "SCREEN_PIXEL_SIZE", "AT_LIGHT_PASS"]:
		h.add_keyword_color(kw, Color(0.55, 0.8, 1.0))

	# GONODES uniform names
	for kw in ["gn_time", "gn_resolution", "gn_frame", "gn_dt",
			"gn_tex0", "gn_tex1", "gn_tex2", "gn_tex3",
			"gn_tex4", "gn_tex5", "gn_tex6", "gn_tex7"]:
		h.add_keyword_color(kw, Color(0.4, 0.9, 0.5))

	# Math functions
	for fn in ["sin", "cos", "tan", "abs", "floor", "ceil", "round",
			"clamp", "mix", "step", "smoothstep", "length", "normalize",
			"dot", "cross", "reflect", "refract", "pow", "sqrt",
			"min", "max", "mod", "fract", "sign", "texture",
			"distance", "atan", "asin", "acos", "exp", "log",
			"inversesqrt", "radians", "degrees"]:
		h.add_keyword_color(fn, Color(0.6, 0.7, 0.95))

	# Symbols
	h.symbol_color = Color(0.7, 0.7, 0.7)
	h.function_color = Color(0.5, 0.85, 0.95)
	h.member_variable_color = Color(0.85, 0.85, 0.75)

	_code_edit.syntax_highlighter = h


# ═══════════════════════════════════════════════════════════════════════════════
# Preset Integration
# ═══════════════════════════════════════════════════════════════════════════════

## Returns the preset folder name for the current node, or "" if none.
func _get_preset_folder() -> String:
	if _owner_node == null:
		return ""
	# Per-family Script operators: node_type is "scriptimg", "scriptchop", etc.
	if _owner_node.node_type.begins_with("script"):
		return _owner_node.node_type
	# GenericScriptNode preset folder
	if _owner_node.node_type == "genericscript":
		return "genericscript"
	# CallbackDAT — share one preset folder for all callback params
	if _owner_node.node_type == "callbackdat":
		return "callbackdat"
	# CustomShaderTOP (node_type == "glsl")
	if _param_name == "shader_code":
		return "glsl"
	# ISFFileTOP
	if _param_name == "isf_code":
		return "isf"
	return ""


## Builds the preset popup menu each time it opens.
func _build_preset_menu() -> void:
	var popup := _preset_menu_btn.get_popup()
	popup.clear()
	_preset_entries.clear()

	var folder := _get_preset_folder()
	if folder.is_empty():
		popup.add_item("(no presets)", 0)
		popup.set_item_disabled(0, true)
		return

	var presets := GNScriptHelper.get_preset_list(folder)
	if presets.is_empty():
		popup.add_item("(no presets)", 0)
		popup.set_item_disabled(0, true)
		return

	# Group by factory vs user
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


## Handles preset selection.
func _on_preset_selected(id: int) -> void:
	if id < 0 or id >= _preset_entries.size():
		return
	var entry: Dictionary = _preset_entries[id]
	var code := GNScriptHelper.load_preset(entry["path"])
	if code.is_empty():
		_set_status("Failed to load preset: %s" % entry["path"], Color(1.0, 0.35, 0.3))
		return

	_code_edit.text = code
	_code_edit.grab_focus()
	_set_status("Loaded preset: %s" % entry["name"], Color(0.4, 0.9, 0.5))


## Opens a save-preset dialog.
func _on_save_preset_pressed() -> void:
	var folder := _get_preset_folder()
	if folder.is_empty():
		_set_status("Presets not supported for this operator type.", Color(1.0, 0.7, 0.3))
		return

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
	name_edit.placeholder_text = "my_preset"
	name_edit.custom_minimum_size = Vector2(300, 0)
	vb.add_child(name_edit)

	dlg.add_child(vb)
	dlg.ok_button_text = "Save"

	var captured_code := code
	var captured_folder := folder
	dlg.confirmed.connect(func() -> void:
		var preset_name := name_edit.text.strip_edges()
		if preset_name.is_empty():
			return
		# Sanitize to safe filename chars
		var sanitized := ""
		for ch in preset_name:
			if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") \
					or (ch >= "0" and ch <= "9") or ch == "_":
				sanitized += ch
			else:
				sanitized += "_"
		if sanitized.is_empty():
			return

		var ok := GNScriptHelper.save_preset(captured_folder, sanitized, captured_code,
				".fs" if _isf_mode else ".gd")
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
