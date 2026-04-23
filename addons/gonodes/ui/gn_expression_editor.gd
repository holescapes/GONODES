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
	edit.caret_changed.connect(_on_caret_changed)
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

	# Detect context: are we inside chop("..., op("..., par("...?
	var context := _detect_function_context(text_before)

	if context.begins_with("node_id:"):
		# Family-filtered node suggestions (e.g. "node_id:2" for CHOP)
		var family := int(context.substr(8))
		_suggest_node_ids(family)
	elif context == "node_id":
		_suggest_node_ids(-1)
	elif context == "data_completions":
		var node_id := _extract_first_string_arg(text_before)
		_suggest_data_and_info_completions(node_id)
	elif context == "op_param" or context == "par_param":
		var node_id := _extract_first_string_arg(text_before)
		_suggest_op_params(node_id)
	elif context == "fn_name":
		_suggest_fn_names()
	else:
		_suggest_general()


## Detects what kind of autocomplete context we're in based on text before cursor.
## Returns a context string: "node_id:<family>", "data_completions",
## "op_param", "par_param", "fn_name", "node_id", or "" for general.
## Patterns are built dynamically from GNFamily's expression function registry
## so extension-defined families get autocomplete automatically.
func _detect_function_context(text: String) -> String:
	var family_alt := _get_family_func_alternation()
	if family_alt.is_empty():
		family_alt = "(?!x)"  # no family funcs registered — never-match sentinel

	# All family funcs now support port args natively, so second-arg
	# context always suggests data keys/channels.
	var value_alt := _get_value_func_alternation()
	if value_alt.is_empty():
		value_alt = "(?!x)"

	# Pattern: value_func|op|par|set_par("first_arg", "  → suggesting second arg
	var re_second := RegEx.new()
	re_second.compile("(%s|op|par[sfi]?|set_par)\\s*\\(\\s*\"[^\"]*\"\\s*,\\s*\"[^\"]*$" % value_alt)
	var m_second := re_second.search(text)
	if m_second:
		var fn := m_second.get_string(1)
		if fn == "op":
			return "op_param"
		if fn.begins_with("par") or fn == "set_par":
			return "par_param"
		# Family expression func → offer data completions + expression info keys
		if GNFamily.resolve_expression_func_family(fn) >= 0:
			return "data_completions"

	# Pattern: family_func("  → suggesting first arg filtered by family
	var re_family := RegEx.new()
	re_family.compile("(%s)\\s*\\(\\s*\"[^\"]*$" % family_alt)
	var m_family := re_family.search(text)
	if m_family:
		var fn := m_family.get_string(1)
		var family_id := GNFamily.resolve_expression_func_family(fn)
		if family_id >= 0:
			return "node_id:%d" % family_id
		return "node_id"

	# Pattern: op/par/set_par("  → all node types
	var re_any := RegEx.new()
	re_any.compile("(?:op|par[sfi]?|set_par)\\s*\\(\\s*\"[^\"]*$")
	if re_any.search(text):
		return "node_id"

	# Pattern: fn("  → suggesting custom function names
	var re_fn := RegEx.new()
	re_fn.compile("fn\\s*\\(\\s*\"[^\"]*$")
	if re_fn.search(text):
		return "fn_name"

	return ""


## Builds a regex alternation string for all registered expression functions
## including variant suffixes (f/i/s/p/pf), sorted longest-first.
func _get_family_func_alternation() -> String:
	var variants := GNFamily.get_expression_func_variants()
	if variants.is_empty():
		return ""
	return "|".join(variants)


## Builds a regex alternation for non-port-aware variants only (f/i/s).
## Used for second-arg detection where the arg is a data key, not a port.
func _get_value_func_alternation() -> String:
	var variants := GNFamily.get_expression_func_value_variants()
	if variants.is_empty():
		return ""
	return "|".join(variants)


## Extracts the first string argument from a function call.
## E.g., from 'chop("lfo1", "' returns "lfo1".
func _extract_first_string_arg(text: String) -> String:
	var family_alt := _get_family_func_alternation()
	if family_alt.is_empty():
		family_alt = "(?!x)"
	var re := RegEx.new()
	re.compile("(?:%s|op|par[sfi]?|set_par)\\s*\\(\\s*\"([^\"]*)\"" % family_alt)
	var m := re.search(text)
	if m:
		return m.get_string(1)
	return ""


