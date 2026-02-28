class_name GNExpressionEditor
extends "res://addons/gonodes/ui/gn_base_code_editor.gd"
## A modal multi-line expression editor popup.
## Provides a CodeEdit with syntax-hinting, an autocomplete helper,
## and a live error indicator for writing complex GDScript expressions.
##
## Extends GNBaseCodeEditor for shared Window / CodeEdit / button-row layout.
##
## Usage:
##   var editor := GNExpressionEditor.new()
##   add_child(editor)
##   editor.open(param, component_index)
##   editor.expression_committed.connect(_handle_expr)

const _ExprFunctions := preload("res://addons/gonodes/core/gn_expression_functions.gd")

## Emitted when the user confirms the expression (OK or Ctrl+Enter).
## Provides the final expression text, the parameter, and the component index
## (-1 for the main expression, 0+ for per-component).
signal expression_committed(text: String, param: GNParameter, component_idx: int)

## The network reference for autocomplete (node IDs, params, channels).
var network: GNNetwork = null

# ─── Internal State ───────────────────────────────────────────────────────────

var _param: GNParameter = null
var _component_idx: int = -1

## The snippets popup (stored for rebuilding after save/delete).
var _snippets_popup: PopupMenu = null

# ─── User Snippets (persisted to disk) ────────────────────────────────────────

const _USER_SNIPPETS_PATH := "user://gonodes_snippets.json"

## User-defined snippets: Array of { "name": String, "code": String, "category": String }.
static var _user_snippets: Array[Dictionary] = []

## Whether user snippets have been loaded from disk yet.
static var _user_snippets_loaded: bool = false


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle Overrides
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	super()
	title = "Expression Editor"
	size = Vector2i(560, 400)


## Configures code completion and syntax highlighting on the shared CodeEdit.
func _setup_code_edit(edit: CodeEdit) -> void:
	edit.code_completion_enabled = true
	edit.code_completion_prefixes = PackedStringArray([".", "(", "\""])
	edit.code_completion_requested.connect(_on_code_completion_requested)
	edit.text_changed.connect(_on_text_changed)
	_setup_syntax_highlighter()


## Adds the Snippets dropdown and reference cheatsheet to the bottom bar.
func _build_bottom_bar(bar: HBoxContainer) -> void:
	var presets_btn := MenuButton.new()
	presets_btn.text = "Snippets \u25be"
	presets_btn.tooltip_text = "Insert expression preset or snippet"
	presets_btn.custom_minimum_size = Vector2(90, 30)
	presets_btn.flat = false
	_snippets_popup = presets_btn.get_popup()
	_load_user_snippets()
	_build_presets_menu(_snippets_popup)
	bar.add_child(presets_btn)

	var ref_label := Label.new()
	ref_label.text = "Vars: me, time, frame, dt  |  Funcs: chop(), op(), top(), fit(), smooth()  |  Paths: ../node, subnet/node"
	ref_label.add_theme_font_size_override("font_size", 10)
	ref_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	bar.add_child(ref_label)


func _on_ok() -> void:
	var text := _code_edit.text.strip_edges()
	expression_committed.emit(text, _param, _component_idx)
	hide()


# ═══════════════════════════════════════════════════════════════════════════════
# Public API
# ═══════════════════════════════════════════════════════════════════════════════

## Opens the editor for a specific parameter's expression.
## [param component_idx] is -1 for the main expression, or 0+ for per-component.
func open(param: GNParameter, component_idx: int = -1) -> void:
	_param = param
	_component_idx = component_idx

	# Set window title and info label
	if component_idx >= 0:
		var labels := param.get_component_labels()
		var comp_label: String = labels[component_idx] if component_idx < labels.size() else str(component_idx)
		title = "Expression Editor \u2014 %s [%s]" % [param.param_name, comp_label]
		var profile_str := ""
		if component_idx < param.component_expression_eval_usec.size() \
				and param.component_expression_eval_usec[component_idx] > 0.0:
			profile_str = "  |  Last eval: %.1f\u00b5s" % param.component_expression_eval_usec[component_idx]
		_info_label.text = "Parameter: %s [%s]  |  Type: %s%s" % [
			param.param_name, comp_label,
			GNParameter.ValueType.keys()[param.value_type], profile_str]
	else:
		title = "Expression Editor \u2014 %s" % param.param_name
		var profile_str := ""
		if param.expression_eval_avg_usec > 0.0:
			profile_str = "  |  Avg eval: %.1f\u00b5s" % param.expression_eval_avg_usec
		_info_label.text = "Parameter: %s  |  Type: %s%s" % [
			param.param_name,
			GNParameter.ValueType.keys()[param.value_type], profile_str]

	# Load existing expression text
	var expr_text := ""
	if component_idx >= 0 and component_idx < param.component_expressions.size():
		expr_text = param.component_expressions[component_idx]
	else:
		expr_text = param.expression

	_code_edit.text = expr_text
	_error_label.text = ""

	# Validate initial text
	_validate_expression(expr_text)

	popup_centered()
	_focus_end()


