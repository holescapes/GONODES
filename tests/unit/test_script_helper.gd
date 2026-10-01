extends Node
## Unit tests for GNScriptHelper pre-reload syntax validation.


func test_validate_rejects_missing_param_name() -> void:
	var bad := "func cook(:\n\tpass\n"
	var err := GNScriptHelper.validate_user_code(bad)
	GNTestAssert.assert_true(not err.is_empty(), "preflight should fail")
	GNTestAssert.assert_true(err.to_lower().contains("parameter name"),
		"error mentions parameter name, got: %s" % err)


func test_validate_accepts_empty_param_list() -> void:
	var ok := "func cook():\n\tpass\n"
	GNTestAssert.assert_eq(GNScriptHelper.validate_user_code(ok), "", "empty params OK")


func test_validate_accepts_typed_params() -> void:
	var ok := "func cook(a: int):\n\tpass\n"
	GNTestAssert.assert_eq(GNScriptHelper.validate_user_code(ok), "", "typed params OK")


func test_validate_rejects_unclosed_double_quote() -> void:
	var bad := "var x = \"hello\nfunc cook():\n\tpass\n"
	var err := GNScriptHelper.validate_user_code(bad)
	GNTestAssert.assert_true(not err.is_empty(), "preflight should fail")
	GNTestAssert.assert_true(err.to_lower().contains("unclosed"),
		"error mentions unclosed string, got: %s" % err)


func test_compile_rejects_missing_param_name_without_reload() -> void:
	var helper := GNScriptHelper.new()
	var bad := "func cook(:\n\tpass\n"
	var ok := helper.compile(bad)
	GNTestAssert.assert_false(ok, "compile should fail")
	GNTestAssert.assert_false(helper.script_ok, "script_ok stays false")
	GNTestAssert.assert_true(not helper.compile_error.is_empty(), "compile_error set")
	GNTestAssert.assert_true(helper.compile_error.to_lower().contains("parameter name"),
		"compile_error mentions parameter name, got: %s" % helper.compile_error)


func test_compile_accepts_valid_cook() -> void:
	var helper := GNScriptHelper.new()
	GNTestAssert.assert_true(helper.compile("func cook():\n\tpass\n"), "valid cook compiles")
