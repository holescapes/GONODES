class_name GNParameter
extends Resource
## A typed parameter on a GNNode with two value modes:
## CONSTANT and EXPRESSION.  Cross-node references (parameter binds,
## CHOP channel reads) are handled via expression functions — par(),
## chop(), etc. — rather than separate mode machinery.

## The two parameter modes — how the parameter's runtime value is determined.
enum Mode {
	CONSTANT,    ## User-set literal value (slider, spinbox, color picker, etc.)
	EXPRESSION,  ## GDScript expression string evaluated every cook frame
}

## Supported value types for parameters.
enum ValueType {
	FLOAT,
	INT,
	BOOL,
	STRING,
	VECTOR2,
	VECTOR2I,
	VECTOR3,
	VECTOR4,
	COLOR,
	ENUM,
	FILE,  ## Project resource file path (res://…) — shown as a file picker button
	RAMP,  ## Curve / ramp — stores an Array of keypoints [{pos, value, left_tangent, right_tangent}]
}

# ─── Identity ──────────────────────────────────────────────────────────────────

## Parameter name (unique within the owning node).
@export var param_name: String = ""

## Displayed label in the inspector UI.
@export var label: String = ""

## Human-readable description shown as tooltip in the inspector UI.
@export var description: String = ""

## Data type of this parameter.
@export var value_type: ValueType = ValueType.FLOAT

## Current mode determining how the value is resolved at cook time.
@export var mode: Mode = Mode.CONSTANT

# ─── Value Storage ─────────────────────────────────────────────────────────────

## The stored value (for CONSTANT mode, or the last-set value).
@export var value: Variant = 0.0

## Default value used for reset and initial state.
@export var default_value: Variant = 0.0

## Last successfully resolved value (from expression evaluation).
## Used as a fallback if the next evaluation fails.
var resolved_value: Variant = 0.0

## Fallback value returned when expression evaluation fails.
var fallback_value: Variant = 0.0

# ─── Constraints ───────────────────────────────────────────────────────────────

## Minimum allowed value (for numeric types). null = no limit.
@export var min_value: Variant = null

## Maximum allowed value (for numeric types). null = no limit.
@export var max_value: Variant = null

## Step size for UI sliders/spinboxes.
@export var step: float = 0.01

## For ENUM type: array of option labels, e.g., ["Sine", "Triangle", "Square"].
@export var enum_options: PackedStringArray = PackedStringArray()

## For ENUM type: optional Callable that returns a fresh PackedStringArray.
## When set, the inspector calls this before opening the dropdown, so the
## option list always reflects current hardware/state (e.g., connected sensors).
## Signature: func() -> PackedStringArray
var dynamic_enum_callback: Callable = Callable()

## For dynamic ENUM type: the human-readable label of the currently selected option,
## saved in patches so name-based resolution works across sessions even when the
## hardware device order changes. Empty for static enums.
var saved_enum_label: String = ""

## For FILE type: array of file extension filters for the picker dialog.
## Each entry is a wildcard pattern, e.g., "*.ttf", "*.otf", "*.png".
@export var file_filters: PackedStringArray = PackedStringArray()

## For FILE type: how the native browse dialog behaves.
enum FileBrowseMode {
	OPEN_FILE = 0,  ## Pick an existing file (inputs)
	SAVE_FILE = 1,  ## Pick/create an output path (exports)
	OPEN_DIR = 2,   ## Pick a directory / folder
}

## Browse dialog mode for FILE parameters ([enum FileBrowseMode]).
var file_browse_mode: int = FileBrowseMode.OPEN_FILE

## When true, the parameter is displayed in the inspector but cannot be edited
## by the user.  Useful for metadata fields (URLs, credits, etc.).
@export var read_only: bool = false

## When true, this bool parameter renders as a momentary push-button in the
## inspector rather than a toggle checkbox.  The operator's _pre_cook should
## read the value, act on it, then reset it to false (one-shot pulse).
var is_pulse: bool = false

## Optional display group tag.  Consecutive parameters sharing the same
## non-empty display_group are rendered side-by-side in one inspector row.
@export var display_group: String = ""

## When false, the parameter is hidden in the inspector UI.
## Managed automatically when [member visibility_rule] is set.
var visible: bool = true

## Declarative visibility rule — hides/shows this parameter based on another
## parameter's current value.  Format:
##   {"param": "mode", "values": [0, 2]}
## Meaning: "visible when the sibling parameter named 'mode' has value 0 or 2."
## Empty dictionary (default) = always visible.  Evaluated by GNNode's
## [method _apply_visibility_rules] whenever the controlling parameter changes.
var visibility_rule: Dictionary = {}

## When >= -1, this string parameter stores a node-reference ID.
## The value is a GNFamily.Type enum value indicating the expected target
## family, or -1 for "any family".  Default -2 means "not a node reference".
## Used by the base-class get_remote_dependencies() / get_node_reference_params()
## (no operator override needed) and by the inspector UI to show a filtered
## node-picker dropdown.
var node_ref_family: int = -2

# ─── Expression Mode (MVP) ────────────────────────────────────────────────────

## The expression string (GDScript syntax), e.g.: chop("lfo1").value("out") * 10.0
## For scalar types (FLOAT, INT, BOOL, STRING, ENUM, FILE) this is the single expression.
## For multi-dimensional types, use `component_expressions` instead.
@export var expression: String = ""