# ═══════════════════════════════════════════════════════════════════════════════
# Syntax Highlighting
# ═══════════════════════════════════════════════════════════════════════════════

## Sets up a CodeHighlighter for expression-relevant keywords.
func _setup_syntax_highlighter() -> void:
	var highlighter := CodeHighlighter.new()

	# Numbers
	highlighter.number_color = Color(0.72, 0.86, 0.56)

	# Strings
	highlighter.add_color_region("\"", "\"", Color(0.87, 0.72, 0.45))
	highlighter.add_color_region("'", "'", Color(0.87, 0.72, 0.45))

	# Comments (single-line — expressions usually don't use these but just in case)
	highlighter.add_color_region("#", "", Color(0.45, 0.45, 0.45), true)

	# GONODES expression functions
	highlighter.add_keyword_color("chop", Color(0.4, 0.9, 0.5))
	highlighter.add_keyword_color("op", Color(0.4, 0.9, 0.5))
	highlighter.add_keyword_color("top", Color(0.7, 0.5, 0.9))
	highlighter.add_keyword_color("sop", Color(0.4, 0.7, 0.9))
	highlighter.add_keyword_color("dat", Color(0.8, 0.8, 0.4))
	highlighter.add_keyword_color("mat", Color(0.9, 0.7, 0.4))

	# Built-in context variables
	highlighter.add_keyword_color("me", Color(0.55, 0.8, 1.0))
	highlighter.add_keyword_color("time", Color(0.55, 0.8, 1.0))
	highlighter.add_keyword_color("frame", Color(0.55, 0.8, 1.0))
	highlighter.add_keyword_color("dt", Color(0.55, 0.8, 1.0))

	# GDScript math functions
	for fn_name in ["sin", "cos", "tan", "abs", "floor", "ceil", "round",
			"clamp", "clampf", "lerp", "lerpf", "remap", "sqrt", "pow",
			"min", "max", "minf", "maxf", "fmod", "fposmod", "sign",
			"randf", "randi", "randf_range", "randi_range",
			"deg_to_rad", "rad_to_deg", "PI", "TAU", "INF",
			"inverse_lerp", "snapped", "wrap", "wrapf",
			"pingpong", "ease", "log", "exp", "is_nan", "is_inf"]:
		highlighter.add_keyword_color(fn_name, Color(0.6, 0.7, 0.95))

	# GONODES built-in expression functions (on CookEngine)
	for fn_name in ["fit", "fit01", "smooth", "lag", "pulse", "step",
			"smoothstep", "cycle", "bounce", "noise1", "noise2",
			"trigger", "fn"]:
		highlighter.add_keyword_color(fn_name, Color(0.45, 0.92, 0.72))

	# GDScript keywords
	for kw in ["true", "false", "null", "and", "or", "not",
			"if", "else", "int", "float", "bool", "str",
			"Vector2", "Vector3", "Vector4", "Color"]:
		highlighter.add_keyword_color(kw, Color(0.95, 0.5, 0.6))

	# Symbols color
	highlighter.symbol_color = Color(0.7, 0.7, 0.7)
	highlighter.function_color = Color(0.5, 0.85, 0.95)
	highlighter.member_variable_color = Color(0.85, 0.85, 0.75)

	_code_edit.syntax_highlighter = highlighter


# ═══════════════════════════════════════════════════════════════════════════════
# Code Completion / Autocomplete
# ═══════════════════════════════════════════════════════════════════════════════

