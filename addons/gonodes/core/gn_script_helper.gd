class_name GNScriptHelper
extends RefCounted
## Shared infrastructure for all Script operators (ScriptCHOP, ScriptDAT,
## ScriptSOP, ScriptIMG).  Provides:
##   • Runtime GDScript compilation with preamble injection
##   • @param / @input annotation parsing for dynamic params and ports
##   • Context injection (me, inputs, op, time, frame, dt, helpers)
##   • setup() and cook() dispatch with error handling
##   • Preset load/save (factory + user directories)
##
## Each Script operator holds a GNScriptHelper instance.  The operator's
## _cook() delegates to helper.run_cook() which manages the full lifecycle.


# ═══════════════════════════════════════════════════════════════════════════════
# Constants
# ═══════════════════════════════════════════════════════════════════════════════

## Annotation regex:  # @param <type> <name> <default> <description...>
## Groups: 1=type, 2=name, 3=default, 4=description (optional)
static var _param_regex: RegEx = null

## Input annotation regex:  # @input <family> <description...>
## Groups: 1=family, 2=description (optional)
static var _input_regex: RegEx = null

## Output annotation regex:  # @output <family> <description...>
## Groups: 1=family, 2=description (optional)
static var _output_regex: RegEx = null

## Maps annotation type names to GNParameter.ValueType.
const _TYPE_MAP: Dictionary = {
	"float":  GNParameter.ValueType.FLOAT,
	"int":    GNParameter.ValueType.INT,
	"bool":   GNParameter.ValueType.BOOL,
	"color":  GNParameter.ValueType.COLOR,
	"vec2":   GNParameter.ValueType.VECTOR2,
	"vec2i":  GNParameter.ValueType.VECTOR2I,
	"string": GNParameter.ValueType.STRING,
	"file":   GNParameter.ValueType.FILE,
}

## Maps family annotation strings to family IDs.
## Seeded with core families; extensions append via register_script_family().
## All core families are re-registered at startup by the extension registry,
## so this initial seed is just for robustness if scripts parse before registry runs.
static var _FAMILY_MAP: Dictionary = {
	"top":  GNFamily.Type.TOP,
	"img":  GNFamily.Type.IMG,
	"chop": GNFamily.Type.CHOP,
	"dat":  GNFamily.Type.DAT,
	"sop":  GNFamily.Type.SOP,
	"pop":  GNFamily.Type.POP,
	"vol":  GNFamily.Type.VOL,
	"mat":  GNFamily.Type.MAT,
	"comp": GNFamily.Type.COMP,
	"ui":   GNFamily.Type.UI,
}


## Registers a new family name for @input/@output annotation parsing.
## Call this after GNFamily.register_family() to make the family usable in scripts.
static func register_script_family(name_lower: String, family_id: int) -> void:
	_FAMILY_MAP[name_lower] = family_id