## Compiled Godot Expression object (cached, recompiled on expression text change).
var _compiled_expression: Expression = null

## Pre-compiled GDScript eval(host, me, time, frame, dt) callable (fast path).
var _compiled_expression_callable: Callable = Callable()

## RefCounted instance backing _compiled_expression_callable.
var _compiled_expression_evaluator: RefCounted = null

## Whether the compiled expression is valid.
var _expression_valid: bool = false

## Last expression error text (for UI display).
var expression_error: String = ""

# ─── Per-Component Expressions (for Vector2, Vector3, Vector4, Color) ─────────
## Each component of a multi-dimensional parameter has its own mode (C/E) and
## expression string, matching the TouchDesigner / Houdini workflow where
## tx, ty, tz are independently controllable.

## Per-component mode: CONSTANT or EXPRESSION. Array length matches component count
## (2 for Vec2/Vec2i, 3 for Vec3, 4 for Vec4/Color). Empty for scalar types.
var component_modes: Array = []  # Array[Mode]

## Per-component expression strings. Same indexing as component_modes.
@export var component_expressions: Array = []  # Array[String]

## Per-component compiled Expression objects.
var _compiled_component_expressions: Array = []  # Array[Expression]

## Per-component compiled GDScript eval callables (parallel to expressions).
var _compiled_component_callables: Array = []  # Array[Callable]

## Per-component RefCounted evaluators backing component callables.
var _compiled_component_evaluators: Array = []  # Array[RefCounted]

## Per-component validity flags.
var _component_expression_valid: Array = []  # Array[bool]

## Per-component error strings (for UI display).
var component_expression_errors: Array = []  # Array[String]

# ─── Expression Profiling ─────────────────────────────────────────────────────

## Last expression evaluation time in microseconds.
var expression_eval_usec: float = 0.0

## Rolling average expression evaluation time in microseconds.
var expression_eval_avg_usec: float = 0.0

## Per-component evaluation times in microseconds.
var component_expression_eval_usec: Array = []  # Array[float]

## Number of samples used for the rolling average.
const _PROFILE_ALPHA: float = 0.1  # Exponential moving average smoothing

# ─── Signals ───────────────────────────────────────────────────────────────────

## Emitted when the value changes (for any mode).
signal value_changed(param_name: String, new_value: Variant)

## Emitted when the mode changes.
signal mode_changed(param_name: String, new_mode: Mode)


# ═══════════════════════════════════════════════════════════════════════════════
# Construction
# ═══════════════════════════════════════════════════════════════════════════════

## Factory method to create a FLOAT parameter with typical settings.
static func create_float(p_name: String, p_default: float,
		p_min: Variant = null, p_max: Variant = null,
		p_step: float = 0.01, p_label: String = "",
		p_description: String = "") -> GNParameter:
	var param := GNParameter.new()
	param.param_name = p_name
	param.label = p_label if not p_label.is_empty() else p_name.capitalize()
	param.description = p_description
	param.value_type = ValueType.FLOAT
	param.default_value = p_default
	param.value = p_default
	param.fallback_value = p_default
	param.resolved_value = p_default
	param.min_value = p_min
	param.max_value = p_max
	param.step = p_step
	return param


## Factory method to create an INT parameter.
static func create_int(p_name: String, p_default: int,
		p_min: Variant = null, p_max: Variant = null,
		p_label: String = "",
		p_description: String = "") -> GNParameter:
	var param := GNParameter.new()
	param.param_name = p_name
	param.label = p_label if not p_label.is_empty() else p_name.capitalize()
	param.description = p_description
	param.value_type = ValueType.INT
	param.default_value = p_default
	param.value = p_default
	param.fallback_value = p_default
	param.resolved_value = p_default
	param.min_value = p_min
	param.max_value = p_max
	param.step = 1.0
	return param


## Factory method to create a BOOL parameter.
static func create_bool(p_name: String, p_default: bool,
		p_label: String = "",
		p_description: String = "") -> GNParameter:
	var param := GNParameter.new()
	param.param_name = p_name
	param.label = p_label if not p_label.is_empty() else p_name.capitalize()
	param.description = p_description
	param.value_type = ValueType.BOOL
	param.default_value = p_default
	param.value = p_default
	param.fallback_value = p_default
	param.resolved_value = p_default
	return param


## Factory method to create a momentary-pulse BOOL parameter.
## Renders as a push-button in the inspector.  The value goes true for
## exactly one cook frame; the operator's _pre_cook should auto-reset it.
static func create_pulse(p_name: String, p_label: String = "",
		p_description: String = "") -> GNParameter:
	var param := GNParameter.new()
	param.param_name = p_name
	param.label = p_label if not p_label.is_empty() else p_name.capitalize()
	param.description = p_description
	param.value_type = ValueType.BOOL
	param.default_value = false
	param.value = false
	param.fallback_value = false
	param.resolved_value = false
	param.is_pulse = true
	return param