## Called when the CodeEdit requests code completion suggestions.
func _on_code_completion_requested() -> void:
	var line := _code_edit.get_line(_code_edit.get_caret_line())
	var col := _code_edit.get_caret_column()
	var text_before := line.substr(0, col)

	# Detect context: are we inside chop("..., op("..., top("...?
	var inside_func := _detect_function_context(text_before)

	if inside_func == "node_id":
		# We're inside a function call's first string argument — suggest node IDs
		_suggest_node_ids()
	elif inside_func == "chop_channel":
		# Second argument of chop() — suggest channel names
		var node_id := _extract_first_string_arg(text_before)
		_suggest_chop_channels(node_id)
	elif inside_func == "op_param":
		# Second argument of op() — suggest param names
		var node_id := _extract_first_string_arg(text_before)
		_suggest_op_params(node_id)
	elif inside_func == "top_prop":
		# Second argument of top() — suggest property names
		_suggest_top_properties()
	elif inside_func == "fn_name":
		# First argument of fn() — suggest registered function names
		_suggest_fn_names()
	else:
		# General context — suggest variables, functions, node reference functions
		_suggest_general()


## Detects what kind of autocomplete context we're in based on text before cursor.
func _detect_function_context(text: String) -> String:
	# Check for patterns like: chop("  op("  top("
	# We look backwards for the most recent unclosed function call

	# Pattern: func_name("first_arg", "  → suggesting second arg
	var re_second := RegEx.new()
	re_second.compile("(chop|op|top)\\s*\\(\\s*\"[^\"]*\"\\s*,\\s*\"[^\"]*$")
	var m_second := re_second.search(text)
	if m_second:
		var fn := m_second.get_string(1)
		match fn:
			"chop": return "chop_channel"
			"op": return "op_param"
			"top": return "top_prop"

	# Pattern: func_name("  → suggesting first arg (node ID)
	var re_first := RegEx.new()
	re_first.compile("(?:chop|op|top|sop|dat|mat)\\s*\\(\\s*\"[^\"]*$")
	if re_first.search(text):
		return "node_id"

	# Pattern: fn("  → suggesting custom function names
	var re_fn := RegEx.new()
	re_fn.compile("fn\\s*\\(\\s*\"[^\"]*$")
	if re_fn.search(text):
		return "fn_name"

	return ""


## Extracts the first string argument from a function call.
## E.g., from 'chop("lfo1", "' returns "lfo1".
func _extract_first_string_arg(text: String) -> String:
	var re := RegEx.new()
	re.compile("(?:chop|op|top)\\s*\\(\\s*\"([^\"]*)\"")
	var m := re.search(text)
	if m:
		return m.get_string(1)
	return ""


## Suggests all node IDs in the network.
func _suggest_node_ids() -> void:
	if network == null:
		return
	for node_id in network.nodes:
		_code_edit.add_code_completion_option(
			CodeEdit.KIND_VARIABLE, node_id, node_id,
			Color(0.55, 0.8, 1.0), null, null)
	_code_edit.update_code_completion_options(true)


## Suggests CHOP channel names for a specific node.
func _suggest_chop_channels(node_id: String) -> void:
	if network == null or node_id.is_empty():
		return
	var node: GNNode = network.nodes.get(node_id, null)
	if node == null or node.cached_output == null:
		return
	if node.cached_output is GNChannelData:
		var ch_data: GNChannelData = node.cached_output as GNChannelData
		for ch_name in ch_data.get_channel_names():
			_code_edit.add_code_completion_option(
				CodeEdit.KIND_MEMBER, ch_name, ch_name,
				Color(0.4, 0.9, 0.5), null, null)
		_code_edit.update_code_completion_options(true)


## Suggests parameter names for a specific node.
func _suggest_op_params(node_id: String) -> void:
	if network == null or node_id.is_empty():
		return
	var node: GNNode = network.nodes.get(node_id, null)
	if node == null:
		return
	for param_name in node.parameters:
		_code_edit.add_code_completion_option(
			CodeEdit.KIND_MEMBER, param_name, param_name,
			Color(0.85, 0.85, 0.75), null, null)
	_code_edit.update_code_completion_options(true)


## Suggests TOP property names.
func _suggest_top_properties() -> void:
	for prop in ["resolution", "aspect"]:
		_code_edit.add_code_completion_option(
			CodeEdit.KIND_MEMBER, prop, prop,
			Color(0.7, 0.5, 0.9), null, null)
	_code_edit.update_code_completion_options(true)


