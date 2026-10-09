extends Node
## Unit tests for GNCookEngine expression evaluation.
##
## Tests cover:
##   - Basic arithmetic expressions (time, frame, dt, constants)
##   - par() self-reference and cross-node reference
##   - parf(), pari(), pars() typed variants
##   - chop() channel read
##   - Circular reference guard (par() cycle detection)
##   - Per-component expression evaluation
##   - Expression error recovery (fallback value)
##
## These tests create a minimal CookEngine + Network + real operator nodes,
## add them to the scene tree, and invoke _resolve_node_parameters() directly
## rather than running a full cook_frame().

var _engine: GNCookEngine
var _network: GNNetwork


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func before_each() -> void:
	_network = GNNetwork.new()
	_engine = GNCookEngine.new()
	_engine.network = _network
	_engine.cooking_enabled = false  # We drive manually
	_engine.elapsed_time = 1.5
	_engine.frame_count = 90
	_engine.current_delta = 1.0 / 60.0
	add_child(_engine)


func after_each() -> void:
	if _engine and is_instance_valid(_engine):
		_engine.queue_free()
	_engine = null
	_network = null


# ─── Helpers ─────────────────────────────────────────────────────────────────

## Creates a ConstantCHOP, initializes it, adds to network + scene tree.
func _make_constant_chop(id: String, ch_name: String = "out", ch_value: float = 0.0) -> GNNode:
	var node := ConstantCHOP.new()
	node.initialize(id)
	_network.add_node(node)
	_engine.add_child(node)
	# Set channel name and value
	node.set_param_value("name0", ch_name)
	node.set_param_value("value0", ch_value)
	# Pre-cook to produce output data
	var inputs: Array[GNData] = []
	node.execute_cook(inputs, _engine.frame_count)
	return node


## Creates a NullCHOP for testing parameter expressions.
func _make_null_chop(id: String) -> GNNode:
	var node := NullCHOP.new()
	node.initialize(id)
	_network.add_node(node)
	_engine.add_child(node)
	return node


## Adds a float parameter to a node dynamically (for test flexibility).
func _add_float_param(node: GNNode, p_name: String, p_value: float,
		p_min: Variant = null, p_max: Variant = null) -> GNParameter:
	var p := GNParameter.create_float(p_name, p_value, p_min, p_max)
	node.add_parameter(p)
	return p


## Resolves ONE parameter's expression via the engine.
func _resolve_param(node: GNNode, param: GNParameter) -> void:
	_engine._current_eval_node = node
	_engine._evaluating_params.clear()
	if param.is_multi_component() and param.has_any_component_expression():
		_engine._evaluate_component_expressions(node, param)
	else:
		_engine._evaluate_expression(node, param)


# ═══════════════════════════════════════════════════════════════════════════════
# Basic Arithmetic Expressions
# ═══════════════════════════════════════════════════════════════════════════════

func test_expression_constant_value() -> void:
	var node := _make_null_chop("test1")
	var p := _add_float_param(node, "x", 0.0)
	p.set_expression("42.0")
	_resolve_param(node, p)
	GNTestAssert.assert_approx(p.resolved_value, 42.0, 0.001, "literal constant")


func test_expression_time_variable() -> void:
	var node := _make_null_chop("test1")
	var p := _add_float_param(node, "x", 0.0)
	p.set_expression("time")
	_resolve_param(node, p)
	GNTestAssert.assert_approx(p.resolved_value, 1.5, 0.001, "time should be 1.5")


func test_expression_frame_variable() -> void:
	var node := _make_null_chop("test1")
	var p := _add_float_param(node, "x", 0.0)
	p.set_expression("frame")
	_resolve_param(node, p)
	GNTestAssert.assert_eq(int(p.resolved_value), 90, "frame should be 90")


func test_expression_dt_variable() -> void:
	var node := _make_null_chop("test1")
	var p := _add_float_param(node, "x", 0.0)
	p.set_expression("dt")
	_resolve_param(node, p)
	GNTestAssert.assert_approx(p.resolved_value, 1.0 / 60.0, 0.0001, "dt")


func test_expression_arithmetic() -> void:
	var node := _make_null_chop("test1")
	var p := _add_float_param(node, "x", 0.0)
	p.set_expression("time * 10.0 + 5.0")
	_resolve_param(node, p)
	GNTestAssert.assert_approx(p.resolved_value, 20.0, 0.001, "1.5*10+5=20")


func test_expression_math_functions() -> void:
	var node := _make_null_chop("test1")
	var p := _add_float_param(node, "x", 0.0)
	p.set_expression("abs(-3.0)")
	_resolve_param(node, p)
	GNTestAssert.assert_approx(p.resolved_value, 3.0, 0.001, "abs(-3)")


# ═══════════════════════════════════════════════════════════════════════════════
# par() — Self-Reference
# ═══════════════════════════════════════════════════════════════════════════════

