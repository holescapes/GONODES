class_name GNExpressionFunctions
extends RefCounted
## Registry for user-defined expression functions.
## Built-in utility functions live directly on GNCookEngine as methods.
## Custom user-defined functions are stored here and dispatched via fn().
##
## Usage in expressions:
##   fn("my_func", arg1, arg2)   — calls a registered custom function
##
## Registration:
##   GNExpressionFunctions.register("my_func", some_callable, "Description", ["arg1", "arg2"])

# ─── Types ────────────────────────────────────────────────────────────────────

## Metadata for a registered function.
class FuncEntry:
	var callable: Callable
	var description: String
	var arg_names: Array[String]
	var is_builtin: bool

	func _init(p_callable: Callable, p_description: String = "",
			p_arg_names: Array[String] = [], p_builtin: bool = false) -> void:
		callable = p_callable
		description = p_description
		arg_names = p_arg_names
		is_builtin = p_builtin


# ─── Registry ────────────────────────────────────────────────────────────────

## All registered functions keyed by name.
static var _functions: Dictionary = {}

## Signal-like flag — set to true when functions change so UIs can refresh.
static var _dirty: bool = false


## Registers a custom user-defined function.
static func register(func_name: String, callable: Callable,
		description: String = "", arg_names: Array[String] = []) -> void:
	_functions[func_name] = FuncEntry.new(callable, description, arg_names, false)
	_dirty = true
	GNLogger.info("ExprFunctions", "Registered custom function '%s'" % func_name)


## Registers a built-in function (not removable by users).
static func register_builtin(func_name: String, callable: Callable,
		description: String = "", arg_names: Array[String] = []) -> void:
	_functions[func_name] = FuncEntry.new(callable, description, arg_names, true)


## Unregisters a custom function. Built-in functions cannot be removed.
static func unregister(func_name: String) -> bool:
	if not _functions.has(func_name):
		return false
	var entry: FuncEntry = _functions[func_name]
	if entry.is_builtin:
		GNLogger.warn("ExprFunctions", "Cannot remove built-in function '%s'" % func_name)
		return false
	_functions.erase(func_name)
	_dirty = true
	GNLogger.info("ExprFunctions", "Unregistered custom function '%s'" % func_name)
	return true


## Calls a registered function by name with the given arguments.
static func call_func(func_name: String, args: Array) -> Variant:
	if not _functions.has(func_name):
		GNLogger.warn("ExprFunctions", "Unknown function '%s'" % func_name)
		return 0.0
	var entry: FuncEntry = _functions[func_name]
	return entry.callable.callv(args)


## Returns true if the function exists.
static func has_func(func_name: String) -> bool:
	return _functions.has(func_name)


## Returns all registered functions as Dictionary[String, FuncEntry].
static func get_all() -> Dictionary:
	return _functions


## Returns only user-defined (non-builtin) functions.
static func get_custom() -> Dictionary:
	var result := {}
	for fname in _functions:
		var entry: FuncEntry = _functions[fname]
		if not entry.is_builtin:
			result[fname] = entry
	return result


## Returns only built-in functions.
static func get_builtins() -> Dictionary:
	var result := {}
	for fname in _functions:
		var entry: FuncEntry = _functions[fname]
		if entry.is_builtin:
			result[fname] = entry
	return result


## Returns all function names as a sorted array.
static func get_names() -> Array[String]:
	var names: Array[String] = []
	for fname in _functions:
		names.append(fname)
	names.sort()
	return names


## Checks and clears the dirty flag.
static func consume_dirty() -> bool:
	if _dirty:
		_dirty = false
		return true
	return false