## Preamble injected before user code.  Provides context variables and helper
## methods so the user script can call par(), chop(), op(), etc.
const _PREAMBLE := """extends RefCounted

# ─── Injected context (set by GNScriptHelper before each cook) ───
var me: GNNode = null
var inputs: Array = []
var op = null
var outputs: Array = []
var time: float = 0.0
var frame: int = 0
var dt: float = 0.0
var _engine = null

func par(p_name: String) -> Variant:
	if me == null:
		return null
	return me.get_param_value(p_name)

func chop(id: String, arg2: Variant = "", arg3: Variant = -1, arg4: Variant = -1) -> Variant:
	if _engine == null:
		return 0.0
	return _engine.chop(id, arg2, arg3, arg4)

func op_ref(id: String, param_name: String = "") -> Variant:
	if _engine == null:
		return 0.0
	return _engine.op(id, param_name)

func top(id: String, arg2: Variant = "", arg3: Variant = "") -> Variant:
	if _engine == null:
		return 0.0
	return _engine.top(id, arg2, arg3)

func sop(id: String) -> Variant:
	if _engine == null:
		return null
	return _engine.sop(id)

func dat(id: String, row = null, col = null) -> Variant:
	if _engine == null:
		return null
	return _engine.dat(id, row, col)

func set_par(name_or_node: String, param_or_value = null, value_arg = null) -> bool:
	if _engine == null:
		return false
	return _engine.set_par(name_or_node, param_or_value, value_arg)

func network_add_node(operator_type: String, node_id: String = \"\") -> String:
	if _engine == null:
		return \"\"
	return _engine.network_add_node(operator_type, node_id)

func network_remove_node(node_id: String) -> bool:
	if _engine == null:
		return false
	return _engine.network_remove_node(node_id)

func network_connect(from_id: String, from_port: int, to_id: String, to_port: int) -> bool:
	if _engine == null:
		return false
	return _engine.network_connect(from_id, from_port, to_id, to_port)

func network_disconnect(from_id: String, from_port: int, to_id: String, to_port: int) -> bool:
	if _engine == null:
		return false
	return _engine.network_disconnect(from_id, from_port, to_id, to_port)

func network_node_ids() -> PackedStringArray:
	if _engine == null:
		return PackedStringArray()
	return _engine.network_node_ids()

func network_node_info(node_id: String) -> Dictionary:
	if _engine == null:
		return {}
	return _engine.network_node_info(node_id)

# ─── Logging helpers ─────────────────────────────────────
func log(message: String) -> void:
	GNLogger.info(me.id if me else \"Script\", str(message))

func log_debug(message: String) -> void:
	GNLogger.debug(me.id if me else \"Script\", str(message))

func log_warn(message: String) -> void:
	GNLogger.warn(me.id if me else \"Script\", str(message))

func log_error(message: String) -> void:
	GNLogger.error(me.id if me else \"Script\", str(message))

# ─── USER CODE BELOW ──────────────────────────────────────
"""


# ═══════════════════════════════════════════════════════════════════════════════
# Instance State
# ═══════════════════════════════════════════════════════════════════════════════

## The compiled GDScript resource.
var _script: GDScript = null

## The live instance of the compiled script (reused across frames).
var _instance: RefCounted = null

## Last successfully compiled code (skip recompile when unchanged).
var _last_compiled_code: String = ""

## Whether the current script compiled and loaded successfully.
var script_ok: bool = false

## Compilation error message (empty if OK).
var compile_error: String = ""

## Names of dynamically created parameters from @param annotations.
var dynamic_param_names: PackedStringArray = PackedStringArray()

## Parsed input annotations from the last compile.
var parsed_inputs: Array = []  # Array of { "family": GNFamily.Type, "desc": String }


# ═══════════════════════════════════════════════════════════════════════════════
# Regex Initialization
# ═══════════════════════════════════════════════════════════════════════════════

static func _ensure_regex() -> void:
	if _param_regex == null:
		_param_regex = RegEx.new()
		# Groups: 1=type, 2=name, 3=default_value, 4=description
		_param_regex.compile("^#\\s*@param\\s+(\\w+)\\s+(\\w+)\\s+(\\S+)(?:\\s+(.*))?$")
	if _input_regex == null:
		_input_regex = RegEx.new()
		# Groups: 1=family, 2=description
		_input_regex.compile("^#\\s*@input\\s+(\\w+)(?:\\s+(.*))?$")
	if _output_regex == null:
		_output_regex = RegEx.new()
		# Groups: 1=family, 2=description
		_output_regex.compile("^#\\s*@output\\s+(\\w+)(?:\\s+(.*))?$")


# ═══════════════════════════════════════════════════════════════════════════════
# Pre-reload Syntax Checks
# ═══════════════════════════════════════════════════════════════════════════════