## Factory method to create an ENUM parameter.
static func create_enum(p_name: String, p_options: PackedStringArray,
		p_default_index: int = 0, p_label: String = "",
		p_description: String = "") -> GNParameter:
	var param := GNParameter.new()
	param.param_name = p_name
	param.label = p_label if not p_label.is_empty() else p_name.capitalize()
	param.description = p_description
	param.value_type = ValueType.ENUM
	param.enum_options = p_options
	param.default_value = p_default_index
	param.value = p_default_index
	param.fallback_value = p_default_index
	param.resolved_value = p_default_index
	return param


## Factory method to create a VECTOR2 parameter.
static func create_vector2(p_name: String, p_default: Vector2,
		p_label: String = "",
		p_description: String = "") -> GNParameter:
	var param := GNParameter.new()
	param.param_name = p_name
	param.label = p_label if not p_label.is_empty() else p_name.capitalize()
	param.description = p_description
	param.value_type = ValueType.VECTOR2
	param.default_value = p_default
	param.value = p_default
	param.fallback_value = p_default
	param.resolved_value = p_default
	param._ensure_component_arrays()
	return param


## Factory method to create a VECTOR2I parameter.
static func create_vector2i(p_name: String, p_default: Vector2i,
		p_label: String = "",
		p_description: String = "") -> GNParameter:
	var param := GNParameter.new()
	param.param_name = p_name
	param.label = p_label if not p_label.is_empty() else p_name.capitalize()
	param.description = p_description
	param.value_type = ValueType.VECTOR2I
	param.step = 1.0
	param.default_value = p_default
	param.value = p_default
	param.fallback_value = p_default
	param.resolved_value = p_default
	param._ensure_component_arrays()
	return param


## Factory method to create a COLOR parameter.
static func create_color(p_name: String, p_default: Color,
		p_label: String = "",
		p_description: String = "") -> GNParameter:
	var param := GNParameter.new()
	param.param_name = p_name
	param.label = p_label if not p_label.is_empty() else p_name.capitalize()
	param.description = p_description
	param.value_type = ValueType.COLOR
	param.default_value = p_default
	param.value = p_default
	param.fallback_value = p_default
	param.resolved_value = p_default
	param._ensure_component_arrays()
	return param


## Factory method to create a STRING parameter.
static func create_string(p_name: String, p_default: String,
		p_label: String = "",
		p_description: String = "") -> GNParameter:
	var param := GNParameter.new()
	param.param_name = p_name
	param.label = p_label if not p_label.is_empty() else p_name.capitalize()
	param.description = p_description
	param.value_type = ValueType.STRING
	param.default_value = p_default
	param.value = p_default
	param.fallback_value = p_default
	param.resolved_value = p_default
	return param


## Factory method to create a node-reference STRING parameter.
## The resulting parameter stores a node ID string and is automatically
## picked up by the base-class get_remote_dependencies() (no override
## needed) and by the inspector UI (filtered node-picker dropdown).
## [param p_ref_family] is a GNFamily.Type value for the expected target
## family, or -1 for "any family".
static func create_node_ref(p_name: String, p_ref_family: int,
		p_label: String = "",
		p_description: String = "") -> GNParameter:
	var param := GNParameter.new()
	param.param_name = p_name
	param.label = p_label if not p_label.is_empty() else p_name.capitalize()
	param.description = p_description
	param.value_type = ValueType.STRING
	param.default_value = ""
	param.value = ""
	param.fallback_value = ""
	param.resolved_value = ""
	param.node_ref_family = p_ref_family
	return param


## Factory method to create a FILE parameter (project resource picker).
## [param p_filters] is an array of wildcard patterns, e.g.
## [code]PackedStringArray(["*.ttf", "*.otf"])[/code].
## [param p_browse_mode] selects open-file / save-file / open-directory dialog.
static func create_file(p_name: String, p_default: String,
		p_filters: PackedStringArray = PackedStringArray(),
		p_label: String = "",
		p_description: String = "",
		p_browse_mode: int = FileBrowseMode.OPEN_FILE) -> GNParameter:
	var param := GNParameter.new()
	param.param_name = p_name
	param.label = p_label if not p_label.is_empty() else p_name.capitalize()
	param.description = p_description
	param.value_type = ValueType.FILE
	param.file_filters = p_filters
	param.file_browse_mode = p_browse_mode
	param.default_value = p_default
	param.value = p_default
	param.fallback_value = p_default
	param.resolved_value = p_default
	return param


## Factory for a directory/folder FILE parameter (browse opens a folder picker).
static func create_folder(p_name: String, p_default: String,
		p_label: String = "",
		p_description: String = "") -> GNParameter:
	return create_file(p_name, p_default, PackedStringArray(), p_label, p_description,
		FileBrowseMode.OPEN_DIR)


## Factory method to create a RAMP parameter (curve/gradient editor).
## The ramp value is stored as an Array of keypoint Dictionaries:
##   [{"pos": 0.0, "value": 0.0, "left_tangent": 0.0, "right_tangent": 0.0},
##    {"pos": 1.0, "value": 1.0, "left_tangent": 0.0, "right_tangent": 0.0}]
## Position range is 0..1, value range is 0..1.
## [param p_default_keys] defaults to a linear ramp (0→0, 1→1).
static func create_ramp(p_name: String,
		p_default_keys: Array = [],
		p_label: String = "",
		p_description: String = "") -> GNParameter:
	var param := GNParameter.new()
	param.param_name = p_name
	param.label = p_label if not p_label.is_empty() else p_name.capitalize()
	param.description = p_description
	param.value_type = ValueType.RAMP
	# Default linear ramp: bottom-left to top-right
	var keys: Array = p_default_keys if p_default_keys.size() >= 2 else [
		{"pos": 0.0, "value": 0.0, "left_tangent": 0.0, "right_tangent": 0.0},
		{"pos": 1.0, "value": 1.0, "left_tangent": 0.0, "right_tangent": 0.0},
	]
	param.default_value = keys.duplicate(true)
	param.value = keys.duplicate(true)
	param.fallback_value = keys.duplicate(true)
	param.resolved_value = keys.duplicate(true)
	return param


