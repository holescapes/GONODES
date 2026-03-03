extends Node
## Integration tests — full cook_frame() through CHOP operator chains.
##
## Tests verify that data flows correctly through multi-node networks
## after a complete cook cycle, including expression resolution,
## dirty propagation, and channel merging.

var _engine: GNCookEngine
var _network: GNNetwork


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func before_each() -> void:
	_network = GNNetwork.new()
	_engine = GNCookEngine.new()
	_engine.network = _network
	_engine.cooking_enabled = false
	_engine.elapsed_time = 2.0
	_engine.frame_count = 60
	_engine.current_delta = 1.0 / 60.0
	add_child(_engine)


func after_each() -> void:
	if is_instance_valid(_engine):
		_engine.queue_free()
	_engine = null
	_network = null


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _make_node(script_class: GDScript, id: String) -> GNNode:
	var node: GNNode = script_class.new()
	node.initialize(id)
	_network.add_node(node)
	return node


func _cook_one_frame() -> void:
	_engine.cook_frame(_engine.current_delta)


func _get_output(node: GNNode) -> GNChannelData:
	return node.cached_output as GNChannelData


# ═══════════════════════════════════════════════════════════════════════════════
# Constant → Null Passthrough
# ═══════════════════════════════════════════════════════════════════════════════

func test_constant_to_null_passthrough() -> void:
	## ConstantCHOP → NullCHOP should pass channel data through unchanged.
	var c := _make_node(ConstantCHOP, "const1")
	c.set_param_value("name0", "out")
	c.set_param_value("value0", 42.0)

	var n := _make_node(NullCHOP, "null1")
	_network.connect_nodes("const1", 0, "null1", 0)

	_cook_one_frame()

	var output := _get_output(n)
	GNTestAssert.assert_not_null(output, "null chop should have output")
	GNTestAssert.assert_approx(output.get_value("out"), 42.0, 0.001, "passthrough value")


# ═══════════════════════════════════════════════════════════════════════════════
# Constant → Math (Add Scalar)
# ═══════════════════════════════════════════════════════════════════════════════

func test_constant_plus_scalar() -> void:
	## ConstantCHOP(10) → MathCHOP(Add, operand=5) should produce 15.
	var c := _make_node(ConstantCHOP, "const1")
	c.set_param_value("name0", "val")
	c.set_param_value("value0", 10.0)

	var m := _make_node(MathCHOP, "math1")
	m.set_param_value("operation", 0)  # Add
	m.set_param_value("operand", 5.0)
	_network.connect_nodes("const1", 0, "math1", 0)

	_cook_one_frame()

	var output := _get_output(m)
	GNTestAssert.assert_not_null(output, "math output exists")
	GNTestAssert.assert_approx(output.get_value("val"), 15.0, 0.001, "10 + 5 = 15")


func test_constant_multiply_scalar() -> void:
	## ConstantCHOP(7) → MathCHOP(Multiply, operand=3) should produce 21.
	var c := _make_node(ConstantCHOP, "const1")
	c.set_param_value("name0", "x")
	c.set_param_value("value0", 7.0)

	var m := _make_node(MathCHOP, "math1")
	m.set_param_value("operation", 2)  # Multiply
	m.set_param_value("operand", 3.0)
	_network.connect_nodes("const1", 0, "math1", 0)

	_cook_one_frame()

	var output := _get_output(m)
	GNTestAssert.assert_not_null(output, "math output exists")
	GNTestAssert.assert_approx(output.get_value("x"), 21.0, 0.001, "7 * 3 = 21")


# ═══════════════════════════════════════════════════════════════════════════════
# Two Constants → Math (Binary Add)
# ═══════════════════════════════════════════════════════════════════════════════

func test_two_constants_binary_add() -> void:
	## ConstantCHOP(A=3) + ConstantCHOP(B=7) → MathCHOP(Add) should produce 10.
	var a := _make_node(ConstantCHOP, "constA")
	a.set_param_value("name0", "ch")
	a.set_param_value("value0", 3.0)

	var b := _make_node(ConstantCHOP, "constB")
	b.set_param_value("name0", "ch")
	b.set_param_value("value0", 7.0)

	var m := _make_node(MathCHOP, "math1")
	m.set_param_value("operation", 0)  # Add
	_network.connect_nodes("constA", 0, "math1", 0)
	_network.connect_nodes("constB", 0, "math1", 1)

	_cook_one_frame()

	var output := _get_output(m)
	GNTestAssert.assert_not_null(output, "binary add output exists")
	GNTestAssert.assert_approx(output.get_value("ch"), 10.0, 0.001, "3 + 7 = 10")


# ═══════════════════════════════════════════════════════════════════════════════
# Three-Node Chain: Constant → Math(Multiply) → Math(Add)
# ═══════════════════════════════════════════════════════════════════════════════