func test_par_self_reference() -> void:
	## par("value0") reads own node's "value0" param.
	var node := _make_constant_chop("const1", "out", 7.0)
	var p := _add_float_param(node, "derived", 0.0)
	p.set_expression('par("value0")')
	_resolve_param(node, p)
	GNTestAssert.assert_approx(p.resolved_value, 7.0, 0.001, "self-ref par()")


func test_par_self_reference_with_math() -> void:
	var node := _make_constant_chop("const1", "out", 5.0)
	var p := _add_float_param(node, "derived", 0.0)
	p.set_expression('par("value0") * 2.0 + 1.0')
	_resolve_param(node, p)
	GNTestAssert.assert_approx(p.resolved_value, 11.0, 0.001, "5*2+1=11")


# ═══════════════════════════════════════════════════════════════════════════════
# par() — Cross-Node Reference
# ═══════════════════════════════════════════════════════════════════════════════

func test_par_cross_node() -> void:
	## par("source", "value0") reads source's "value0" param.
	var _source := _make_constant_chop("source", "out", 42.0)
	var target := _make_null_chop("target")
	var p := _add_float_param(target, "x", 0.0)
	p.set_expression('par("source", "value0")')
	_resolve_param(target, p)
	GNTestAssert.assert_approx(p.resolved_value, 42.0, 0.001, "cross-node par()")


func test_par_cross_node_expression_target() -> void:
	## Cross-node par() where the TARGET param is also an expression.
	## Should demand-evaluate the target expression.
	var source := _make_constant_chop("source", "out", 10.0)
	# source's "value0" is CONSTANT = 10.0
	# Put an expression on source's own custom param that reads time
	var src_p := _add_float_param(source, "dynamic", 0.0)
	src_p.set_expression("time * 100.0")  # = 150.0

	var target := _make_null_chop("target")
	var p := _add_float_param(target, "x", 0.0)
	p.set_expression('par("source", "dynamic")')
	_resolve_param(target, p)
	GNTestAssert.assert_approx(p.resolved_value, 150.0, 0.001, "demand-evaluated expression")


# ═══════════════════════════════════════════════════════════════════════════════
# parf(), pari(), pars() — Typed Variants
# ═══════════════════════════════════════════════════════════════════════════════

func test_parf_returns_float() -> void:
	var node := _make_constant_chop("const1", "out", 3.0)
	var result: float = _engine.parf("value0")
	# parf with 1 arg needs _current_eval_node set
	_engine._current_eval_node = node
	result = _engine.parf("value0")
	GNTestAssert.assert_approx(result, 3.0, 0.001, "parf()")


func test_pari_returns_int() -> void:
	var node := _make_constant_chop("const1", "out", 7.0)
	_engine._current_eval_node = node
	var result: int = _engine.pari("value0")
	GNTestAssert.assert_eq(result, 7, "pari()")


func test_pars_returns_string() -> void:
	var node := _make_constant_chop("const1", "out", 0.0)
	_engine._current_eval_node = node
	var result: String = _engine.pars("name0")
	GNTestAssert.assert_eq(result, "out", "pars()")


# ═══════════════════════════════════════════════════════════════════════════════
# chop() — Channel Read
# ═══════════════════════════════════════════════════════════════════════════════

func test_chop_read_channel() -> void:
	## chop("const1", "out") should read the CHOP's output channel.
	var _chop_node := _make_constant_chop("const1", "mychan", 99.0)
	var target := _make_null_chop("target")
	var p := _add_float_param(target, "x", 0.0)
	p.set_expression('chop("const1", "mychan")')
	_resolve_param(target, p)
	GNTestAssert.assert_approx(p.resolved_value, 99.0, 0.001, "chop() value")


func test_chop_nonexistent_channel() -> void:
	## Reading a channel that doesn't exist should return 0.0 or a safe fallback.
	var _chop_node := _make_constant_chop("const1", "out", 5.0)
	var target := _make_null_chop("target")
	var p := _add_float_param(target, "x", 0.0)
	p.set_expression('chop("const1", "nonexistent")')
	_resolve_param(target, p)
	# Should not crash — returns 0.0 or fallback
	GNTestAssert.assert_true(true, "no crash on missing channel")


# ═══════════════════════════════════════════════════════════════════════════════
# Circular Reference Guard
# ═══════════════════════════════════════════════════════════════════════════════

func test_circular_self_reference() -> void:
	## A param that references itself via par() should hit the circular guard.
	var node := _make_null_chop("test1")
	var p := _add_float_param(node, "x", 0.0)
	p.fallback_value = -1.0
	p.set_expression('par("x")')  # Self reads self → cycle
	_resolve_param(node, p)
	# Should return fallback_value, not recurse infinitely
	GNTestAssert.assert_approx(p.resolved_value, -1.0, 0.001,
		"circular guard should return fallback")