## Evaluates a ramp parameter at position [param t] (0.0–1.0).
## Uses cubic Hermite interpolation between adjacent keypoints.
## Returns the interpolated value (0.0–1.0).
static func sample_ramp(keys: Array, t: float) -> float:
	if keys.is_empty():
		return 0.0
	# Clamp t to [0, 1]
	t = clampf(t, 0.0, 1.0)
	# Single key — return its value
	if keys.size() == 1:
		return float(keys[0].get("value", 0.0))
	# Find the segment: keys must be sorted by pos
	var last_idx := keys.size() - 1
	# Before first key
	if t <= float(keys[0].get("pos", 0.0)):
		return float(keys[0].get("value", 0.0))
	# After last key
	if t >= float(keys[last_idx].get("pos", 1.0)):
		return float(keys[last_idx].get("value", 1.0))
	# Find segment
	for i in range(last_idx):
		var p0: float = float(keys[i].get("pos", 0.0))
		var p1: float = float(keys[i + 1].get("pos", 1.0))
		if t >= p0 and t <= p1:
			var span := p1 - p0
			if span < 1e-8:
				return float(keys[i].get("value", 0.0))
			var local_t := (t - p0) / span
			var v0: float = float(keys[i].get("value", 0.0))
			var v1: float = float(keys[i + 1].get("value", 0.0))
			var m0: float = float(keys[i].get("right_tangent", 0.0)) * span
			var m1: float = float(keys[i + 1].get("left_tangent", 0.0)) * span
			# Cubic Hermite
			var t2 := local_t * local_t
			var t3 := t2 * local_t
			return (2.0 * t3 - 3.0 * t2 + 1.0) * v0 \
				+ (t3 - 2.0 * t2 + local_t) * m0 \
				+ (-2.0 * t3 + 3.0 * t2) * v1 \
				+ (t3 - t2) * m1
	return float(keys[last_idx].get("value", 1.0))


# ═══════════════════════════════════════════════════════════════════════════════
# Value Access
# ═══════════════════════════════════════════════════════════════════════════════

## Sets the parameter value (CONSTANT mode) and emits [signal value_changed].
func set_value(new_value: Variant) -> void:
	var clamped := _clamp_value(new_value)
	if is_pulse and new_value == true:
		value = clamped
		resolved_value = clamped
		value_changed.emit(param_name, value)
		return
	if value != clamped:
		value = clamped
		resolved_value = clamped
		value_changed.emit(param_name, value)


## Returns the current effective value (constant or resolved expression).
func get_resolved_value() -> Variant:
	if mode == Mode.CONSTANT:
		return value
	return resolved_value


## Resets the parameter to its default value and CONSTANT mode.
func reset() -> void:
	mode = Mode.CONSTANT
	value = default_value
	resolved_value = default_value
	expression = ""
	_compiled_expression = null
	_clear_expression_callable()
	_expression_valid = false
	expression_error = ""
	# Reset per-component expressions
	for i in range(component_modes.size()):
		component_modes[i] = Mode.CONSTANT
		component_expressions[i] = ""
		_compiled_component_expressions[i] = null
		_clear_component_callable(i)
		_component_expression_valid[i] = false
		component_expression_errors[i] = ""
	value_changed.emit(param_name, value)


## Restores parameter state from a snapshot (Dictionary from to_dict()) and
## emits change signals so the UI refreshes. Used by undo/redo.
func restore_snapshot(snapshot: Dictionary) -> void:
	from_dict(snapshot)
	value_changed.emit(param_name, value)
	mode_changed.emit(param_name, mode)


# ═══════════════════════════════════════════════════════════════════════════════
# Mode Switching
# ═══════════════════════════════════════════════════════════════════════════════

## Switches this parameter to CONSTANT mode with an optional new value.
func set_constant(new_value: Variant = value) -> void:
	mode = Mode.CONSTANT
	set_value(new_value)
	mode_changed.emit(param_name, mode)


## Switches to EXPRESSION mode and compiles the given expression string.
func set_expression(expr_text: String) -> void:
	mode = Mode.EXPRESSION
	expression = expr_text
	_compile_expression()
	mode_changed.emit(param_name, mode)


## Convenience: sets expression mode with a par() reference to another node's parameter.
## Equivalent to the old BIND mode but uses the expression engine instead.
func set_param_reference(source_node: String, source_param: String) -> void:
	var expr_text := 'par("%s", "%s")' % [source_node, source_param]
	set_expression(expr_text)