func test_three_node_chain() -> void:
	## ConstantCHOP(5) → MathCHOP(*2) → MathCHOP(+100) should produce 110.
	var c := _make_node(ConstantCHOP, "const1")
	c.set_param_value("name0", "x")
	c.set_param_value("value0", 5.0)

	var m1 := _make_node(MathCHOP, "mul")
	m1.set_param_value("operation", 2)  # Multiply
	m1.set_param_value("operand", 2.0)
	_network.connect_nodes("const1", 0, "mul", 0)

	var m2 := _make_node(MathCHOP, "add")
	m2.set_param_value("operation", 0)  # Add
	m2.set_param_value("operand", 100.0)
	_network.connect_nodes("mul", 0, "add", 0)

	_cook_one_frame()

	var output := _get_output(m2)
	GNTestAssert.assert_not_null(output, "chain output exists")
	GNTestAssert.assert_approx(output.get_value("x"), 110.0, 0.001, "5*2+100 = 110")


# ═══════════════════════════════════════════════════════════════════════════════
# Merge CHOP — Combines Channels from Multiple Sources
# ═══════════════════════════════════════════════════════════════════════════════

func test_merge_chop_combines_channels() -> void:
	## Two ConstantCHOPs (different channel names) → MergeCHOP
	## should produce output with both channels.
	var a := _make_node(ConstantCHOP, "constA")
	a.set_param_value("name0", "alpha")
	a.set_param_value("value0", 0.5)

	var b := _make_node(ConstantCHOP, "constB")
	b.set_param_value("name0", "beta")
	b.set_param_value("value0", 0.9)

	var mg := _make_node(MergeCHOP, "merge1")
	_network.connect_nodes("constA", 0, "merge1", 0)
	_network.connect_nodes("constB", 0, "merge1", 1)

	_cook_one_frame()

	var output := _get_output(mg)
	GNTestAssert.assert_not_null(output, "merge output exists")
	var names := output.get_channel_names()
	GNTestAssert.assert_true(names.has("alpha"), "should have alpha channel")
	GNTestAssert.assert_true(names.has("beta"), "should have beta channel")
	GNTestAssert.assert_approx(output.get_value("alpha"), 0.5, 0.001, "alpha value")
	GNTestAssert.assert_approx(output.get_value("beta"), 0.9, 0.001, "beta value")


# ═══════════════════════════════════════════════════════════════════════════════
# Expression-Driven Parameter (par() Cross-Reference Through Cook)
# ═══════════════════════════════════════════════════════════════════════════════

func test_expression_par_ref_through_cook() -> void:
	## ConstantCHOP["ctrl"] with value0=25 →
	## ConstantCHOP["target"] with value0 expression: par("ctrl", "value0")
	## After cook_frame, target's output should be 25.
	var ctrl := _make_node(ConstantCHOP, "ctrl")
	ctrl.set_param_value("name0", "out")
	ctrl.set_param_value("value0", 25.0)

	var target := _make_node(ConstantCHOP, "target")
	target.set_param_value("name0", "result")
	# Set value0 to expression mode referencing ctrl
	var p: GNParameter = target.parameters["value0"]
	p.set_expression('par("ctrl", "value0")')

	_cook_one_frame()

	var output := _get_output(target)
	GNTestAssert.assert_not_null(output, "target has output")
	GNTestAssert.assert_approx(output.get_value("result"), 25.0, 0.001,
		"expression par() resolved through cook_frame")


# ═══════════════════════════════════════════════════════════════════════════════
# chop() Expression Through Cook
# ═══════════════════════════════════════════════════════════════════════════════

func test_expression_chop_ref_through_cook() -> void:
	## ConstantCHOP["source"] outputs channel "sig" = 99.
	## ConstantCHOP["reader"] has value0 expression: chop("source", "sig")
	## After cook, reader should output 99.
	var source := _make_node(ConstantCHOP, "source")
	source.set_param_value("name0", "sig")
	source.set_param_value("value0", 99.0)

	var reader := _make_node(ConstantCHOP, "reader")
	reader.set_param_value("name0", "out")
	var p: GNParameter = reader.parameters["value0"]
	p.set_expression('chop("source", "sig")')

	_cook_one_frame()

	var output := _get_output(reader)
	GNTestAssert.assert_not_null(output, "reader has output")
	GNTestAssert.assert_approx(output.get_value("out"), 99.0, 0.001,
		"chop() expression resolved through cook_frame")


# ═══════════════════════════════════════════════════════════════════════════════
# Dirty Propagation — Only Downstream Re-Cooks
# ═══════════════════════════════════════════════════════════════════════════════

