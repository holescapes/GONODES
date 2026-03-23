class_name GNTestAssert
extends RefCounted
## Assertion helpers for GONODES unit tests.
##
## Usage inside test methods:
##   GNTestAssert.assert_eq(actual, expected, "values should match")
##   GNTestAssert.assert_true(condition, "should be true")
##
## The test runner checks _failure_count after each test method.
## Assertions do NOT throw — they record the failure and continue,
## so a single test can report multiple assertion failures.

static var _failure_count: int = 0
static var _last_failure: String = ""
static var _all_failures: Array[String] = []


## Resets the failure state between test methods.
static func _reset() -> void:
	_failure_count = 0
	_last_failure = ""
	_all_failures.clear()


## Records a failure with context.
static func _fail(msg: String) -> void:
	_failure_count += 1
	_last_failure = msg
	_all_failures.append(msg)
	printerr("    ASSERT FAILED: %s" % msg)


# ═══════════════════════════════════════════════════════════════════════════════
# Core Assertions
# ═══════════════════════════════════════════════════════════════════════════════

## Asserts that [param condition] is true.
static func assert_true(condition: bool, msg: String = "") -> void:
	if not condition:
		_fail("Expected true. %s" % msg)


## Asserts that [param condition] is false.
static func assert_false(condition: bool, msg: String = "") -> void:
	if condition:
		_fail("Expected false. %s" % msg)


## Asserts that [param actual] equals [param expected] (using ==).
static func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if actual != expected:
		_fail("Expected '%s' == '%s'. %s" % [str(actual), str(expected), msg])


## Asserts that [param actual] does NOT equal [param unexpected].
static func assert_ne(actual: Variant, unexpected: Variant, msg: String = "") -> void:
	if actual == unexpected:
		_fail("Expected '%s' != '%s'. %s" % [str(actual), str(unexpected), msg])


## Asserts that [param actual] is null.
static func assert_null(actual: Variant, msg: String = "") -> void:
	if actual != null:
		_fail("Expected null, got '%s'. %s" % [str(actual), msg])


## Asserts that [param actual] is NOT null.
static func assert_not_null(actual: Variant, msg: String = "") -> void:
	if actual == null:
		_fail("Expected non-null. %s" % msg)


# ═══════════════════════════════════════════════════════════════════════════════
# Numeric Assertions
# ═══════════════════════════════════════════════════════════════════════════════

## Asserts that two floats are approximately equal (within [param tolerance]).
static func assert_approx(actual: float, expected: float,
		tolerance: float = 0.001, msg: String = "") -> void:
	if absf(actual - expected) > tolerance:
		_fail("Expected ~%s, got %s (tolerance %s). %s" % [
			str(expected), str(actual), str(tolerance), msg])


## Asserts that two Vector3s are approximately equal (per-component tolerance).
static func assert_vec3_approx(actual: Vector3, expected: Vector3,
		tolerance: float = 0.001, msg: String = "") -> void:
	if absf(actual.x - expected.x) > tolerance \
			or absf(actual.y - expected.y) > tolerance \
			or absf(actual.z - expected.z) > tolerance:
		_fail("Expected ~%s, got %s (tolerance %s). %s" % [
			str(expected), str(actual), str(tolerance), msg])


## Asserts that two arrays have the same length and equal elements.
## Works with Array, PackedFloat32Array, PackedStringArray, etc.
static func assert_array_eq(actual: Variant, expected: Variant,
		msg: String = "") -> void:
	var a_size: int = actual.size() if actual != null else -1
	var e_size: int = expected.size() if expected != null else -1
	if a_size != e_size:
		_fail("Array size %d != %d. %s" % [a_size, e_size, msg])
		return
	for i in range(a_size):
		if actual[i] != expected[i]:
			_fail("Array[%d]: '%s' != '%s'. %s" % [i, str(actual[i]), str(expected[i]), msg])
			return


## Asserts that [param actual] is greater than [param threshold].
static func assert_gt(actual: Variant, threshold: Variant, msg: String = "") -> void:
	if actual <= threshold:
		_fail("Expected %s > %s. %s" % [str(actual), str(threshold), msg])


## Asserts that [param actual] is less than [param threshold].
static func assert_lt(actual: Variant, threshold: Variant, msg: String = "") -> void:
	if actual >= threshold:
		_fail("Expected %s < %s. %s" % [str(actual), str(threshold), msg])


## Asserts that [param actual] is within [param min_val]..[param max_val] inclusive.
static func assert_in_range(actual: float, min_val: float, max_val: float,
		msg: String = "") -> void:
	if actual < min_val or actual > max_val:
		_fail("Expected %s in [%s, %s]. %s" % [str(actual), str(min_val), str(max_val), msg])


# ═══════════════════════════════════════════════════════════════════════════════
# String Assertions
# ═══════════════════════════════════════════════════════════════════════════════

## Asserts that [param haystack] contains [param needle].
static func assert_contains(haystack: String, needle: String, msg: String = "") -> void:
	if not haystack.contains(needle):
		_fail("Expected '%s' to contain '%s'. %s" % [haystack, needle, msg])


## Asserts that [param text] is empty.
static func assert_empty(text: String, msg: String = "") -> void:
	if not text.is_empty():
		_fail("Expected empty string, got '%s'. %s" % [text, msg])


## Asserts that [param text] is NOT empty.
static func assert_not_empty(text: String, msg: String = "") -> void:
	if text.is_empty():
		_fail("Expected non-empty string. %s" % msg)


# ═══════════════════════════════════════════════════════════════════════════════
# Collection Assertions
# ═══════════════════════════════════════════════════════════════════════════════

## Asserts that [param collection] has exactly [param expected_size] elements.
## Works with Array, Dictionary, PackedStringArray, etc.
static func assert_size(collection: Variant, expected_size: int, msg: String = "") -> void:
	var actual_size: int = collection.size() if collection != null else 0
	if actual_size != expected_size:
		_fail("Expected size %d, got %d. %s" % [expected_size, actual_size, msg])


## Asserts that [param dict] has a key [param key].
static func assert_has_key(dict: Dictionary, key: Variant, msg: String = "") -> void:
	if not dict.has(key):
		_fail("Expected dictionary to have key '%s'. %s" % [str(key), msg])


# ═══════════════════════════════════════════════════════════════════════════════
# Type Assertions
# ═══════════════════════════════════════════════════════════════════════════════

## Asserts that [param actual] is an instance of the given type string (e.g., "GNParameter").
static func assert_is(actual: Variant, type_name: String, msg: String = "") -> void:
	if actual == null:
		_fail("Expected instance of '%s', got null. %s" % [type_name, msg])
		return
	if not (actual is Object):
		_fail("Expected Object of type '%s', got %s. %s" % [type_name, typeof(actual), msg])
		return
	var obj: Object = actual
	if not obj.get_class() == type_name and not (obj is RefCounted and obj.get_script() != null):
		# Check script class name
		if obj.get_script() != null:
			var script_name: String = obj.get_script().get_global_name()
			if script_name != type_name:
				_fail("Expected '%s', got '%s'. %s" % [type_name, script_name, msg])
		else:
			_fail("Expected '%s', got '%s'. %s" % [type_name, obj.get_class(), msg])