## Convenience: sets expression mode with a chop() reference to a CHOP channel.
## Equivalent to the old EXPORT mode but uses the expression engine instead.
func set_chop_reference(source_node: String, channel: String,
		scale: float = 1.0, offset: float = 0.0) -> void:
	var expr_text := 'chop("%s", "%s")' % [source_node, channel]
	if not is_equal_approx(scale, 1.0):
		expr_text += " * %s" % str(scale)
	if not is_equal_approx(offset, 0.0):
		var sign_str := " + " if offset >= 0.0 else " - "
		expr_text += sign_str + str(absf(offset))
	set_expression(expr_text)


# ═══════════════════════════════════════════════════════════════════════════════
# Expression Compilation
# ═══════════════════════════════════════════════════════════════════════════════

## Compiles the current expression string into a Godot Expression object.
## Called internally when the expression text changes.
func _compile_expression() -> void:
	_clear_expression_callable()
	if expression.is_empty():
		_expression_valid = false
		expression_error = "Empty expression"
		_compiled_expression = null
		return

	_compiled_expression = Expression.new()
	# Define the variable names available inside expressions.
	# These are passed positionally via Expression.execute() at eval time.
	# chop(), op(), top() are methods on the base_instance (CookEngine),
	# so they are NOT listed here — Expression calls them directly.
	var input_names := PackedStringArray([
		"me", "time", "frame", "dt",
	])
	var err := _compiled_expression.parse(expression, input_names)
	if err != OK:
		_expression_valid = false
		expression_error = _compiled_expression.get_error_text()
		GNLogger.error("Parameter", "'%s' expression parse error — %s" % [param_name, expression_error])
	else:
		_expression_valid = true
		expression_error = ""
		_build_expression_callable(expression)
		GNLogger.debug("Parameter", "'%s' expression compiled OK: %s" % [param_name, expression])


## Returns the compiled Expression, or null if compilation failed.
func get_compiled_expression() -> Expression:
	if _compiled_expression == null and not expression.is_empty():
		_compile_expression()
	return _compiled_expression if _expression_valid else null


## Returns a pre-compiled eval(host, me, time, frame, dt) callable, or an invalid Callable.
func get_expression_eval_callable() -> Callable:
	if not _expression_valid:
		return Callable()
	if not _compiled_expression_callable.is_valid() and not expression.is_empty():
		if _compiled_expression == null:
			_compile_expression()
		elif _expression_valid:
			_build_expression_callable(expression)
	return _compiled_expression_callable


## Returns true if the expression is compiled and ready to evaluate.
func is_expression_valid() -> bool:
	return _expression_valid and _compiled_expression != null


## Clears the scalar expression callable cache.
func _clear_expression_callable() -> void:
	_compiled_expression_callable = Callable()
	_compiled_expression_evaluator = null


## Clears one component expression callable cache.
func _clear_component_callable(idx: int) -> void:
	if idx < 0:
		return
	if idx < _compiled_component_callables.size():
		_compiled_component_callables[idx] = Callable()
	if idx < _compiled_component_evaluators.size():
		_compiled_component_evaluators[idx] = null


## True when the expression cannot be turned into a single-return GDScript callable.
static func _expression_callable_blocked(expr_text: String) -> bool:
	if expr_text.contains("\n") or expr_text.contains(";"):
		return true
	var re := RegEx.new()
	re.compile("\\b(func|class)\\b")
	return re.search(expr_text) != null


## Rewrites GNCookEngine method calls to host.* without touching longer identifiers or string literals.
static func _rewrite_host_method_calls(expr_text: String) -> String:
	const HOST_METHODS: Array[String] = [
		"cell_by_name",
		"cellf_by_name",
		"lookupf",
		"lookup",
		"par_label",
		"smoothstep",
		"cellf",
		"chopf",
		"chopi",
		"chops",
		"parf",
		"pari",
		"pars",
		"bounce",
		"frames",
		"noise1",
		"noise2",
		"noise3",
		"npoints",
		"ncells",
		"output",
		"set_par",
		"smooth",
		"speed",
		"tstart",
		"trigger",
		"cell",
		"chop",
		"cycle",
		"digits",
		"fetch",
		"fit01",
		"fit",
		"fn",
		"fps",
		"iif",
		"img",
		"lag",
		"log",
		"mat",
		"op",
		"par",
		"pulse",
		"ramp",
		"rand",
		"sop",
		"step",
		"store",
		"tend",
		"top",
		"vol",
		"dat",
	]
	var out := ""
	var i := 0
	var in_string := false
	var string_quote := ""
	while i < expr_text.length():
		var ch: String = expr_text[i]
		if in_string:
			out += ch
			if ch == string_quote and (i == 0 or expr_text[i - 1] != "\\"):
				in_string = false
			i += 1
			continue
		if ch == '"' or ch == "'":
			in_string = true
			string_quote = ch
			out += ch
			i += 1
			continue
		var matched := false
		for method_name in HOST_METHODS:
			var token: String = method_name + "("
			if expr_text.length() - i < token.length():
				continue
			if expr_text.substr(i, token.length()) != token:
				continue
			var prev_is_ident := i > 0 and _is_expression_ident_char(expr_text[i - 1])
			if prev_is_ident:
				continue
			out += "host." + token
			i += token.length()
			matched = true
			break
		if not matched:
			out += ch
			i += 1
	return out