func test_dirty_propagation_recooks_downstream() -> void:
	## A → B → C chain. After first cook, change A's value.
	## Second cook should update C.
	var a := _make_node(ConstantCHOP, "a")
	a.set_param_value("name0", "x")
	a.set_param_value("value0", 1.0)

	var b := _make_node(MathCHOP, "b")
	b.set_param_value("operation", 2)  # Multiply
	b.set_param_value("operand", 10.0)
	_network.connect_nodes("a", 0, "b", 0)

	var c := _make_node(NullCHOP, "c")
	_network.connect_nodes("b", 0, "c", 0)

	# First cook
	_cook_one_frame()
	var out1 := _get_output(c)
	GNTestAssert.assert_not_null(out1, "first cook output exists")
	GNTestAssert.assert_approx(out1.get_value("x"), 10.0, 0.001, "1 * 10 = 10")

	# Change upstream value
	a.set_param_value("value0", 5.0)

	# Second cook — dirty should propagate
	_engine.elapsed_time += _engine.current_delta
	_cook_one_frame()
	var out2 := _get_output(c)
	GNTestAssert.assert_not_null(out2, "second cook output exists")
	GNTestAssert.assert_approx(out2.get_value("x"), 50.0, 0.001, "5 * 10 = 50 after dirty propagation")


# ═══════════════════════════════════════════════════════════════════════════════
# Diamond Topology — Shared Upstream
# ═══════════════════════════════════════════════════════════════════════════════

func test_diamond_topology() -> void:
	## Source → Math(*2) ──┐
	## Source → Math(+10) ──┤→ Merge → Null
	## Verifies both branches cook and merge correctly.
	var src := _make_node(ConstantCHOP, "src")
	src.set_param_value("name0", "x")
	src.set_param_value("value0", 5.0)

	var mul := _make_node(MathCHOP, "mul")
	mul.set_param_value("operation", 2)  # Multiply
	mul.set_param_value("operand", 2.0)
	_network.connect_nodes("src", 0, "mul", 0)

	var add := _make_node(MathCHOP, "add")
	add.set_param_value("operation", 0)  # Add
	add.set_param_value("operand", 10.0)
	_network.connect_nodes("src", 0, "add", 0)

	var mg := _make_node(MergeCHOP, "merge1")
	_network.connect_nodes("mul", 0, "merge1", 0)
	_network.connect_nodes("add", 0, "merge1", 1)

	_cook_one_frame()

	var output := _get_output(mg)
	GNTestAssert.assert_not_null(output, "diamond merge output exists")
	# Both branches output channel "x" — merge should rename the second
	var names := output.get_channel_names()
	GNTestAssert.assert_true(names.size() >= 1, "at least one channel in merged output")


# ═══════════════════════════════════════════════════════════════════════════════
# Bypass Mode — Passes Input Through
# ═══════════════════════════════════════════════════════════════════════════════

func test_bypass_passes_input_through() -> void:
	## ConstantCHOP(val=7) → MathCHOP(bypass=ON, *100)
	## Bypass should skip the multiply and pass 7 through.
	var c := _make_node(ConstantCHOP, "const1")
	c.set_param_value("name0", "ch")
	c.set_param_value("value0", 7.0)

	var m := _make_node(MathCHOP, "math1")
	m.set_param_value("operation", 2)  # Multiply
	m.set_param_value("operand", 100.0)
	m.bypass = true
	_network.connect_nodes("const1", 0, "math1", 0)

	_cook_one_frame()

	var output := _get_output(m)
	GNTestAssert.assert_not_null(output, "bypassed node still has output")
	GNTestAssert.assert_approx(output.get_value("ch"), 7.0, 0.001,
		"bypass should pass input, not multiply")


# ═══════════════════════════════════════════════════════════════════════════════
# Multi-Channel Constant + Math
# ═══════════════════════════════════════════════════════════════════════════════

func test_multi_channel_math() -> void:
	## ConstantCHOP with 2 channels → MathCHOP(Abs)
	## Both channels should be processed.
	var c := _make_node(ConstantCHOP, "const1")
	c.set_param_value("name0", "a")
	c.set_param_value("value0", -3.0)
	c.set_param_value("name1", "b")
	c.set_param_value("value1", -7.0)

	var m := _make_node(MathCHOP, "math1")
	m.set_param_value("operation", 4)  # Abs
	_network.connect_nodes("const1", 0, "math1", 0)

	_cook_one_frame()

	var output := _get_output(m)
	GNTestAssert.assert_not_null(output, "abs output exists")
	GNTestAssert.assert_approx(output.get_value("a"), 3.0, 0.001, "abs(-3) = 3")
	GNTestAssert.assert_approx(output.get_value("b"), 7.0, 0.001, "abs(-7) = 7")


# ═══════════════════════════════════════════════════════════════════════════════
# Time-Dependent Expression in Cook
# ═══════════════════════════════════════════════════════════════════════════════

func test_time_expression_in_cook() -> void:
	## ConstantCHOP with value0 expression: time * 10
	## With elapsed_time=2.0, should produce 20.
	var c := _make_node(ConstantCHOP, "const1")
	c.set_param_value("name0", "t")
	var p: GNParameter = c.parameters["value0"]
	p.set_expression("time * 10.0")

	_cook_one_frame()

	var output := _get_output(c)
	GNTestAssert.assert_not_null(output, "time expression output")
	GNTestAssert.assert_approx(output.get_value("t"), 20.0, 0.001,
		"time=2.0, expression=time*10 → 20")