## Suggests registered custom function names (for fn("...") autocomplete).
func _suggest_fn_names() -> void:
	for func_name in _ExprFunctions.get_names():
		var entry = _ExprFunctions.get_all().get(func_name)
		var desc: String = ""
		if entry:
			desc = entry.description
		_code_edit.add_code_completion_option(
			CodeEdit.KIND_FUNCTION, func_name, func_name,
			Color(0.9, 0.75, 0.4), null, desc)
	_code_edit.update_code_completion_options(true)


## Suggests general expression symbols: variables, functions, constructors.
func _suggest_general() -> void:
	# Context variables
	for v in [["me", "Current node"], ["time", "Elapsed seconds"],
			["frame", "Frame number"], ["dt", "Delta time"]]:
		_code_edit.add_code_completion_option(
			CodeEdit.KIND_VARIABLE, v[0], v[0],
			Color(0.55, 0.8, 1.0), null, v[1])

	# Node reference functions
	for fn_entry in [["chop(\"", "Read CHOP channel value"],
			["op(\"", "Read node parameter value"],
			["top(\"", "Read TOP info (resolution, aspect)"]]:
		_code_edit.add_code_completion_option(
			CodeEdit.KIND_FUNCTION, fn_entry[0], fn_entry[0],
			Color(0.4, 0.9, 0.5), null, fn_entry[1])

	# GONODES built-in expression functions
	var builtin_funcs: Array = [
		["fit(", "Remap value between ranges: fit(v, in_min, in_max, out_min, out_max)"],
		["fit01(", "Remap to 0-1: fit01(v, in_min, in_max)"],
		["smooth(\"", "Exponential smoothing: smooth(key, target, speed)"],
		["lag(\"", "Asymmetric lag: lag(key, target, up_speed, down_speed)"],
		["pulse(", "Pulse wave: pulse(phase, duty)"],
		["step(", "Step function: step(edge, value)"],
		["smoothstep(", "Smooth interpolation: smoothstep(edge0, edge1, x)"],
		["cycle(", "Cyclic 0-1 ramp: cycle(period_seconds)"],
		["bounce(", "Bounce: abs(sin(t * PI))"],
		["noise1(", "1D value noise: noise1(x)"],
		["noise2(", "2D value noise: noise2(x, y)"],
		["trigger(\"", "Trigger on threshold cross: trigger(key, value, threshold)"],
		["fn(\"", "Call custom function: fn(name, arg1, arg2, ...)"],
	]
	for fn_entry in builtin_funcs:
		_code_edit.add_code_completion_option(
			CodeEdit.KIND_FUNCTION, fn_entry[0], fn_entry[0],
			Color(0.45, 0.92, 0.72), null, fn_entry[1])

	# Common math functions
	for fn_name in ["sin(", "cos(", "abs(", "clamp(", "lerp(", "remap(",
			"sqrt(", "pow(", "min(", "max(", "floor(", "ceil(",
			"round(", "fmod(", "randf()", "pingpong("]:
		_code_edit.add_code_completion_option(
			CodeEdit.KIND_FUNCTION, fn_name, fn_name,
			Color(0.6, 0.7, 0.95))

	# Custom user-defined functions (registered via GNExpressionFunctions)
	for func_name in _ExprFunctions.get_names():
		var entry = _ExprFunctions.get_all().get(func_name)
		if entry and not entry.is_builtin:
			var desc: String = entry.description if entry.description else "Custom function"
			var insert := "fn(\"%s\", " % func_name
			_code_edit.add_code_completion_option(
				CodeEdit.KIND_FUNCTION, insert, insert,
				Color(0.9, 0.75, 0.4), null, desc)

	# Constants
	for c in ["PI", "TAU", "INF", "true", "false"]:
		_code_edit.add_code_completion_option(
			CodeEdit.KIND_CONSTANT, c, c,
			Color(0.95, 0.5, 0.6))

	_code_edit.update_code_completion_options(true)


# ═══════════════════════════════════════════════════════════════════════════════
# Presets / Snippets
# ═══════════════════════════════════════════════════════════════════════════════