static func _is_expression_ident_char(ch: String) -> bool:
	return ch == "_" \
			or (ch >= "a" and ch <= "z") \
			or (ch >= "A" and ch <= "Z") \
			or (ch >= "0" and ch <= "9")


## Builds _compiled_expression_callable after a successful Expression.parse().
func _build_expression_callable(expr_text: String) -> void:
	_clear_expression_callable()
	if _expression_callable_blocked(expr_text):
		return
	var body := _rewrite_host_method_calls(expr_text)
	var source := "extends RefCounted\n\n@warning_ignore(\"unused_parameter\")\nfunc eval(host, me, time, frame, dt):\n\treturn %s\n" % body
	var script := GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		return
	var evaluator: RefCounted = script.new()
	_compiled_expression_evaluator = evaluator
	_compiled_expression_callable = evaluator.eval


## Builds one component callable after a successful Expression.parse().
func _build_component_expression_callable(idx: int, expr_text: String) -> void:
	_clear_component_callable(idx)
	if _expression_callable_blocked(expr_text):
		return
	var body := _rewrite_host_method_calls(expr_text)
	var source := "extends RefCounted\n\n@warning_ignore(\"unused_parameter\")\nfunc eval(host, me, time, frame, dt):\n\treturn %s\n" % body
	var script := GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		return
	var evaluator: RefCounted = script.new()
	_compiled_component_evaluators[idx] = evaluator
	_compiled_component_callables[idx] = evaluator.eval


# ═══════════════════════════════════════════════════════════════════════════════
# Per-Component Expression Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Returns the number of components for this parameter's type.
## 0 for scalar types (FLOAT, INT, BOOL, STRING, ENUM, FILE).
func get_component_count() -> int:
	match value_type:
		ValueType.VECTOR2, ValueType.VECTOR2I: return 2
		ValueType.VECTOR3: return 3
		ValueType.VECTOR4, ValueType.COLOR: return 4
		_: return 0


## Returns true if this parameter is a multi-dimensional type.
func is_multi_component() -> bool:
	return get_component_count() > 0


## Component label names for UI display (e.g., ["X", "Y"] or ["R", "G", "B", "A"]).
func get_component_labels() -> PackedStringArray:
	match value_type:
		ValueType.VECTOR2, ValueType.VECTOR2I: return PackedStringArray(["X", "Y"])
		ValueType.VECTOR3: return PackedStringArray(["X", "Y", "Z"])
		ValueType.VECTOR4: return PackedStringArray(["X", "Y", "Z", "W"])
		ValueType.COLOR: return PackedStringArray(["R", "G", "B", "A"])
		_: return PackedStringArray()


## Ensures the component arrays are correctly sized.  Called during init or
## whenever the parameter is restored from serialization.
func _ensure_component_arrays() -> void:
	var count := get_component_count()
	if count == 0:
		return
	if component_modes.size() != count:
		component_modes.resize(count)
		component_expressions.resize(count)
		_compiled_component_expressions.resize(count)
		_compiled_component_callables.resize(count)
		_compiled_component_evaluators.resize(count)
		_component_expression_valid.resize(count)
		component_expression_errors.resize(count)
		for i in range(count):
			if component_modes[i] == null:
				component_modes[i] = Mode.CONSTANT
			if component_expressions[i] == null:
				component_expressions[i] = ""
			if _compiled_component_expressions[i] == null:
				_compiled_component_expressions[i] = null
			if _compiled_component_callables[i] == null:
				_compiled_component_callables[i] = Callable()
			if _compiled_component_evaluators[i] == null:
				_compiled_component_evaluators[i] = null
			if _component_expression_valid[i] == null:
				_component_expression_valid[i] = false
			if component_expression_errors[i] == null:
				component_expression_errors[i] = ""


## Sets a single component to EXPRESSION mode with the given expression text.
func set_component_expression(component_idx: int, expr_text: String) -> void:
	_ensure_component_arrays()
	if component_idx < 0 or component_idx >= component_modes.size():
		return
	component_modes[component_idx] = Mode.EXPRESSION
	component_expressions[component_idx] = expr_text
	_compile_component_expression(component_idx)
	# If ANY component is in expression mode, the overall param mode is EXPRESSION
	mode = Mode.EXPRESSION
	mode_changed.emit(param_name, mode)


## Sets a single component back to CONSTANT mode.
## The expression text is preserved so the user can toggle back to Expression
## mode without losing their work.
func set_component_constant(component_idx: int) -> void:
	_ensure_component_arrays()
	if component_idx < 0 or component_idx >= component_modes.size():
		return
	component_modes[component_idx] = Mode.CONSTANT
	# NOTE: component_expressions[idx] is intentionally NOT cleared —
	# the text is preserved so toggling back to Expression restores it.
	# Check if ALL components are back to constant
	var all_constant := true
	for m in component_modes:
		if m != Mode.CONSTANT:
			all_constant = false
			break
	if all_constant:
		mode = Mode.CONSTANT
	mode_changed.emit(param_name, mode)


## Returns true if any component has an active expression.
func has_any_component_expression() -> bool:
	for m in component_modes:
		if m == Mode.EXPRESSION:
			return true
	return false


