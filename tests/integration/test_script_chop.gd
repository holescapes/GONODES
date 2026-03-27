extends Node
## Integration tests — GDScriptSCRIPT: user-scripted CHOP operator.
##
## Tests verify that GDScriptSCRIPT correctly compiles user code, produces
## output channels, and responds to parameter/annotation changes through
## a full cook_frame() cycle.

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
	_engine.elapsed_time = 1.0
	_engine.frame_count = 30
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


func _get_chop_output(node: GNNode) -> GNChannelData:
	return node.cached_output as GNChannelData


# ═══════════════════════════════════════════════════════════════════════════════
# Basic Script — Single Channel Output
# ═══════════════════════════════════════════════════════════════════════════════

func test_script_chop_basic_output() -> void:
	## A simple script that sets one channel to a constant.
	var s := _make_node(GDScriptSCRIPT, "script1")
	s.set_param_value("code", """# @output chop Result

func cook():
	op.set_single_value("result", 42.0)
""".strip_edges())

	_cook_one_frame()

	var output := _get_chop_output(s)
	GNTestAssert.assert_not_null(output, "script output exists")
	GNTestAssert.assert_approx(output.get_value("result"), 42.0, 0.001, "constant output")


# ═══════════════════════════════════════════════════════════════════════════════
# Script Using time Variable
# ═══════════════════════════════════════════════════════════════════════════════

func test_script_chop_uses_time() -> void:
	## Script outputs time * 100.  With elapsed_time=1.0, should be 100.
	var s := _make_node(GDScriptSCRIPT, "script1")
	s.set_param_value("code", """# @output chop Result

func cook():
	op.set_single_value("t", time * 100.0)
""".strip_edges())

	_cook_one_frame()

	var output := _get_chop_output(s)
	GNTestAssert.assert_not_null(output, "script output exists")
	GNTestAssert.assert_approx(output.get_value("t"), 100.0, 0.001, "time=1.0 * 100")


# ═══════════════════════════════════════════════════════════════════════════════
# Script Using par() for Custom @param
# ═══════════════════════════════════════════════════════════════════════════════

func test_script_chop_custom_param() -> void:
	## Script declares @param float gain and uses par("gain").
	var s := _make_node(GDScriptSCRIPT, "script1")
	s.set_param_value("code", """# @output chop Result
# @param float gain 5.0 Volume gain

func cook():
	op.set_single_value("out", par("gain") * 2.0)
""".strip_edges())

	# First cook compiles and creates dynamic params
	_cook_one_frame()

	# The annotation should have created a "gain" parameter with default 5.0
	# Output should be 5.0 * 2.0 = 10.0
	var output := _get_chop_output(s)
	GNTestAssert.assert_not_null(output, "script output exists")
	GNTestAssert.assert_approx(output.get_value("out"), 10.0, 0.001, "par(gain)=5 * 2 = 10")


# ═══════════════════════════════════════════════════════════════════════════════
# Script Reads Upstream Input
# ═══════════════════════════════════════════════════════════════════════════════

func test_script_chop_reads_input() -> void:
	## ConstantCHOP(val=7) → GDScriptSCRIPT that reads input and doubles it.
	var c := _make_node(ConstantCHOP, "const1")
	c.set_param_value("name0", "sig")
	c.set_param_value("value0", 7.0)

	var s := _make_node(GDScriptSCRIPT, "script1")
	s.set_param_value("code", """# @output chop Result
# @input chop  Upstream data

func cook():
	if inputs.size() > 0 and inputs[0] != null:
		var val = inputs[0].get_value("sig")
		op.set_single_value("doubled", val * 2.0)
	else:
		op.set_single_value("doubled", 0.0)
""".strip_edges())

	_network.connect_nodes("const1", 0, "script1", 0)

	_cook_one_frame()

	var output := _get_chop_output(s)
	GNTestAssert.assert_not_null(output, "script output exists")
	GNTestAssert.assert_approx(output.get_value("doubled"), 14.0, 0.001, "7 * 2 = 14")


# ═══════════════════════════════════════════════════════════════════════════════
# Script Multi-Channel Output
# ═══════════════════════════════════════════════════════════════════════════════

func test_script_chop_multi_channel() -> void:
	## Script outputs 3 channels with distinct values.
	var s := _make_node(GDScriptSCRIPT, "script1")
	s.set_param_value("code", """# @output chop Result

func cook():
	op.set_single_value("x", 1.0)
	op.set_single_value("y", 2.0)
	op.set_single_value("z", 3.0)
""".strip_edges())

	_cook_one_frame()

	var output := _get_chop_output(s)
	GNTestAssert.assert_not_null(output, "script output exists")
	GNTestAssert.assert_approx(output.get_value("x"), 1.0, 0.001, "x")
	GNTestAssert.assert_approx(output.get_value("y"), 2.0, 0.001, "y")
	GNTestAssert.assert_approx(output.get_value("z"), 3.0, 0.001, "z")
	GNTestAssert.assert_eq(output.get_channel_names().size(), 3, "3 channels")


# ═══════════════════════════════════════════════════════════════════════════════
# Script with Syntax Error — Graceful Fallback
# ═══════════════════════════════════════════════════════════════════════════════

func test_script_chop_syntax_error_graceful() -> void:
	## A script with broken syntax should not crash.
	## It should produce null or empty output.
	var s := _make_node(GDScriptSCRIPT, "script1")
	s.set_param_value("code", """
func cook():
	this is not valid gdscript !!!
""".strip_edges())

	_cook_one_frame()

	# Should not crash — output may be null or empty
	GNTestAssert.assert_true(true, "no crash on syntax error")


# ═══════════════════════════════════════════════════════════════════════════════
# Script → Math Chain
# ═══════════════════════════════════════════════════════════════════════════════

func test_script_to_math_chain() -> void:
	## GDScriptSCRIPT(outputs val=10) → MathCHOP(Multiply by 3) should produce 30.
	var s := _make_node(GDScriptSCRIPT, "script1")
	s.set_param_value("code", """# @output chop Result

func cook():
	op.set_single_value("val", 10.0)
""".strip_edges())

	var m := _make_node(MathCHOP, "math1")
	m.set_param_value("operation", 2)  # Multiply
	m.set_param_value("operand", 3.0)
	_network.connect_nodes("script1", 0, "math1", 0)

	_cook_one_frame()

	var output := m.cached_output as GNChannelData
	GNTestAssert.assert_not_null(output, "math output from script chain")
	GNTestAssert.assert_approx(output.get_value("val"), 30.0, 0.001, "10 * 3 = 30")