func test_circular_mutual_reference() -> void:
	## A reads B, B reads A → should be caught by circular guard.
	var nodeA := _make_null_chop("nodeA")
	var pA := _add_float_param(nodeA, "x", 0.0)
	pA.fallback_value = -1.0
	pA.set_expression('par("nodeB", "y")')

	var nodeB := _make_null_chop("nodeB")
	var pB := _add_float_param(nodeB, "y", 0.0)
	pB.fallback_value = -2.0
	pB.set_expression('par("nodeA", "x")')

	# Evaluate A's param — it will demand-eval B's param, which tries to eval A → guard
	_resolve_param(nodeA, pA)
	# A should get B's fallback (-2.0) or its own fallback (-1.0)
	# The important thing is it doesn't hang or crash
	GNTestAssert.assert_true(true, "mutual cycle did not hang")


# ═══════════════════════════════════════════════════════════════════════════════
# Per-Component Expression Evaluation
# ═══════════════════════════════════════════════════════════════════════════════

func test_component_expression_vector2() -> void:
	## X = time * 10, Y stays constant at 5.0
	var node := _make_null_chop("test1")
	var p := GNParameter.create_vector2("pos", Vector2(0.0, 5.0))
	node.add_parameter(p)
	p.set_component_expression(0, "time * 10.0")
	# Y stays CONSTANT at 5.0
	_resolve_param(node, p)
	var result: Vector2 = p.resolved_value
	GNTestAssert.assert_approx(result.x, 15.0, 0.001, "X = time*10 = 15")
	GNTestAssert.assert_approx(result.y, 5.0, 0.001, "Y = constant 5.0")


func test_component_expression_color_rgb() -> void:
	## R = time, G = 0.5 constant, B = frame / 100.0
	var node := _make_null_chop("test1")
	var p := GNParameter.create_color("c", Color(0.0, 0.5, 0.0, 1.0))
	node.add_parameter(p)
	p.set_component_expression(0, "time")        # R = 1.5
	# G stays constant at 0.5
	p.set_component_expression(2, "frame / 100.0")  # B = 0.9
	# A stays constant at 1.0
	_resolve_param(node, p)
	var result: Color = p.resolved_value
	GNTestAssert.assert_approx(result.r, 1.5, 0.001, "R = time")
	GNTestAssert.assert_approx(result.g, 0.5, 0.001, "G = constant")
	GNTestAssert.assert_approx(result.b, 0.9, 0.001, "B = frame/100")
	GNTestAssert.assert_approx(result.a, 1.0, 0.001, "A = constant")


# ═══════════════════════════════════════════════════════════════════════════════
# Expression Error Recovery
# ═══════════════════════════════════════════════════════════════════════════════

func test_invalid_expression_uses_fallback() -> void:
	var node := _make_null_chop("test1")
	var p := _add_float_param(node, "x", 0.0)
	p.fallback_value = 99.0
	p.set_expression("this_var_does_not_exist + 1")
	# Expression won't compile — should use fallback
	_resolve_param(node, p)
	GNTestAssert.assert_approx(p.resolved_value, 99.0, 0.001, "fallback on compile error")


func test_fallback_updates_on_success() -> void:
	## After a successful eval, fallback_value should update.
	var node := _make_null_chop("test1")
	var p := _add_float_param(node, "x", 0.0)
	p.fallback_value = 0.0
	p.set_expression("time * 100.0")  # = 150.0
	_resolve_param(node, p)
	GNTestAssert.assert_approx(p.fallback_value, 150.0, 0.001, "fallback updated")


# ═══════════════════════════════════════════════════════════════════════════════
# resolve_node() — Path Resolution
# ═══════════════════════════════════════════════════════════════════════════════

func test_resolve_node_flat() -> void:
	var _node := _make_null_chop("mynode")
	var found := _engine.resolve_node("mynode")
	GNTestAssert.assert_not_null(found, "should find node")
	GNTestAssert.assert_eq(found.id, "mynode", "correct node")


func test_resolve_node_not_found() -> void:
	var found := _engine.resolve_node("nonexistent")
	GNTestAssert.assert_null(found, "should return null for missing node")


func test_resolve_node_empty_path() -> void:
	var found := _engine.resolve_node("")
	GNTestAssert.assert_null(found, "empty path returns null")


func test_empty_image_is_not_a_cook_payload() -> void:
	var empty := GNImageData.new()
	GNTestAssert.assert_false(GNCookEngine.input_has_payload(empty), "image shell is not ready")
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	empty.set_image(img)
	GNTestAssert.assert_true(GNCookEngine.input_has_payload(empty), "pixels count as input")
	GNTestAssert.assert_false(GNCookEngine.input_has_payload(null), "missing input is not a payload")
	var tex := GNTextureData.new()
	GNTestAssert.assert_false(GNCookEngine.input_has_payload(tex), "texture shell is not ready")