## Suggests node IDs in the network, optionally filtered by output family.
## Pass -1 to show all nodes (for op/par/set_par).
## Supports hierarchical path completion: typing "subnet1/" lists that
## subnetwork's inner nodes.
func _suggest_node_ids(filter_family: int = -1) -> void:
	if network == null:
		return

	# Detect if the user is typing a hierarchical path (contains "/")
	var line := _code_edit.get_line(_code_edit.get_caret_line())
	var col := _code_edit.get_caret_column()
	var text_before := line.substr(0, col)

	# Extract what's been typed inside the current quotes
	var partial := _extract_partial_path(text_before)

	if "/" in partial:
		# Hierarchical path — resolve the prefix and list inner nodes
		_suggest_hierarchical_nodes(partial, filter_family)
	else:
		# Flat — list current network's nodes (+ "../" for parent access)
		_suggest_flat_nodes(filter_family)


## Suggests nodes from the current network level.
func _suggest_flat_nodes(filter_family: int) -> void:
	# Offer "../" to navigate to parent network
	_code_edit.add_code_completion_option(
		CodeEdit.KIND_FILE_PATH, "../", "../",
		Color(0.7, 0.7, 0.5), null, "Parent network")

	for node_id in network.nodes:
		var node: GNNode = network.nodes[node_id]
		if filter_family >= 0 and not _node_has_output_family(node, filter_family):
			continue
		var family_name: String = GNFamily.get_family_name(node.family)
		_code_edit.add_code_completion_option(
			CodeEdit.KIND_VARIABLE, node_id, node_id,
			GNFamily.FAMILY_COLORS.get(node.family, Color(0.55, 0.8, 1.0)),
			null, family_name)

		# If this node is a subnetwork, also offer "node_id/" to drill in
		if "inner_network" in node and node.get("inner_network") != null:
			var display_sub: String = node_id + "/"
			_code_edit.add_code_completion_option(
				CodeEdit.KIND_FILE_PATH, display_sub, display_sub,
				Color(0.7, 0.7, 0.5), null, "Subnetwork — type / to browse")

	_code_edit.update_code_completion_options(true)


## Suggests nodes inside a subnetwork when the user types "subnet1/".
func _suggest_hierarchical_nodes(partial: String, filter_family: int) -> void:
	var segments: PackedStringArray = partial.split("/")
	var prefix: String = "/".join(segments.slice(0, segments.size() - 1))
	var target_net: GNNetwork = _resolve_network_path(prefix)
	if target_net == null:
		_code_edit.update_code_completion_options(true)
		return

	for node_id in target_net.nodes:
		var node: GNNode = target_net.nodes[node_id]
		if filter_family >= 0 and not _node_has_output_family(node, filter_family):
			continue
		var insert_text: String = prefix + "/" + node_id
		var family_name: String = GNFamily.get_family_name(node.family)
		_code_edit.add_code_completion_option(
			CodeEdit.KIND_VARIABLE, node_id, insert_text,
			GNFamily.FAMILY_COLORS.get(node.family, Color(0.55, 0.8, 1.0)),
			null, family_name)

		# Offer further drill-down for nested subnetworks
		if "inner_network" in node and node.get("inner_network") != null:
			var display_nested: String = node_id + "/"
			var insert_deeper: String = prefix + "/" + node_id + "/"
			_code_edit.add_code_completion_option(
				CodeEdit.KIND_FILE_PATH, display_nested, insert_deeper,
				Color(0.7, 0.7, 0.5), null, "Subnetwork")

	_code_edit.update_code_completion_options(true)


## Resolves a path prefix like "../" or "subnet1" or "subnet1/inner" to a GNNetwork.
func _resolve_network_path(prefix: String) -> GNNetwork:
	if prefix.is_empty():
		return network

	var segments := prefix.split("/")
	var current_net: GNNetwork = network

	for seg in segments:
		if seg == "..":
			# Walk up — check if any node in the registry owns current_net
			# For now, parent resolution requires engine context which we
			# don't have, so ".." returns null (parent suggestions are cosmetic).
			return null
		elif seg.is_empty():
			continue
		else:
			var node: GNNode = current_net.nodes.get(seg, null)
			if node == null:
				return null
			if "inner_network" in node:
				var inner = node.get("inner_network")
				if inner is GNNetwork:
					current_net = inner
				else:
					return null
			else:
				return null

	return current_net