## Compiles a single component's expression string.
func _compile_component_expression(idx: int) -> void:
	var expr_text: String = component_expressions[idx]
	_clear_component_callable(idx)
	if expr_text.is_empty():
		_component_expression_valid[idx] = false
		component_expression_errors[idx] = "Empty expression"
		_compiled_component_expressions[idx] = null
		return

	var expr := Expression.new()
	var input_names := PackedStringArray(["me", "time", "frame", "dt"])
	var err := expr.parse(expr_text, input_names)
	if err != OK:
		_component_expression_valid[idx] = false
		component_expression_errors[idx] = expr.get_error_text()
		_compiled_component_expressions[idx] = null
		var labels := get_component_labels()
		var label_str: String = labels[idx] if idx < labels.size() else str(idx)
		GNLogger.error("Parameter", "'%s'[%s] expression parse error — %s" % [
			param_name, label_str, component_expression_errors[idx]])
	else:
		_component_expression_valid[idx] = true
		component_expression_errors[idx] = ""
		_compiled_component_expressions[idx] = expr
		_build_component_expression_callable(idx, expr_text)


## Returns the compiled Expression for a component, or null.
func get_compiled_component_expression(idx: int) -> Expression:
	_ensure_component_arrays()
	if idx < 0 or idx >= _compiled_component_expressions.size():
		return null
	if _compiled_component_expressions[idx] == null and not component_expressions[idx].is_empty():
		_compile_component_expression(idx)
	return _compiled_component_expressions[idx] if _component_expression_valid[idx] else null


## Returns a pre-compiled component eval callable, or an invalid Callable.
func get_component_expression_eval_callable(idx: int) -> Callable:
	_ensure_component_arrays()
	if idx < 0 or idx >= _component_expression_valid.size():
		return Callable()
	if not _component_expression_valid[idx]:
		return Callable()
	var callable: Callable = _compiled_component_callables[idx]
	if not callable.is_valid() and not component_expressions[idx].is_empty():
		if _compiled_component_expressions[idx] == null:
			_compile_component_expression(idx)
		elif _component_expression_valid[idx]:
			_build_component_expression_callable(idx, component_expressions[idx])
		callable = _compiled_component_callables[idx]
	return callable if callable is Callable and callable.is_valid() else Callable()


## Returns the constant value of a single component (extracted from the stored value).
func get_component_value(idx: int) -> float:
	match value_type:
		ValueType.VECTOR2:
			var v: Vector2 = value if value is Vector2 else Vector2.ZERO
			return v.x if idx == 0 else v.y
		ValueType.VECTOR2I:
			var v: Vector2i = value if value is Vector2i else Vector2i.ZERO
			return float(v.x if idx == 0 else v.y)
		ValueType.VECTOR3:
			var v: Vector3 = value if value is Vector3 else Vector3.ZERO
			return [v.x, v.y, v.z][idx] if idx < 3 else 0.0
		ValueType.VECTOR4:
			var v: Vector4 = value if value is Vector4 else Vector4.ZERO
			return [v.x, v.y, v.z, v.w][idx] if idx < 4 else 0.0
		ValueType.COLOR:
			var c: Color = value if value is Color else Color.BLACK
			return [c.r, c.g, c.b, c.a][idx] if idx < 4 else 0.0
		_:
			return 0.0


## Sets a single component's constant value (updates the stored vector/color).
func set_component_value(idx: int, val: float) -> void:
	match value_type:
		ValueType.VECTOR2:
			var v: Vector2 = value if value is Vector2 else Vector2.ZERO
			if idx == 0: v.x = val
			else: v.y = val
			set_value(v)
		ValueType.VECTOR2I:
			var v: Vector2i = value if value is Vector2i else Vector2i.ZERO
			if idx == 0: v.x = int(val)
			else: v.y = int(val)
			set_value(v)
		ValueType.VECTOR3:
			var v: Vector3 = value if value is Vector3 else Vector3.ZERO
			match idx:
				0: v.x = val
				1: v.y = val
				2: v.z = val
			set_value(v)
		ValueType.VECTOR4:
			var v: Vector4 = value if value is Vector4 else Vector4.ZERO
			match idx:
				0: v.x = val
				1: v.y = val
				2: v.z = val
				3: v.w = val
			set_value(v)
		ValueType.COLOR:
			var c: Color = value if value is Color else Color.BLACK
			match idx:
				0: c.r = val
				1: c.g = val
				2: c.b = val
				3: c.a = val
			set_value(c)


# ═══════════════════════════════════════════════════════════════════════════════
# Internal Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Clamps a value to [min_value, max_value] if constraints are set.
func _clamp_value(val: Variant) -> Variant:
	if val is float or val is int:
		if min_value != null and val < min_value:
			return min_value
		if max_value != null and val > max_value:
			return max_value
	return val


# ═══════════════════════════════════════════════════════════════════════════════
# Serialization
# ═══════════════════════════════════════════════════════════════════════════════

## Converts a Godot Variant to a JSON-safe representation.
## Handles Vector2, Vector2i, Vector3, Vector4, Color → arrays.
## Primitives (float, int, bool, String) pass through as-is.
static func _variant_to_json(val: Variant) -> Variant:
	if val is Vector2:
		return {"_type": "Vector2", "x": val.x, "y": val.y}
	if val is Vector2i:
		return {"_type": "Vector2i", "x": val.x, "y": val.y}
	if val is Vector3:
		return {"_type": "Vector3", "x": val.x, "y": val.y, "z": val.z}
	if val is Vector4:
		return {"_type": "Vector4", "x": val.x, "y": val.y, "z": val.z, "w": val.w}
	if val is Color:
		return {"_type": "Color", "r": val.r, "g": val.g, "b": val.b, "a": val.a}
	# Ramp keypoints: Array of Dicts — already JSON-safe
	if val is Array:
		return {"_type": "Ramp", "keys": val}
	# float, int, bool, String → JSON-native
	return val