## Lightweight checks run before GDScript.reload() on user code.
## Returns empty string if OK, or a short error message.
static func validate_user_code(code: String) -> String:
	var quote_err := _check_unclosed_quotes(code)
	if not quote_err.is_empty():
		return quote_err
	var func_err := _check_func_param_headers(code)
	if not func_err.is_empty():
		return func_err
	return ""


static func _check_unclosed_quotes(code: String) -> String:
	var in_double := false
	var in_single := false
	var escaped := false
	var i := 0
	while i < code.length():
		var c := code[i]
		if not in_double and not in_single:
			if c == "#":
				while i < code.length() and code[i] != "\n":
					i += 1
				continue
			if c == '"':
				in_double = true
				i += 1
				continue
			if c == "'":
				in_single = true
				i += 1
				continue
		elif in_double:
			if escaped:
				escaped = false
			elif c == "\\":
				escaped = true
			elif c == '"':
				in_double = false
		elif in_single:
			if escaped:
				escaped = false
			elif c == "\\":
				escaped = true
			elif c == "'":
				in_single = false
		i += 1
	if in_double:
		return "Unclosed string (\""
	if in_single:
		return "Unclosed string (')"
	return ""


static func _check_func_param_headers(code: String) -> String:
	var i := 0
	while i < code.length():
		var c := code[i]
		if c == "#":
			while i < code.length() and code[i] != "\n":
				i += 1
		elif c == '"':
			i = _skip_double_quoted(code, i + 1)
		elif c == "'":
			i = _skip_single_quoted(code, i + 1)
		elif _match_keyword_at(code, i, "func"):
			var err := _validate_func_signature_after_keyword(code, i + 4)
			if not err.is_empty():
				return err
			i += 4
		else:
			i += 1
	return ""


static func _validate_func_signature_after_keyword(code: String, start: int) -> String:
	var i := _skip_horizontal_ws(code, start)
	if i >= code.length() or not _is_ident_start(code[i]):
		return ""
	i = _skip_ident(code, i)
	i = _skip_horizontal_ws(code, i)
	if i >= code.length() or code[i] != "(":
		return ""
	return _validate_func_param_list(code, i)


static func _validate_func_param_list(code: String, open_paren_idx: int) -> String:
	var i := open_paren_idx + 1
	var depth := 1
	var expect_name := true
	while i < code.length():
		var c := code[i]
		if c == "#":
			while i < code.length() and code[i] != "\n":
				i += 1
			continue
		if c == '"':
			i = _skip_double_quoted(code, i + 1)
			continue
		if c == "'":
			i = _skip_single_quoted(code, i + 1)
			continue
		if c == "(":
			depth += 1
		elif c == ")":
			depth -= 1
			if depth == 0:
				return ""
		elif depth == 1:
			if c == " " or c == "\t" or c == "\n" or c == "\r":
				pass
			elif c == ":" or c == ",":
				if expect_name:
					return "Expected parameter name"
				if c == ",":
					expect_name = true
			elif _is_ident_start(c):
				i = _skip_ident(code, i)
				expect_name = false
				continue
		i += 1
	return ""


static func _skip_double_quoted(code: String, start: int) -> int:
	var escaped := false
	var i := start
	while i < code.length():
		var c := code[i]
		if escaped:
			escaped = false
		elif c == "\\":
			escaped = true
		elif c == '"':
			return i + 1
		i += 1
	return code.length()


static func _skip_single_quoted(code: String, start: int) -> int:
	var escaped := false
	var i := start
	while i < code.length():
		var c := code[i]
		if escaped:
			escaped = false
		elif c == "\\":
			escaped = true
		elif c == "'":
			return i + 1
		i += 1
	return code.length()


static func _skip_horizontal_ws(code: String, start: int) -> int:
	var i := start
	while i < code.length() and code[i] in " \t":
		i += 1
	return i


static func _skip_ident(code: String, start: int) -> int:
	var i := start
	while i < code.length() and _is_ident_char(code[i]):
		i += 1
	return i


