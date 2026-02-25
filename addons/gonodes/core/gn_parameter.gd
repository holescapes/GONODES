class_name GNParameter
extends Resource
## A typed parameter on a GNNode with four value modes:
## CONSTANT, EXPRESSION, BIND, and EXPORT (last two are post-MVP).
## Handles value storage, mode switching, expression compilation, and
## bind/export metadata.

## The four parameter modes — how the parameter's runtime value is determined.
enum Mode {
	CONSTANT,    ## User-set literal value (slider, spinbox, color picker, etc.)
	EXPRESSION,  ## GDScript expression string evaluated every cook frame
	BIND,        ## Direct pointer to another node's parameter (no string eval)
	EXPORT,      ## Value pushed from a CHOP's export mapping (passive)
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

## The stored value (for CONSTANT mode, or the last-set value for EXPORT mode).
@export var value: Variant = 0.0

## Default value used for reset and initial state.
@export var default_value: Variant = 0.0

## Last successfully resolved value (from expression, bind, or export).
## Used as a fallback if the next evaluation fails.
var resolved_value: Variant = 0.0

## Fallback value returned when expression or bind evaluation fails.
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

## For FILE type: array of file extension filters for the picker dialog.
## Each entry is a wildcard pattern, e.g., "*.ttf", "*.otf", "*.png".
@export var file_filters: PackedStringArray = PackedStringArray()

# ─── Expression Mode (MVP) ────────────────────────────────────────────────────

## The expression string (GDScript syntax), e.g.: chop("lfo1").value("out") * 10.0
@export var expression: String = ""

## Compiled Godot Expression object (cached, recompiled on expression text change).
var _compiled_expression: Expression = null

## Whether the compiled expression is valid.
var _expression_valid: bool = false

## Last expression error text (for UI display).
var expression_error: String = ""

# ─── Bind Mode (Post-MVP) ─────────────────────────────────────────────────────

## Node ID of the bind source (e.g., "ctrl_panel").
@export var bind_source_node: String = ""

## Parameter name on the source node (e.g., "master_scale").
@export var bind_source_param: String = ""

## Optional transform applied after reading the bound value.
var bind_transform: Callable = Callable()


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
	param.default_value = p_default
	param.value = p_default
	param.fallback_value = p_default
	param.resolved_value = p_default
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


## Factory method to create a FILE parameter (project resource picker).
## [param p_filters] is an array of wildcard patterns, e.g.
## [code]PackedStringArray(["*.ttf", "*.otf"])[/code].
static func create_file(p_name: String, p_default: String,
		p_filters: PackedStringArray = PackedStringArray(),
		p_label: String = "",
		p_description: String = "") -> GNParameter:
	var param := GNParameter.new()
	param.param_name = p_name
	param.label = p_label if not p_label.is_empty() else p_name.capitalize()
	param.description = p_description
	param.value_type = ValueType.FILE
	param.file_filters = p_filters
	param.default_value = p_default
	param.value = p_default
	param.fallback_value = p_default
	param.resolved_value = p_default
	return param


# ═══════════════════════════════════════════════════════════════════════════════
# Value Access
# ═══════════════════════════════════════════════════════════════════════════════

## Sets the parameter value (CONSTANT mode) and emits [signal value_changed].
func set_value(new_value: Variant) -> void:
	var clamped := _clamp_value(new_value)
	if value != clamped:
		value = clamped
		resolved_value = clamped
		value_changed.emit(param_name, value)


## Returns the current effective value (constant, resolved expression, bound, or exported).
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
	_expression_valid = false
	expression_error = ""
	bind_source_node = ""
	bind_source_param = ""
	bind_transform = Callable()
	value_changed.emit(param_name, value)


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


## Switches to BIND mode pointing at [param source_node].[param source_param].
func set_bind(source_node: String, source_param: String,
		transform: Callable = Callable()) -> void:
	mode = Mode.BIND
	bind_source_node = source_node
	bind_source_param = source_param
	bind_transform = transform
	mode_changed.emit(param_name, mode)


## Switches to EXPORT mode (passive — value is written by the cook engine's export pass).
func set_export_mode() -> void:
	mode = Mode.EXPORT
	mode_changed.emit(param_name, mode)


# ═══════════════════════════════════════════════════════════════════════════════
# Expression Compilation
# ═══════════════════════════════════════════════════════════════════════════════

## Compiles the current expression string into a Godot Expression object.
## Called internally when the expression text changes.
func _compile_expression() -> void:
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
		GNLogger.debug("Parameter", "'%s' expression compiled OK: %s" % [param_name, expression])


## Returns the compiled Expression, or null if compilation failed.
func get_compiled_expression() -> Expression:
	if _compiled_expression == null and not expression.is_empty():
		_compile_expression()
	return _compiled_expression if _expression_valid else null


## Returns true if the expression is compiled and ready to evaluate.
func is_expression_valid() -> bool:
	return _expression_valid and _compiled_expression != null


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
		d["mode"] = Mode.keys()[mode]  # "EXPRESSION", "BIND", "EXPORT"

	# Save expression text if in expression mode
	if mode == Mode.EXPRESSION and not expression.is_empty():
		d["expression"] = expression

	# Save bind info if in bind mode
	if mode == Mode.BIND:
		if not bind_source_node.is_empty():
			d["bind_source_node"] = bind_source_node
		if not bind_source_param.is_empty():
			d["bind_source_param"] = bind_source_param

	return d


## Restores this parameter's user-editable state from a Dictionary.
## Call after the parameter has been created by the operator's _init_parameters().
func from_dict(d: Dictionary) -> void:
	# Restore mode
	var mode_str: String = d.get("mode", "CONSTANT")
	match mode_str:
		"EXPRESSION":
			mode = Mode.EXPRESSION
		"BIND":
			mode = Mode.BIND
		"EXPORT":
			mode = Mode.EXPORT
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

	# Restore bind info
	if d.has("bind_source_node"):
		bind_source_node = d["bind_source_node"]
	if d.has("bind_source_param"):
		bind_source_param = d["bind_source_param"]
