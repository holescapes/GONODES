extends Node
## Unit tests — GDScriptSCRIPT is_sink follows compile validation.


func test_invalid_code_makes_sink() -> void:
	var node := GDScriptSCRIPT.new()
	node.initialize("script1")
	node.set_param_value("code", "func cook(:\n\tpass\n")
	GNTestAssert.assert_true(node.is_sink, "syntax error keeps node as sink")
	node._pre_cook(0.016)
	GNTestAssert.assert_true(node.time_dependent, "invalid code forces time_dependent in _pre_cook")
	GNTestAssert.assert_true(node.dirty, "invalid code keeps node dirty via time_dependent")


func test_valid_code_follows_force_active() -> void:
	var node := GDScriptSCRIPT.new()
	node.initialize("script2")
	node.set_param_value("code", "func cook():\n\tpass\n")
	GNTestAssert.assert_false(node.is_sink, "valid code with Force Active off is not sink")

	node.set_param_value("force_active", true)
	GNTestAssert.assert_true(node.is_sink, "valid code with Force Active on is sink")

	node.set_param_value("force_active", false)
	GNTestAssert.assert_false(node.is_sink, "valid code returns to Force Active value")

	node.set_param_value("time_dependent", false)
	node._pre_cook(0.016)
	GNTestAssert.assert_false(node.time_dependent,
		"valid code with Time Dependent off stays non-time-dependent")


func test_from_dict_invalid_code_makes_sink() -> void:
	var node := GDScriptSCRIPT.new()
	node.initialize("script3")
	node.from_dict({
		"parameters": {
			"code": {"value": "func cook(:\n\tpass\n"},
		},
	})
	GNTestAssert.assert_true(node.is_sink, "from_dict with syntax error keeps node as sink")