## Reconstructs a Godot Variant from its JSON representation.
static func _json_to_variant(json_val: Variant, target_type: ValueType) -> Variant:
	if json_val is Dictionary and json_val.has("_type"):
		match json_val["_type"]:
			"Vector2":
				return Vector2(json_val["x"], json_val["y"])
			"Vector2i":
				return Vector2i(int(json_val["x"]), int(json_val["y"]))
			"Vector3":
				return Vector3(json_val["x"], json_val["y"], json_val["z"])
			"Vector4":
				return Vector4(json_val["x"], json_val["y"], json_val["z"], json_val["w"])
			"Color":
				return Color(json_val["r"], json_val["g"], json_val["b"], json_val["a"])
	# Ramp data — stored as {"_type": "Ramp", "keys": [...]}
	if json_val is Dictionary and json_val.get("_type") == "Ramp":
		return json_val.get("keys", [])
	# Bare dict without _type — reconstruct from target_type hint
	if json_val is Dictionary:
		match target_type:
			ValueType.VECTOR2I:
				return Vector2i(int(json_val.get("x", 0)), int(json_val.get("y", 0)))
			ValueType.VECTOR2:
				return Vector2(float(json_val.get("x", 0)), float(json_val.get("y", 0)))
			ValueType.VECTOR3:
				return Vector3(float(json_val.get("x", 0)), float(json_val.get("y", 0)), float(json_val.get("z", 0)))
			ValueType.COLOR:
				return Color(float(json_val.get("r", 0)), float(json_val.get("g", 0)), float(json_val.get("b", 0)), float(json_val.get("a", 1)))
	# For numeric types, ensure correct cast
	match target_type:
		ValueType.FLOAT:
			return float(json_val) if json_val != null else 0.0
		ValueType.INT, ValueType.ENUM:
			return int(json_val) if json_val != null else 0
		ValueType.BOOL:
			return bool(json_val) if json_val != null else false
	return json_val


## Serializes this parameter's user-editable state to a Dictionary.
## Only saves state that differs from defaults (compact output).
func to_dict() -> Dictionary:
	var d: Dictionary = {}

	# Always save the current value
	d["value"] = _variant_to_json(value)

	# Save mode if not CONSTANT
	if mode != Mode.CONSTANT:
		d["mode"] = Mode.keys()[mode]  # "EXPRESSION"

	# Save expression text if in expression mode
	if mode == Mode.EXPRESSION and not expression.is_empty():
		d["expression"] = expression

	# Save per-component expressions for multi-dimensional types
	if is_multi_component() and has_any_component_expression():
		var comp_data: Array = []
		for i in range(component_modes.size()):
			comp_data.append({
				"mode": Mode.keys()[component_modes[i]],
				"expression": component_expressions[i],
			})
		d["component_expressions"] = comp_data

	# Persist enum label so name-based resolution works on reload (device order may change)
	if not saved_enum_label.is_empty():
		d["enum_label"] = saved_enum_label

	# Persist the read-only flag so credit/metadata fields survive save/load
	if read_only:
		d["read_only"] = true

	# Persist pulse flag
	if is_pulse:
		d["is_pulse"] = true

	return d


## Restores this parameter's user-editable state from a Dictionary.
## Call after the parameter has been created by the operator's _init_parameters().
func from_dict(d: Dictionary) -> void:
	# Restore mode
	var mode_str: String = d.get("mode", "CONSTANT")
	match mode_str:
		"EXPRESSION":
			mode = Mode.EXPRESSION
		_:
			mode = Mode.CONSTANT

	# Restore value
	if d.has("value"):
		var restored := _json_to_variant(d["value"], value_type)
		value = _clamp_value(restored)
		resolved_value = value
		fallback_value = value

	# Restore expression
	if d.has("expression"):
		expression = d["expression"]
		_compile_expression()

	# Restore per-component expressions
	if d.has("component_expressions"):
		_ensure_component_arrays()
		var comp_data: Array = d["component_expressions"]
		for i in range(mini(comp_data.size(), component_modes.size())):
			var cd: Dictionary = comp_data[i]
			var cm_str: String = cd.get("mode", "CONSTANT")
			component_modes[i] = Mode.EXPRESSION if cm_str == "EXPRESSION" else Mode.CONSTANT
			component_expressions[i] = cd.get("expression", "")
			if component_modes[i] == Mode.EXPRESSION and not component_expressions[i].is_empty():
				_compile_component_expression(i)

	# Restore enum label for name-based device resolution on reload
	if d.has("enum_label"):
		saved_enum_label = d["enum_label"]

	# Restore read-only flag (credit / metadata params)
	if d.has("read_only"):
		read_only = d["read_only"]

	# Restore pulse flag
	if d.has("is_pulse"):
		is_pulse = d["is_pulse"]