static func _match_keyword_at(code: String, pos: int, keyword: String) -> bool:
	if pos + keyword.length() > code.length():
		return false
	if code.substr(pos, keyword.length()) != keyword:
		return false
	if pos > 0 and _is_ident_char(code[pos - 1]):
		return false
	var after := pos + keyword.length()
	if after < code.length() and _is_ident_char(code[after]):
		return false
	return true


static func _is_ident_start(ch: String) -> bool:
	return (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or ch == "_"


static func _is_ident_char(ch: String) -> bool:
	return _is_ident_start(ch) or (ch >= "0" and ch <= "9")


# ═══════════════════════════════════════════════════════════════════════════════
# Compilation
# ═══════════════════════════════════════════════════════════════════════════════

## Compiles user code into a GDScript class.  Returns true on success.
## On failure, sets compile_error and keeps the old instance alive.
func compile(code: String) -> bool:
	if code == _last_compiled_code and script_ok:
		return true  # Already compiled this exact code

	_last_compiled_code = code

	if code.strip_edges().is_empty():
		compile_error = "Empty script"
		script_ok = false
		return false

	var preflight_err := validate_user_code(code)
	if not preflight_err.is_empty():
		compile_error = preflight_err
		script_ok = false
		return false

	# Build full source: preamble + user code
	var full_source: String = _PREAMBLE + code

	var new_script := GDScript.new()
	new_script.source_code = full_source

	# Attempt compilation
	var err := new_script.reload()
	if err != OK:
		compile_error = "Compilation failed (error %d). Check script syntax." % err
		GNLogger.error("ScriptHelper", compile_error)
		script_ok = false
		return false

	# Create instance
	var new_instance = new_script.new()
	if new_instance == null:
		compile_error = "Failed to instantiate compiled script"
		GNLogger.error("ScriptHelper", compile_error)
		script_ok = false
		return false

	# Verify cook() method exists
	if not new_instance.has_method("cook"):
		compile_error = "Script must define a cook() function"
		GNLogger.error("ScriptHelper", compile_error)
		script_ok = false
		return false

	_script = new_script
	_instance = new_instance
	script_ok = true
	compile_error = ""
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# Context Injection & Execution
# ═══════════════════════════════════════════════════════════════════════════════

## Injects context variables into the script instance and calls cook().
## Returns true if cook() executed without errors.
func run_cook(node: GNNode, inputs: Array[GNData], output: Variant,
		engine: Node) -> bool:
	if not script_ok or _instance == null:
		return false

	# Inject context
	_instance.me = node
	_instance.inputs = inputs
	_instance.op = output
	_instance.time = engine.elapsed_time
	_instance.frame = engine.frame_count
	_instance.dt = engine.current_delta
	_instance._engine = engine

	# Run cook()
	var cook_err := _safe_call(_instance, "cook", node)
	if not cook_err.is_empty():
		GNLogger.error("ScriptHelper", "'%s' cook() error: %s" % [node.id, cook_err])
		return false

	return true


## Captures script errors logged while a user script method runs.
class _CallErrorLogger extends Logger:
	var message: String = ""
	var had_error: bool = false

	func _log_error(_function: String, _file: String, _line: int, _code: String,
			rationale: String, _editor_notify: bool, _error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		had_error = true
		if message.is_empty():
			if not rationale.is_empty():
				message = rationale
			elif not _code.is_empty():
				message = _code
			else:
				message = "script error in %s()" % _function


## Safely calls a Callable with argument array, capturing GDScript runtime errors.
## Returns {ok: bool, value: Variant, error: String}.
static func safe_callv(callable: Callable, args: Array) -> Dictionary:
	if not callable.is_valid():
		return {"ok": false, "value": null, "error": "invalid callable"}
	var err_logger := _CallErrorLogger.new()
	OS.add_logger(err_logger)
	var value: Variant = callable.callv(args)
	if OS.has_method("remove_logger"):
		OS.remove_logger(err_logger)
	return {
		"ok": not err_logger.had_error,
		"value": value,
		"error": err_logger.message,
	}


## Safely calls a method on the instance, catching runtime errors.
## Returns empty string on success, or the error message on failure.
static func _safe_call(instance: RefCounted, method: String, node: GNNode) -> String:
	if not instance.has_method(method):
		return "Method '%s' not found" % method

	var err_logger := _CallErrorLogger.new()
	OS.add_logger(err_logger)
	instance.call(method)
	if OS.has_method("remove_logger"):
		OS.remove_logger(err_logger)

	if err_logger.had_error:
		var msg := err_logger.message
		node.node_warning = msg
		return msg
	node.node_warning = ""
	return ""


# ═══════════════════════════════════════════════════════════════════════════════
# Annotation Parsing — @param
# ═══════════════════════════════════════════════════════════════════════════════

## Parsed parameter annotation record.
class ParamAnnotation:
	var param_name: String
	var type_name: String
	var value_type: GNParameter.ValueType
	var default_value: Variant
	var description: String

	func _init(p_name: String, p_type_name: String, p_value_type: GNParameter.ValueType,
			p_default: Variant, p_desc: String) -> void:
		param_name = p_name
		type_name = p_type_name
		value_type = p_value_type
		default_value = p_default
		description = p_desc


## Parses @param annotations from user code.
## Returns Array[ParamAnnotation] in declaration order.
static func parse_param_annotations(code: String) -> Array:
	_ensure_regex()
	var result: Array = []
	for line in code.split("\n"):
		var stripped := line.strip_edges()
		var m := _param_regex.search(stripped)
		if m == null:
			continue
		var type_name: String = m.get_string(1).to_lower()
		var param_name: String = m.get_string(2)
		var default_str: String = m.get_string(3)
		var desc: String = m.get_string(4).strip_edges() if m.get_string(4) != "" else ""

		if not _TYPE_MAP.has(type_name):
			GNLogger.warn("ScriptHelper", "Unknown @param type '%s' for '%s'" % [type_name, param_name])
			continue

		var value_type: GNParameter.ValueType = _TYPE_MAP[type_name]
		var default_value: Variant = _parse_default(type_name, default_str)

		result.append(ParamAnnotation.new(param_name, type_name, value_type,
			default_value, desc))
	return result


## Converts a default value string to the appropriate Variant.
static func _parse_default(type_name: String, default_str: String) -> Variant:
	match type_name:
		"float":
			return default_str.to_float() if default_str.is_valid_float() else 0.0
		"int":
			return default_str.to_int() if default_str.is_valid_int() else 0
		"bool":
			return default_str.to_lower() == "true"
		"color":
			return Color.from_string(default_str, Color.WHITE)
		"vec2":
			var parts := default_str.split(",")
			if parts.size() >= 2:
				return Vector2(parts[0].strip_edges().to_float(),
					parts[1].strip_edges().to_float())
			return Vector2(default_str.to_float(), default_str.to_float())
		"vec2i":
			var parts := default_str.split(",")
			if parts.size() >= 2:
				return Vector2i(parts[0].strip_edges().to_int(),
					parts[1].strip_edges().to_int())
			return Vector2i(default_str.to_int(), default_str.to_int())
		"string":
			# Strip surrounding quotes if present
			if default_str.begins_with("\"") and default_str.ends_with("\""):
				return default_str.substr(1, default_str.length() - 2)
			return default_str
		"file":
			return ""
	return null


# ═══════════════════════════════════════════════════════════════════════════════
# Annotation Parsing — @input
# ═══════════════════════════════════════════════════════════════════════════════

## Parsed input annotation record.
class InputAnnotation:
	var family: int
	var description: String

	func _init(p_family: int, p_desc: String) -> void:
		family = p_family
		description = p_desc


## Parses @input annotations from user code.
## Returns Array[InputAnnotation] in declaration order.
static func parse_input_annotations(code: String) -> Array:
	_ensure_regex()
	var result: Array = []
	for line in code.split("\n"):
		var stripped := line.strip_edges()
		var m := _input_regex.search(stripped)
		if m == null:
			continue
		var family_name: String = m.get_string(1).to_lower()
		var desc: String = m.get_string(2).strip_edges() if m.get_string(2) != "" else ""

		if not _FAMILY_MAP.has(family_name):
			GNLogger.warn("ScriptHelper", "Unknown @input family '%s'" % family_name)
			continue

		var family_type: int = _FAMILY_MAP[family_name]
		if desc.is_empty():
			desc = "%s input %d" % [family_name.to_upper(), result.size()]

		result.append(InputAnnotation.new(family_type, desc))
	return result


# ═══════════════════════════════════════════════════════════════════════════════
# Annotation Parsing — @output
# ═══════════════════════════════════════════════════════════════════════════════

## Parsed output annotation record (used by GDScriptSCRIPT for multi-output).
class OutputAnnotation:
	var family: int
	var description: String

	func _init(p_family: int, p_desc: String) -> void:
		family = p_family
		description = p_desc


## Parses @output annotations from user code.
## Returns Array[OutputAnnotation] in declaration order.
static func parse_output_annotations(code: String) -> Array:
	_ensure_regex()
	var result: Array = []
	for line in code.split("\n"):
		var stripped := line.strip_edges()
		var m := _output_regex.search(stripped)
		if m == null:
			continue
		var family_name: String = m.get_string(1).to_lower()
		var desc: String = m.get_string(2).strip_edges() if m.get_string(2) != "" else ""

		if not _FAMILY_MAP.has(family_name):
			GNLogger.warn("ScriptHelper", "Unknown @output family '%s'" % family_name)
			continue

		var family_type: int = _FAMILY_MAP[family_name]
		if desc.is_empty():
			desc = "%s output %d" % [family_name.to_upper(), result.size()]

		result.append(OutputAnnotation.new(family_type, desc))
	return result


## Creates a fresh GNData subclass instance for the given family type.
## Used by GDScriptSCRIPT to pre-populate multi-output data objects.
## Delegates to GNFamily._data_factories which covers both core and extension families.
static func create_data_for_family(family: int) -> GNData:
	var data := GNFamily.create_data_for_family(family)
	if data != null:
		return data as GNData
	return GNData.new()


# ═══════════════════════════════════════════════════════════════════════════════
# Dynamic Parameter Rebuild
# ═══════════════════════════════════════════════════════════════════════════════

## Removes old dynamic params, creates new ones from @param annotations,
## preserving values that match by name + type.  Mirrors CustomShaderTOP pattern.
## Returns true if parameters changed.
func rebuild_dynamic_params(node: GNNode, code: String) -> bool:
	var annotations: Array = parse_param_annotations(code)

	# Check if anything changed
	var new_names := PackedStringArray()
	for ann in annotations:
		new_names.append((ann as ParamAnnotation).param_name)
	if new_names == dynamic_param_names:
		return false  # No structural change

	# Snapshot old values for preservation
	var old_values: Dictionary = {}
	for p_name in dynamic_param_names:
		var param := node.get_parameter(p_name)
		if param != null:
			old_values[p_name] = { "value": param.value, "type": param.value_type }

	# Remove old dynamic params
	for p_name in dynamic_param_names:
		if node.parameters.has(p_name):
			var param: GNParameter = node.parameters[p_name]
			if param.value_changed.is_connected(node._on_parameter_changed):
				param.value_changed.disconnect(node._on_parameter_changed)
			if param.mode_changed.is_connected(node._on_parameter_mode_changed):
				param.mode_changed.disconnect(node._on_parameter_mode_changed)
			node.parameters.erase(p_name)
	dynamic_param_names.clear()

	# Create new params from annotations
	for ann in annotations:
		var a: ParamAnnotation = ann as ParamAnnotation
		var param: GNParameter = _create_param_from_annotation(a)
		if param == null:
			continue

		# Restore previous value if same name + type
		if old_values.has(a.param_name):
			var old: Dictionary = old_values[a.param_name]
			if old["type"] == a.value_type:
				param.value = old["value"]
				param.resolved_value = old["value"]

		node.add_parameter(param)
		dynamic_param_names.append(a.param_name)

	GNLogger.info("ScriptHelper", "'%s' dynamic params → %s" % [node.id, str(dynamic_param_names)])
	node.parameters_changed.emit(node.id)
	return true


## Creates a GNParameter from a ParamAnnotation.
static func _create_param_from_annotation(ann: ParamAnnotation) -> GNParameter:
	var desc: String = ann.description if not ann.description.is_empty() \
		else "Script param '%s'" % ann.param_name
	match ann.type_name:
		"float":
			return GNParameter.create_float(ann.param_name, ann.default_value,
				null, null, 0.01, "", desc)
		"int":
			return GNParameter.create_int(ann.param_name, ann.default_value,
				null, null, "", desc)
		"bool":
			return GNParameter.create_bool(ann.param_name, ann.default_value, "", desc)
		"color":
			return GNParameter.create_color(ann.param_name, ann.default_value, "", desc)
		"vec2":
			return GNParameter.create_vector2(ann.param_name, ann.default_value, "", desc)
		"vec2i":
			return GNParameter.create_vector2i(ann.param_name, ann.default_value, "", desc)
		"string":
			return GNParameter.create_string(ann.param_name, ann.default_value, "", desc)
		"file":
			return GNParameter.create_file(ann.param_name, "",
				PackedStringArray(["*.*"]), "", desc)
	return null


# ═══════════════════════════════════════════════════════════════════════════════
# Dynamic Port Rebuild
# ═══════════════════════════════════════════════════════════════════════════════

## Rebuilds input ports from @input annotations.  Returns true if ports changed.
func rebuild_input_ports(node: GNNode, code: String) -> bool:
	var annotations: Array = parse_input_annotations(code)

	# Check if anything changed
	if annotations.size() == parsed_inputs.size():
		var same := true
		for i in range(annotations.size()):
			var new_ann: InputAnnotation = annotations[i] as InputAnnotation
			var old_ann: InputAnnotation = parsed_inputs[i] as InputAnnotation
			if new_ann.family != old_ann.family or new_ann.description != old_ann.description:
				same = false
				break
		if same:
			return false

	parsed_inputs = annotations

	# Rebuild ports
	node.input_ports.clear()
	for i in range(annotations.size()):
		var ann: InputAnnotation = annotations[i] as InputAnnotation
		var family_str: String = GNFamily.get_family_name(ann.family).to_lower()
		node.add_input("in%d" % i, ann.family, false, ann.description)
	GNLogger.info("ScriptHelper", "'%s' input ports → %d (from @input annotations)" % [
		node.id, annotations.size()])
	node.ports_changed.emit(node.id)
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# Full Code Change Handler
# ═══════════════════════════════════════════════════════════════════════════════

## Called when the user's code text changes.  Handles the full lifecycle:
## 1. Parse annotations → rebuild ports and params
## 2. Compile the new code
## 3. Returns true if compilation succeeded
func on_code_changed(node: GNNode, code: String) -> bool:
	rebuild_input_ports(node, code)
	rebuild_dynamic_params(node, code)
	var ok := compile(code)
	if ok:
		_run_setup(node)
	return ok


## Runs setup() eagerly after compilation, injecting only the node reference.
## Consistent with C++/Python which call native_setup()/python_setup() right
## after build/load — before any cook frame.
func _run_setup(node: GNNode) -> void:
	if _instance == null:
		return
	if not _instance.has_method("setup"):
		return
	_instance.me = node
	var setup_err := _safe_call(_instance, "setup", node)
	if not setup_err.is_empty():
		GNLogger.error("ScriptHelper", "'%s' setup() error: %s" % [node.id, setup_err])


# ═══════════════════════════════════════════════════════════════════════════════
# Preset Management
# ═══════════════════════════════════════════════════════════════════════════════

## Factory presets directory (read-only, ships with addon).
## @deprecated Use GNPresetPaths instead.
const FACTORY_PRESET_DIR := "res://addons/gonodes/presets/"

## User presets directory (read-write).
## @deprecated Use GNPresetPaths instead.
const USER_PRESET_DIR := "user://gonodes/presets/code/"


## Returns all available preset names for a given family.
## Returns Array of { "name": String, "path": String, "is_factory": bool }.
static func get_preset_list(family_folder: String) -> Array:
	var result: Array = []
	var dirs := GNPresetPaths.get_code_preset_dirs(family_folder)
	for i in range(dirs.size()):
		var is_factory: bool = i < dirs.size() - 1
		_scan_preset_dir(dirs[i], is_factory, result)
	return result


## Scans a directory for code preset files.
## Recognised extensions: .gd, .gdshader, .fs, .glsl, .frag, .isf, .html, .js, .h, .hpp, .py
static func _scan_preset_dir(dir_path: String, is_factory: bool, result: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	const EXTS := [".gd", ".gdshader", ".fs", ".glsl", ".frag", ".isf", ".html", ".js", ".h", ".hpp", ".py"]
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			for ext in EXTS:
				if fname.ends_with(ext):
					result.append({
						"name": fname.get_basename(),
						"path": dir_path + "/" + fname,
						"is_factory": is_factory,
					})
					break
		fname = dir.get_next()
	dir.list_dir_end()


## Loads a preset file and returns its code text, or empty string on failure.
static func load_preset(file_path: String) -> String:
	if not FileAccess.file_exists(file_path):
		GNLogger.warn("ScriptHelper", "Preset not found: %s" % file_path)
		return ""
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		GNLogger.warn("ScriptHelper", "Cannot open preset: %s" % file_path)
		return ""
	var code := file.get_as_text()
	file.close()
	return code


## Saves user code as a preset.  Creates directories if needed.
## [param file_ext] defaults to ".gd" but can be ".fs", ".glsl", etc.
## Returns true on success.
static func save_preset(family_folder: String, preset_name: String,
		code: String, file_ext: String = ".gd") -> bool:
	var dir_path := GNPresetPaths.get_code_preset_save_dir(family_folder)
	# Ensure directory exists
	if not DirAccess.dir_exists_absolute(dir_path):
		var err := DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK:
			GNLogger.error("ScriptHelper",
				"Cannot create preset directory: %s (error %d)" % [dir_path, err])
			return false
	var ext := file_ext if file_ext.begins_with(".") else "." + file_ext
	var file_path := dir_path + "/" + preset_name + ext
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		GNLogger.error("ScriptHelper",
			"Cannot write preset: %s" % file_path)
		return false
	file.store_string(code)
	file.close()
	GNLogger.info("ScriptHelper", "Saved preset: %s" % file_path)
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# Save / Load Support
# ═══════════════════════════════════════════════════════════════════════════════

## Restores dynamic params from a saved dict AFTER recompilation has created them.
## Call from operator's from_dict() override, after super.from_dict() and on_code_changed().
static func restore_dynamic_param_values(node: GNNode, params_dict: Dictionary,
		static_param_names: PackedStringArray) -> void:
	for param_name in params_dict:
		if param_name in static_param_names:
			continue  # Already restored by super.from_dict()
		var param: GNParameter = node.parameters.get(param_name, null)
		if param != null:
			param.from_dict(params_dict[param_name])