## Checks if a node has at least one output port matching the given family.
func _node_has_output_family(node: GNNode, family: int) -> bool:
	for port in node.output_ports:
		if port.family == family:
			return true
	return false


## Extracts the partial text being typed inside the current quoted string.
## E.g., from 'chop("sub1/noi' returns "sub1/noi".
func _extract_partial_path(text: String) -> String:
	# Find the last unmatched opening quote
	var last_quote := text.rfind("\"")
	if last_quote < 0:
		return ""
	return text.substr(last_quote + 1)


## Suggests data-specific completion items (e.g. CHOP channel names) plus
## expression info keys (e.g. "resolution", "aspect" for TOP) for a node.
## Replaces the former type-specific _suggest_data_completions() and
## _suggest_top_properties() with a single polymorphic method.
func _suggest_data_and_info_completions(node_id: String) -> void:
	if network == null or node_id.is_empty():
		return
	var node: GNNode = network.nodes.get(node_id, null)
	if node == null or node.cached_output == null:
		return

	# Data-type-specific completions (e.g. channel names for CHOP)
	var completions := node.cached_output.get_completions()
	for item in completions:
		_code_edit.add_code_completion_option(
			CodeEdit.KIND_MEMBER, item["label"], item["label"],
			Color(0.4, 0.9, 0.5), null, null)

	# Expression info keys (e.g. "resolution", "aspect" for TOP/IMG)
	var info := node.cached_output.get_expression_info()
	for key: String in info:
		_code_edit.add_code_completion_option(
			CodeEdit.KIND_MEMBER, key, key,
			Color(0.7, 0.5, 0.9), null, str(info[key]))

	_code_edit.update_code_completion_options(true)


## Suggests parameter names for a specific node.
func _suggest_op_params(node_id: String) -> void:
	if network == null or node_id.is_empty():
		return
	var node: GNNode = network.nodes.get(node_id, null)
	if node == null:
		return
	for param_name in node.parameters:
		var param: GNParameter = node.parameters[param_name]
		if not param.visible:
			continue
		var desc: String = param.description if not param.description.is_empty() else param.label
		_code_edit.add_code_completion_option(
			CodeEdit.KIND_MEMBER, param_name, param_name,
			Color(0.85, 0.85, 0.75), null, desc)
	_code_edit.update_code_completion_options(true)


## Suggests registered custom function names (for fn("...") autocomplete).
func _suggest_fn_names() -> void:
	for func_name in GNExpressionFunctions.get_names():
		var entry = GNExpressionFunctions.get_all().get(func_name)
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
			["top(\"", "Read TOP info (resolution, aspect)"],
			["par(\"", "Read parameter value (self or cross-node)"],
			["set_par(\"", "Write parameter value on another node"]]:
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
		["ramp(\"", "Sample ramp curve: ramp(param_name, t) or ramp(node, param, t)"],
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
	for func_name in GNExpressionFunctions.get_names():
		var entry = GNExpressionFunctions.get_all().get(func_name)
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
		["Sample ramp (self)", "ramp(\"ramp_param\", time)"],
		["Sample ramp (cross-node)", "ramp(\"node_id\", \"ramp_param\", time)"],
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
		_error_label.add_theme_color_override("default_color", Color(1.0, 0.7, 0.3))
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
	_maybe_request_completion()


## Called when the caret moves (click, arrow keys) without text changing.
func _on_caret_changed() -> void:
	_maybe_request_completion()


## Force-triggers code completion when the caret is inside a recognised
## autocomplete context (node IDs, channels, params).  CodeEdit normally
## suppresses completion inside string color regions, so we bypass that.
func _maybe_request_completion() -> void:
	var line := _code_edit.get_line(_code_edit.get_caret_line())
	var col := _code_edit.get_caret_column()
	var before := line.substr(0, col)
	var ctx := _detect_function_context(before)
	if not ctx.is_empty():
		_code_edit.request_code_completion(true)


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
		_error_label.add_theme_color_override("default_color", Color(1.0, 0.35, 0.3))
	else:
		_error_label.text = "Expression OK"
		_error_label.add_theme_color_override("default_color", Color(0.4, 0.85, 0.4))