## Built-in expression presets organized by category.
const PRESETS := {
	"Time & Animation": [
		["Sine wave", "sin(time * TAU * 1.0)"],
		["Cosine wave", "cos(time * TAU * 1.0)"],
		["Sawtooth 0-1", "fmod(time, 1.0)"],
		["Cyclic ramp", "cycle(2.0)"],
		["Ping-pong", "pingpong(time, 1.0)"],
		["Bounce", "bounce(time)"],
		["Pulse wave", "pulse(time * 2.0, 0.5)"],
		["Frame counter", "frame"],
		["Delta time", "dt"],
	],
	"Remapping": [
		["Fit to range", "fit(value, 0.0, 1.0, -1.0, 1.0)"],
		["Fit to 0-1", "fit01(value, -1.0, 1.0)"],
		["Sin to 0-1", "fit(sin(time * TAU), -1.0, 1.0, 0.0, 1.0)"],
		["Smoothstep", "smoothstep(0.0, 1.0, value)"],
		["Step threshold", "step(0.5, value)"],
	],
	"Smoothing & Filtering": [
		["Smooth follow", "smooth(\"key\", target, 5.0)"],
		["Lag (asymmetric)", "lag(\"key\", target, 3.0, 8.0)"],
		["Trigger detect", "trigger(\"key\", value, 0.5)"],
	],
	"Noise & Random": [
		["Noise 1D (time)", "noise1(time * 2.0)"],
		["Noise 2D", "noise2(time, 0.0)"],
		["Random [0, 1]", "randf()"],
		["Random range", "randf_range(-1.0, 1.0)"],
	],
	"Node References": [
		["Read CHOP channel", "chop(\"node_id\", \"channel\")"],
		["Read parameter", "op(\"node_id\", \"param\")"],
		["TOP resolution X", "top(\"node_id\", \"resolution\").x"],
		["TOP aspect ratio", "top(\"node_id\", \"aspect\")"],
	],
	"Math Patterns": [
		["Sine + offset", "sin(time * TAU * 1.0) * 0.5 + 0.5"],
		["Exponential decay", "exp(-time * 2.0)"],
		["Power curve", "pow(value, 2.0)"],
		["Circular motion X", "cos(time * TAU * 0.5) * radius"],
		["Circular motion Y", "sin(time * TAU * 0.5) * radius"],
		["Quantize (steps)", "floor(value * 4.0) / 4.0"],
	],
}


## Builds the presets popup menu from the PRESETS dictionary + user snippets.
func _build_presets_menu(popup: PopupMenu) -> void:
	# Disconnect any prior signal to avoid duplicates on rebuild
	if popup.id_pressed.is_connected(_on_preset_selected):
		popup.id_pressed.disconnect(_on_preset_selected)
	popup.clear()
	var id := 0

	# ── Built-in presets ────────────────────────────────────────────────
	for category in PRESETS:
		popup.add_separator(category)
		var entries: Array = PRESETS[category]
		for entry in entries:
			popup.add_item(entry[0], id)
			popup.set_item_tooltip(id, entry[1])
			popup.set_item_metadata(id, {"action": "insert", "code": entry[1]})
			id += 1

	# ── User snippets ───────────────────────────────────────────────────
	if _user_snippets.size() > 0:
		popup.add_separator("My Snippets")
		for i in range(_user_snippets.size()):
			var snip: Dictionary = _user_snippets[i]
			var display_name: String = snip.get("name", "Untitled")
			popup.add_item(display_name, id)
			popup.set_item_tooltip(id, snip.get("code", ""))
			popup.set_item_metadata(id, {"action": "insert", "code": snip.get("code", ""), "user_idx": i})
			id += 1
		# Delete submenu
		var delete_sub := PopupMenu.new()
		delete_sub.name = "DeleteSnippets"
		for i in range(_user_snippets.size()):
			var snip: Dictionary = _user_snippets[i]
			delete_sub.add_item(snip.get("name", "Untitled"), i)
		delete_sub.id_pressed.connect(_on_delete_snippet)
		popup.add_child(delete_sub)
		popup.add_submenu_item("Delete snippet...", "DeleteSnippets", id)
		id += 1

	# ── Save current expression as snippet ──────────────────────────────
	popup.add_separator()
	popup.add_item("Save current as snippet...", id)
	popup.set_item_metadata(id, {"action": "save"})
	id += 1

	popup.id_pressed.connect(_on_preset_selected)


## Handles clicks on the snippets popup menu.
func _on_preset_selected(id: int) -> void:
	if _snippets_popup == null:
		return
	var idx := _snippets_popup.get_item_index(id)
	if idx < 0:
		return
	var meta = _snippets_popup.get_item_metadata(idx)
	if meta == null or not meta is Dictionary:
		return

	var action: String = meta.get("action", "")
	if action == "insert":
		var snippet: String = meta.get("code", "")
		if snippet.is_empty():
			return
		if _code_edit.text.strip_edges().is_empty():
			_code_edit.text = snippet
		else:
			_code_edit.insert_text_at_caret(snippet)
		_code_edit.grab_focus()
		_validate_expression(_code_edit.text.strip_edges())
	elif action == "save":
		_show_save_snippet_dialog()


## Opens a small dialog asking for a snippet name, then saves.
func _show_save_snippet_dialog() -> void:
	var code := _code_edit.text.strip_edges()
	if code.is_empty():
		_error_label.text = "Nothing to save — editor is empty."
		_error_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
		return

	var dlg := AcceptDialog.new()
	dlg.title = "Save Snippet"
	dlg.size = Vector2i(360, 130)
	dlg.exclusive = true

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)

	var lbl := Label.new()
	lbl.text = "Snippet name:"
	lbl.add_theme_font_size_override("font_size", 13)
	vb.add_child(lbl)

	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "My awesome expression"
	name_edit.custom_minimum_size = Vector2(300, 0)
	vb.add_child(name_edit)

	dlg.add_child(vb)
	dlg.ok_button_text = "Save"

	# Capture code for the confirmation callback
	var captured_code := code
	dlg.confirmed.connect(func() -> void:
		var sname := name_edit.text.strip_edges()
		if sname.is_empty():
			sname = "Untitled"
		_save_user_snippet(sname, captured_code)
		dlg.queue_free()
	)
	dlg.canceled.connect(func() -> void: dlg.queue_free())

	add_child(dlg)
	dlg.popup_centered()
	name_edit.grab_focus()


## Deletes a user snippet by index.
func _on_delete_snippet(idx: int) -> void:
	if idx < 0 or idx >= _user_snippets.size():
		return
	var removed_name: String = _user_snippets[idx].get("name", "")
	_user_snippets.remove_at(idx)
	_persist_user_snippets()
	_build_presets_menu(_snippets_popup)
	GNLogger.info("ExprEditor", "Deleted user snippet '%s'" % removed_name)


## Saves a new user snippet and refreshes the menu.
func _save_user_snippet(snippet_name: String, code: String) -> void:
	_user_snippets.append({"name": snippet_name, "code": code})
	_persist_user_snippets()
	_build_presets_menu(_snippets_popup)
	GNLogger.info("ExprEditor", "Saved user snippet '%s'" % snippet_name)


# ─── User Snippet Persistence ────────────────────────────────────────────────

## Loads user snippets from disk (called once per session).
static func _load_user_snippets() -> void:
	if _user_snippets_loaded:
		return
	_user_snippets_loaded = true
	if not FileAccess.file_exists(_USER_SNIPPETS_PATH):
		return
	var f := FileAccess.open(_USER_SNIPPETS_PATH, FileAccess.READ)
	if f == null:
		return
	var json_text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(json_text)
	if parsed is Array:
		_user_snippets.clear()
		for entry in parsed:
			if entry is Dictionary and entry.has("name") and entry.has("code"):
				_user_snippets.append(entry)
		GNLogger.info("ExprEditor", "Loaded %d user snippet(s)" % _user_snippets.size())


## Persists user snippets to disk as JSON.
static func _persist_user_snippets() -> void:
	var data: Array[Dictionary] = []
	for snip in _user_snippets:
		data.append({"name": snip.get("name", ""), "code": snip.get("code", "")})
	var f := FileAccess.open(_USER_SNIPPETS_PATH, FileAccess.WRITE)
	if f == null:
		GNLogger.warn("ExprEditor", "Failed to save user snippets to %s" % _USER_SNIPPETS_PATH)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


# ═══════════════════════════════════════════════════════════════════════════════
# Validation
# ═══════════════════════════════════════════════════════════════════════════════

## Live-validates the expression and shows errors.
func _on_text_changed() -> void:
	var text := _code_edit.text.strip_edges()
	_validate_expression(text)


## Attempts to parse the expression and shows any error.
func _validate_expression(text: String) -> void:
	if text.is_empty():
		_error_label.text = ""
		return

	var expr := Expression.new()
	var input_names := PackedStringArray(["me", "time", "frame", "dt"])
	var err := expr.parse(text, input_names)
	if err != OK:
		_error_label.text = "Error: %s" % expr.get_error_text()
		_error_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	else:
		_error_label.text = "Expression OK"
		_error_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4))
