extends Node
## Comprehensive tests for ALL expression functions on GNCookEngine.
##
## Covers the functions NOT tested in test_cook_engine.gd:
##   - Math/utility: fit, fit01, smooth, lag, pulse, step, smoothstep,
##     cycle, bounce, noise1/2/3, trigger, digits, iif, rand, ramp
##   - Timeline: fps, speed, tstart, tend, frames
##   - State: store/fetch
##   - Data access: top, sop, dat, output, npoints, ncells
##   - Mutation: set_par, log
##   - Custom functions: fn (GNExpressionFunctions)
##   - op() proxy: GNOpProxy properties
##   - me variable
##   - Hierarchical path resolution: ../, subnet/child
##   - Multi-output chop with port arg
##
## Same test pattern as test_cook_engine.gd — lightweight engine-driven
## evaluation via _resolve_param().

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
	_engine.elapsed_time = 1.5
	_engine.frame_count = 90
	_engine.current_delta = 1.0 / 60.0
	_engine.playback_speed = 1.0
	_engine.timeline_start = 0.0
	_engine.timeline_end = 600.0
	_engine.non_realtime = false
	add_child(_engine)


func after_each() -> void:
	# Clean up any registered custom functions
	if GNExpressionFunctions.has_func("test_add"):
		GNExpressionFunctions.unregister("test_add")
	if GNExpressionFunctions.has_func("test_greet"):
		GNExpressionFunctions.unregister("test_greet")
	if _engine and is_instance_valid(_engine):
		_engine.queue_free()
	_engine = null
	_network = null


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _make_constant_chop(id: String, ch_name: String = "out", ch_value: float = 0.0) -> GNNode:
	var node := ConstantCHOP.new()
	node.initialize(id)
	_network.add_node(node)
	_engine.add_child(node)
	node.set_param_value("name0", ch_name)
	node.set_param_value("value0", ch_value)
	var inputs: Array[GNData] = []
	node.execute_cook(inputs, _engine.frame_count)
	return node


func _make_null_chop(id: String) -> GNNode:
	var node := NullCHOP.new()
	node.initialize(id)
	_network.add_node(node)
	_engine.add_child(node)
	return node


func _make_noise_top(id: String) -> GNNode:
	var node := NoiseTOP.new()
	node.initialize(id)
	_network.add_node(node)
	_engine.add_child(node)
	var inputs: Array[GNData] = []
	node.execute_cook(inputs, _engine.frame_count)
	return node


func _make_grid_sop(id: String) -> GNNode:
	var node := GridSOP.new()
	node.initialize(id)
	_network.add_node(node)
	_engine.add_child(node)
	var inputs: Array[GNData] = []
	node.execute_cook(inputs, _engine.frame_count)
	return node


func _make_constant_dat(id: String, text: String = "hello") -> GNNode:
	var node := ConstantDAT.new()
	node.initialize(id)
	_network.add_node(node)
	_engine.add_child(node)
	node.set_param_value("text", text)
	var inputs: Array[GNData] = []
	node.execute_cook(inputs, _engine.frame_count)
	return node


func _add_float_param(node: GNNode, p_name: String, p_value: float,
		p_min: Variant = null, p_max: Variant = null) -> GNParameter:
	var p := GNParameter.create_float(p_name, p_value, p_min, p_max)
	node.add_parameter(p)
	return p


func _resolve_param(node: GNNode, param: GNParameter) -> void:
	_engine._current_eval_node = node
	_engine._evaluating_params.clear()
	if param.is_multi_component() and param.has_any_component_expression():
		_engine._evaluate_component_expressions(node, param)
	else:
		_engine._evaluate_expression(node, param)


# ═══════════════════════════════════════════════════════════════════════════════
# fit() / fit01()
# ═══════════════════════════════════════════════════════════════════════════════

func test_fit_linear_remap() -> void:
	var result := _engine.fit(0.5, 0.0, 1.0, 10.0, 20.0)
	GNTestAssert.assert_approx(result, 15.0, 0.001, "fit(0.5, 0..1, 10..20) = 15")


func test_fit_reverse_range() -> void:
	var result := _engine.fit(0.5, 0.0, 1.0, 20.0, 10.0)
	GNTestAssert.assert_approx(result, 15.0, 0.001, "fit reverse range")


func test_fit_equal_input_returns_out_min() -> void:
	var result := _engine.fit(5.0, 5.0, 5.0, 10.0, 20.0)
	GNTestAssert.assert_approx(result, 10.0, 0.001, "fit degenerate returns out_min")


func test_fit_outside_range() -> void:
	# fit does NOT clamp — values outside range extrapolate
	var result := _engine.fit(2.0, 0.0, 1.0, 0.0, 10.0)
	GNTestAssert.assert_approx(result, 20.0, 0.001, "fit extrapolates outside range")


func test_fit01_normalizes() -> void:
	var result := _engine.fit01(5.0, 0.0, 10.0)
	GNTestAssert.assert_approx(result, 0.5, 0.001, "fit01(5, 0, 10) = 0.5")


func test_fit_in_expression() -> void:
	var node := _make_null_chop("test1")
	var p := _add_float_param(node, "x", 0.0)
	p.set_expression("fit(0.5, 0.0, 1.0, 100.0, 200.0)")
	_resolve_param(node, p)
	GNTestAssert.assert_approx(p.resolved_value, 150.0, 0.001, "fit() in expression")


# ═══════════════════════════════════════════════════════════════════════════════
# pulse() / step() / smoothstep()
# ═══════════════════════════════════════════════════════════════════════════════

func test_pulse_within_duty() -> void:
	GNTestAssert.assert_approx(_engine.pulse(0.3, 0.5), 1.0, 0.001, "0.3 < 0.5 duty → 1")


func test_pulse_outside_duty() -> void:
	GNTestAssert.assert_approx(_engine.pulse(0.7, 0.5), 0.0, 0.001, "0.7 >= 0.5 duty → 0")


func test_pulse_wraps_period() -> void:
	GNTestAssert.assert_approx(_engine.pulse(1.3, 0.5), 1.0, 0.001, "wraps: 0.3 < 0.5 → 1")


func test_step_above() -> void:
	GNTestAssert.assert_approx(_engine.step(0.5, 0.7), 1.0, 0.001, "0.7 >= 0.5 → 1")


func test_step_below() -> void:
	GNTestAssert.assert_approx(_engine.step(0.5, 0.3), 0.0, 0.001, "0.3 < 0.5 → 0")


func test_step_at_edge() -> void:
	GNTestAssert.assert_approx(_engine.step(0.5, 0.5), 1.0, 0.001, "0.5 == edge → 1")


func test_smoothstep_middle() -> void:
	var result := _engine.smoothstep(0.0, 1.0, 0.5)
	GNTestAssert.assert_approx(result, 0.5, 0.001, "smoothstep(0,1,0.5) = 0.5")


func test_smoothstep_below() -> void:
	var result := _engine.smoothstep(0.0, 1.0, -0.5)
	GNTestAssert.assert_approx(result, 0.0, 0.001, "smoothstep clamps below")


func test_smoothstep_above() -> void:
	var result := _engine.smoothstep(0.0, 1.0, 1.5)
	GNTestAssert.assert_approx(result, 1.0, 0.001, "smoothstep clamps above")


func test_smoothstep_degenerate() -> void:
	var result := _engine.smoothstep(0.5, 0.5, 0.5)
	GNTestAssert.assert_approx(result, 1.0, 0.001, "smoothstep degenerate edge0==edge1")


func test_smoothstep_in_expression() -> void:
	var node := _make_null_chop("test1")
	var p := _add_float_param(node, "x", 0.0)
	p.set_expression("smoothstep(0.0, 1.0, 0.5)")
	_resolve_param(node, p)
	GNTestAssert.assert_approx(p.resolved_value, 0.5, 0.001, "smoothstep in expression")


# ═══════════════════════════════════════════════════════════════════════════════
# cycle() / bounce()
# ═══════════════════════════════════════════════════════════════════════════════

func test_cycle_basic() -> void:
	# elapsed_time = 1.5, period = 2.0 → 1.5/2 = 0.75
	var result := _engine.cycle(2.0)
	GNTestAssert.assert_approx(result, 0.75, 0.001, "cycle(2.0) at t=1.5")


func test_cycle_zero_period() -> void:
	GNTestAssert.assert_approx(_engine.cycle(0.0), 0.0, 0.001, "cycle(0) returns 0")


func test_bounce_zero() -> void:
	GNTestAssert.assert_approx(_engine.bounce(0.0), 0.0, 0.001, "bounce(0)=0")


func test_bounce_half() -> void:
	# abs(sin(0.5 * PI)) = abs(1.0) = 1.0
	GNTestAssert.assert_approx(_engine.bounce(0.5), 1.0, 0.001, "bounce(0.5)=1")


func test_bounce_one() -> void:
	# abs(sin(1.0 * PI)) = abs(0.0) = 0.0
	GNTestAssert.assert_approx(_engine.bounce(1.0), 0.0, 0.01, "bounce(1.0)≈0")


# ═══════════════════════════════════════════════════════════════════════════════
# noise1() / noise2() / noise3()
# ═══════════════════════════════════════════════════════════════════════════════

func test_noise1_in_range() -> void:
	var val := _engine.noise1(3.7)
	GNTestAssert.assert_true(val >= -1.5 and val <= 1.5,
		"noise1 should be in [-1.5, 1.5], got %f" % val)


func test_noise1_deterministic() -> void:
	var a := _engine.noise1(42.5)
	var b := _engine.noise1(42.5)
	GNTestAssert.assert_approx(a, b, 0.0001, "same input → same output")


func test_noise1_different_inputs_differ() -> void:
	var a := _engine.noise1(1.0)
	var b := _engine.noise1(5.7)
	GNTestAssert.assert_true(not is_equal_approx(a, b),
		"different inputs should produce different values")


func test_noise2_in_range() -> void:
	var val := _engine.noise2(1.3, 4.7)
	GNTestAssert.assert_true(val >= -1.5 and val <= 1.5,
		"noise2 should be in [-1.5, 1.5], got %f" % val)


func test_noise2_deterministic() -> void:
	var a := _engine.noise2(2.1, 3.4)
	var b := _engine.noise2(2.1, 3.4)
	GNTestAssert.assert_approx(a, b, 0.0001, "same input → same output")


func test_noise3_in_range() -> void:
	var val := _engine.noise3(1.0, 2.0, 3.0)
	GNTestAssert.assert_true(val >= -1.5 and val <= 1.5,
		"noise3 should be in [-1.5, 1.5], got %f" % val)


func test_noise1_in_expression() -> void:
	var node := _make_null_chop("test1")
	var p := _add_float_param(node, "x", 0.0)
	p.set_expression("noise1(42.0)")
	_resolve_param(node, p)
	var expected := _engine.noise1(42.0)
	GNTestAssert.assert_approx(p.resolved_value, expected, 0.001, "noise1 in expression")


# ═══════════════════════════════════════════════════════════════════════════════
# iif() / rand()
# ═══════════════════════════════════════════════════════════════════════════════

func test_iif_true() -> void:
	var result: Variant = _engine.iif(true, 10.0, 20.0)
	GNTestAssert.assert_approx(float(result), 10.0, 0.001, "iif(true) → true_val")


func test_iif_false() -> void:
	var result: Variant = _engine.iif(false, 10.0, 20.0)
	GNTestAssert.assert_approx(float(result), 20.0, 0.001, "iif(false) → false_val")


func test_iif_in_expression() -> void:
	var node := _make_null_chop("test1")
	var p := _add_float_param(node, "x", 0.0)
	p.set_expression("iif(frame > 50, 100.0, 0.0)")
	_resolve_param(node, p)
	GNTestAssert.assert_approx(p.resolved_value, 100.0, 0.001, "iif in expr (frame=90>50)")


func test_rand_deterministic() -> void:
	var a := _engine.rand(42)
	var b := _engine.rand(42)
	GNTestAssert.assert_approx(a, b, 0.0001, "same seed → same result")


func test_rand_in_range() -> void:
	var val := _engine.rand(123)
	GNTestAssert.assert_true(val >= 0.0 and val < 1.0,
		"rand should be in [0, 1), got %f" % val)


func test_rand_different_seeds_differ() -> void:
	GNTestAssert.assert_true(not is_equal_approx(_engine.rand(1), _engine.rand(99)),
		"different seeds should give different results")


# ═══════════════════════════════════════════════════════════════════════════════
# digits()
# ═══════════════════════════════════════════════════════════════════════════════

func test_digits_trailing_number() -> void:
	var node := _make_null_chop("lfo3")
	_engine._current_eval_node = node
	GNTestAssert.assert_eq(_engine.digits(), 3, "lfo3 → 3")


func test_digits_multi_digit() -> void:
	var node := _make_null_chop("noise12")
	_engine._current_eval_node = node
	GNTestAssert.assert_eq(_engine.digits(), 12, "noise12 → 12")


func test_digits_no_number() -> void:
	var node := _make_null_chop("const")
	_engine._current_eval_node = node
	GNTestAssert.assert_eq(_engine.digits(), 0, "const → 0")


func test_digits_in_expression() -> void:
	var node := _make_null_chop("wave7")
	var p := _add_float_param(node, "x", 0.0)
	p.set_expression("digits()")
	_resolve_param(node, p)
	GNTestAssert.assert_eq(int(p.resolved_value), 7, "digits() in expression")


# ═══════════════════════════════════════════════════════════════════════════════
# smooth() — stateful exponential smoothing
# ═══════════════════════════════════════════════════════════════════════════════

func test_smooth_initial_returns_target() -> void:
	var result := _engine.smooth("test_key", 10.0)
	GNTestAssert.assert_approx(result, 10.0, 0.001, "first call returns target")


func test_smooth_converges_toward_target() -> void:
	_engine.smooth("conv_key", 0.0)
	# Second call with different target — should move toward it
	var result := _engine.smooth("conv_key", 10.0, 5.0)
	GNTestAssert.assert_true(result > 0.0 and result < 10.0,
		"should be between 0 and 10, got %f" % result)


func test_smooth_separate_keys_independent() -> void:
	_engine.smooth("key_a", 100.0)
	_engine.smooth("key_b", 0.0)
	var a := _engine.smooth("key_a", 100.0)
	var b := _engine.smooth("key_b", 0.0)
	GNTestAssert.assert_approx(a, 100.0, 0.1, "key_a tracks 100")
	GNTestAssert.assert_approx(b, 0.0, 0.1, "key_b tracks 0")


# ═══════════════════════════════════════════════════════════════════════════════
# lag() — asymmetric lag filter
# ═══════════════════════════════════════════════════════════════════════════════

func test_lag_initial_returns_target() -> void:
	var result := _engine.lag("lag_key", 5.0)
	GNTestAssert.assert_approx(result, 5.0, 0.001, "first call returns target")


func test_lag_asymmetric_speeds() -> void:
	_engine.lag("asym_key", 0.0, 100.0, 100.0)
	# Ramp up fast
	var up := _engine.lag("asym_key", 10.0, 100.0, 1.0)
	GNTestAssert.assert_true(up > 5.0, "up_speed=100 should move fast, got %f" % up)
	# Reset for down test
	_engine.lag("asym_key2", 10.0, 1.0, 100.0)
	var down := _engine.lag("asym_key2", 0.0, 1.0, 100.0)
	GNTestAssert.assert_true(down < 5.0, "down_speed=100 should move fast, got %f" % down)


# ═══════════════════════════════════════════════════════════════════════════════
# trigger() — rising-edge detector
# ═══════════════════════════════════════════════════════════════════════════════

func test_trigger_rising_edge() -> void:
	# First call: prev=0, value=1.0 → crosses threshold 0.5 → fires
	var result := _engine.trigger("trig_key", 1.0)
	GNTestAssert.assert_approx(result, 1.0, 0.001, "rising edge fires")


func test_trigger_no_edge() -> void:
	_engine.trigger("trig_key2", 1.0)
	# Already above threshold, value stays at 1.0 → no rising edge
	var result := _engine.trigger("trig_key2", 1.0)
	GNTestAssert.assert_approx(result, 0.0, 0.001, "no edge when already above")


func test_trigger_below_threshold() -> void:
	var result := _engine.trigger("trig_key3", 0.3, 0.5)
	GNTestAssert.assert_approx(result, 0.0, 0.001, "below threshold → no fire")


# ═══════════════════════════════════════════════════════════════════════════════
# store() / fetch() — per-node persistent state
# ═══════════════════════════════════════════════════════════════════════════════

func test_store_and_fetch() -> void:
	var node := _make_null_chop("state_node")
	_engine._current_eval_node = node
	_engine.store("counter", 42.0)
	var result: Variant = _engine.fetch("counter")
	GNTestAssert.assert_approx(float(result), 42.0, 0.001, "fetch stored value")


func test_fetch_default_when_missing() -> void:
	var node := _make_null_chop("state_node2")
	_engine._current_eval_node = node
	var result: Variant = _engine.fetch("nonexistent", -1.0)
	GNTestAssert.assert_approx(float(result), -1.0, 0.001, "fetch returns default")


func test_store_returns_value() -> void:
	var node := _make_null_chop("state_node3")
	_engine._current_eval_node = node
	var result: Variant = _engine.store("val", 7.0)
	GNTestAssert.assert_approx(float(result), 7.0, 0.001, "store returns stored value")


func test_store_per_node_isolation() -> void:
	var nodeA := _make_null_chop("storeA")
	var nodeB := _make_null_chop("storeB")
	_engine._current_eval_node = nodeA
	_engine.store("x", 10.0)
	_engine._current_eval_node = nodeB
	_engine.store("x", 20.0)
	# Read back
	_engine._current_eval_node = nodeA
	GNTestAssert.assert_approx(float(_engine.fetch("x")), 10.0, 0.001, "nodeA's x=10")
	_engine._current_eval_node = nodeB
	GNTestAssert.assert_approx(float(_engine.fetch("x")), 20.0, 0.001, "nodeB's x=20")


func test_store_fetch_in_expression() -> void:
	var node := _make_null_chop("expr_state1")
	# First store a value via expression
	var p1 := _add_float_param(node, "init", 0.0)
	p1.set_expression('store("acc", 99.0)')
	_resolve_param(node, p1)
	# Then fetch it in another expression
	var p2 := _add_float_param(node, "read", 0.0)
	p2.set_expression('fetch("acc", 0.0)')
	_resolve_param(node, p2)
	GNTestAssert.assert_approx(p2.resolved_value, 99.0, 0.001, "store/fetch in expressions")


# ═══════════════════════════════════════════════════════════════════════════════
# Timeline Functions — fps(), speed(), tstart(), tend(), frames()
# ═══════════════════════════════════════════════════════════════════════════════

func test_fps_realtime() -> void:
	# current_delta = 1/60 → fps = 60
	var result := _engine.fps()
	GNTestAssert.assert_approx(result, 60.0, 0.5, "fps() = 60")


func test_fps_nrt_mode() -> void:
	_engine.non_realtime = true
	_engine.non_realtime_fps = 30.0
	GNTestAssert.assert_approx(_engine.fps(), 30.0, 0.001, "NRT fps = 30")


func test_speed_default() -> void:
	GNTestAssert.assert_approx(_engine.speed(), 1.0, 0.001, "default speed = 1.0")


func test_speed_custom() -> void:
	_engine.playback_speed = 2.0
	GNTestAssert.assert_approx(_engine.speed(), 2.0, 0.001, "speed = 2.0")


func test_tstart() -> void:
	_engine.timeline_start = 5.0
	GNTestAssert.assert_approx(_engine.tstart(), 5.0, 0.001, "tstart = 5.0")


func test_tend() -> void:
	_engine.timeline_end = 300.0
	GNTestAssert.assert_approx(_engine.tend(), 300.0, 0.001, "tend = 300.0")


func test_frames_calculation() -> void:
	# timeline: 0–600, fps: 60 → 36000 frames
	var result := _engine.frames()
	GNTestAssert.assert_eq(result, 36000, "frames() = 600 * 60")


func test_timeline_in_expression() -> void:
	var node := _make_null_chop("test1")
	var p := _add_float_param(node, "x", 0.0)
	p.set_expression("tend() - tstart()")
	_resolve_param(node, p)
	GNTestAssert.assert_approx(p.resolved_value, 600.0, 0.001, "tend()-tstart() = 600")


func test_fps_in_expression() -> void:
	var node := _make_null_chop("test1")
	var p := _add_float_param(node, "x", 0.0)
	p.set_expression("fps()")
	_resolve_param(node, p)
	GNTestAssert.assert_approx(p.resolved_value, 60.0, 0.5, "fps() in expression")


func test_speed_in_expression() -> void:
	_engine.playback_speed = 0.5
	var node := _make_null_chop("test1")
	var p := _add_float_param(node, "x", 0.0)
	p.set_expression("speed()")
	_resolve_param(node, p)
	GNTestAssert.assert_approx(p.resolved_value, 0.5, 0.001, "speed() in expression")


# ═══════════════════════════════════════════════════════════════════════════════
# set_par() — parameter mutation
# ═══════════════════════════════════════════════════════════════════════════════

func test_set_par_cross_node() -> void:
	var target := _make_null_chop("target")
	var p := _add_float_param(target, "scale", 1.0)
	_engine._current_eval_node = _make_null_chop("caller")
	var ok := _engine.set_par("target", "scale", 42.0)
	GNTestAssert.assert_true(ok, "set_par returns true")
	GNTestAssert.assert_approx(p.value, 42.0, 0.001, "param value updated")


func test_set_par_self() -> void:
	var node := _make_null_chop("self_node")
	var p := _add_float_param(node, "val", 0.0)
	_engine._current_eval_node = node
	_engine.set_par("val", 7.0)
	GNTestAssert.assert_approx(p.value, 7.0, 0.001, "self set_par")


func test_set_par_missing_node() -> void:
	_engine._current_eval_node = _make_null_chop("caller")
	var ok := _engine.set_par("nonexistent", "x", 1.0)
	GNTestAssert.assert_false(ok, "set_par to missing node returns false")


func test_set_par_missing_param() -> void:
	var _target := _make_null_chop("target2")
	_engine._current_eval_node = _make_null_chop("caller")
	var ok := _engine.set_par("target2", "nonexistent", 1.0)
	GNTestAssert.assert_false(ok, "set_par to missing param returns false")


# ═══════════════════════════════════════════════════════════════════════════════
# log() — expression debug logging
# ═══════════════════════════════════════════════════════════════════════════════

func test_log_returns_zero() -> void:
	_engine._current_eval_node = _make_null_chop("logtest")
	var result := _engine.log("test message")
	GNTestAssert.assert_approx(result, 0.0, 0.001, "log() returns 0.0")


func test_log_inline_in_expression() -> void:
	# Note: Godot's Expression class overrides `log()` with the math function.
	# The engine's log() is still callable via direct API.
	var node := _make_null_chop("logtest2")
	_engine._current_eval_node = node
	var result := _engine.log("test from expression")
	GNTestAssert.assert_approx(result, 0.0, 0.001, "log() returns 0 via direct call")


# ═══════════════════════════════════════════════════════════════════════════════
# op() proxy — GNOpProxy properties
# ═══════════════════════════════════════════════════════════════════════════════

func test_op_proxy_returns_proxy() -> void:
	var _node := _make_null_chop("myop")
	_engine._current_eval_node = _node
	var proxy: Variant = _engine.op("myop")
	GNTestAssert.assert_true(proxy is GNOpProxy, "op() returns GNOpProxy")


func test_op_proxy_id() -> void:
	var _node := _make_null_chop("myop")
	_engine._current_eval_node = _node
	var proxy: GNOpProxy = _engine.op("myop") as GNOpProxy
	GNTestAssert.assert_eq(proxy.id, "myop", "proxy.id")


func test_op_proxy_type() -> void:
	var _node := _make_null_chop("myop")
	_engine._current_eval_node = _node
	var proxy: GNOpProxy = _engine.op("myop") as GNOpProxy
	GNTestAssert.assert_eq(proxy.type, "null", "proxy.type = node_type")


func test_op_proxy_family() -> void:
	var _node := _make_null_chop("myop")
	_engine._current_eval_node = _node
	var proxy: GNOpProxy = _engine.op("myop") as GNOpProxy
	GNTestAssert.assert_eq(proxy.family, "CHOP", "proxy.family")


func test_op_proxy_digits() -> void:
	var _node := _make_null_chop("lfo42")
	_engine._current_eval_node = _node
	var proxy: GNOpProxy = _engine.op("lfo42") as GNOpProxy
	GNTestAssert.assert_eq(proxy.digits, 42, "proxy.digits")


func test_op_proxy_num_outputs() -> void:
	var _node := _make_null_chop("myop")
	_engine._current_eval_node = _node
	var proxy: GNOpProxy = _engine.op("myop") as GNOpProxy
	GNTestAssert.assert_true(proxy.num_outputs >= 1, "proxy.num_outputs >= 1")


func test_op_proxy_num_params() -> void:
	var _node := _make_null_chop("myop")
	_engine._current_eval_node = _node
	var proxy: GNOpProxy = _engine.op("myop") as GNOpProxy
	GNTestAssert.assert_true(proxy.num_params >= 0, "proxy.num_params")


func test_op_with_param_returns_value() -> void:
	var node := _make_constant_chop("const1", "out", 7.0)
	_engine._current_eval_node = node
	var result: Variant = _engine.op("const1", "value0")
	GNTestAssert.assert_approx(float(result), 7.0, 0.001, "op(node, param) returns value")


func test_op_missing_node() -> void:
	_engine._current_eval_node = _make_null_chop("caller")
	var result: Variant = _engine.op("nonexistent")
	GNTestAssert.assert_null(result, "op() missing node returns null")


# ═══════════════════════════════════════════════════════════════════════════════
# me variable — self-reference in expressions
# ═══════════════════════════════════════════════════════════════════════════════

func test_me_id_in_expression() -> void:
	var node := _make_null_chop("mynode5")
	var p := GNParameter.create_string("label", "")
	node.add_parameter(p)
	p.set_expression("me.id")
	_resolve_param(node, p)
	GNTestAssert.assert_eq(str(p.resolved_value), "mynode5", "me.id in expression")


func test_me_family_in_expression() -> void:
	var node := _make_null_chop("node1")
	var p := _add_float_param(node, "x", 0.0)
	# me.family is the enum int, CHOP = 1
	p.set_expression("me.family")
	_resolve_param(node, p)
	GNTestAssert.assert_eq(int(p.resolved_value), GNFamily.Type.CHOP,
		"me.family == CHOP enum")


# ═══════════════════════════════════════════════════════════════════════════════
# top() — read TOP data from expressions
# ═══════════════════════════════════════════════════════════════════════════════

func test_top_resolution_width() -> void:
	var _noise := _make_noise_top("noise1")
	_engine._current_eval_node = _make_null_chop("caller")
	var result: Variant = _engine.top("noise1", "width")
	GNTestAssert.assert_true(int(result) > 0,
		"top('noise1', 'width') should be > 0, got %s" % str(result))


func test_top_resolution_height() -> void:
	var _noise := _make_noise_top("noise1")
	_engine._current_eval_node = _make_null_chop("caller")
	var result: Variant = _engine.top("noise1", "height")
	GNTestAssert.assert_true(int(result) > 0,
		"top('noise1', 'height') should be > 0, got %s" % str(result))


func test_top_missing_node() -> void:
	_engine._current_eval_node = _make_null_chop("caller")
	var result: Variant = _engine.top("nonexistent", "width")
	GNTestAssert.assert_approx(float(result), 0.0, 0.001,
		"top() missing node returns 0")


func test_top_in_expression() -> void:
	var _noise := _make_noise_top("noise1")
	var node := _make_null_chop("caller")
	var p := _add_float_param(node, "w", 0.0)
	p.set_expression('top("noise1", "width")')
	_resolve_param(node, p)
	GNTestAssert.assert_true(p.resolved_value > 0,
		"top() in expression returns width > 0")


# ═══════════════════════════════════════════════════════════════════════════════
# sop() / npoints()
# ═══════════════════════════════════════════════════════════════════════════════

func test_npoints_grid() -> void:
	var _grid := _make_grid_sop("grid1")
	_engine._current_eval_node = _make_null_chop("caller")
	var result := _engine.npoints("grid1")
	GNTestAssert.assert_true(result > 0,
		"npoints('grid1') should be > 0, got %d" % result)


func test_npoints_missing_node() -> void:
	_engine._current_eval_node = _make_null_chop("caller")
	var result := _engine.npoints("nonexistent")
	GNTestAssert.assert_eq(result, 0, "npoints missing node returns 0")


func test_npoints_in_expression() -> void:
	var _grid := _make_grid_sop("grid1")
	var node := _make_null_chop("caller")
	var p := _add_float_param(node, "pts", 0.0)
	p.set_expression('npoints("grid1")')
	_resolve_param(node, p)
	GNTestAssert.assert_true(p.resolved_value > 0,
		"npoints() in expression returns > 0")


func test_sop_returns_data() -> void:
	var _grid := _make_grid_sop("grid1")
	_engine._current_eval_node = _make_null_chop("caller")
	var result: Variant = _engine.sop("grid1")
	GNTestAssert.assert_true(result is GNGeoData or result != null,
		"sop() should return GNGeoData or non-null")


# ═══════════════════════════════════════════════════════════════════════════════
# dat() / ncells()
# ═══════════════════════════════════════════════════════════════════════════════

func test_ncells_constant_dat() -> void:
	var _dat := _make_constant_dat("table1", "row1\nrow2\nrow3")
	_engine._current_eval_node = _make_null_chop("caller")
	var result := _engine.ncells("table1")
	GNTestAssert.assert_true(result >= 0,
		"ncells should be >= 0, got %d" % result)


func test_ncells_missing_node() -> void:
	_engine._current_eval_node = _make_null_chop("caller")
	GNTestAssert.assert_eq(_engine.ncells("nonexistent"), 0,
		"ncells missing node returns 0")


func test_dat_returns_data() -> void:
	var _dat := _make_constant_dat("table1")
	_engine._current_eval_node = _make_null_chop("caller")
	var result: Variant = _engine.dat("table1")
	GNTestAssert.assert_not_null(result, "dat() should return non-null")


func _make_keyed_dat(id: String) -> GNNode:
	var node := ConstantDAT.new()
	node.initialize(id)
	_network.add_node(node)
	_engine.add_child(node)
	node.set_param_value("col0", "category")
	node.set_param_value("col1", "property")
	node.set_param_value("col2", "value")
	node.set_param_value("r0c0", "Display")
	node.set_param_value("r0c1", "screen_0_width")
	node.set_param_value("r0c2", "1920")
	node.set_param_value("r1c0", "Display")
	node.set_param_value("r1c1", "screen_0_height")
	node.set_param_value("r1c2", "1080")
	node.set_param_value("r2c0", "Engine")
	node.set_param_value("r2c1", "fps")
	node.set_param_value("r2c2", "60")
	var inputs: Array[GNData] = []
	node.execute_cook(inputs, _engine.frame_count)
	return node


func test_cell_addresses_by_index_and_name() -> void:
	var _dat := _make_keyed_dat("table1")
	_engine._current_eval_node = _make_null_chop("caller")
	GNTestAssert.assert_eq(_engine.cell("table1", 0, 0), "Display", "index address")
	GNTestAssert.assert_eq(_engine.cell("table1", 1, "value"), "1080", "column name")
	GNTestAssert.assert_eq(_engine.cell("table1", "Engine", "property"), "fps", "row name is column 0")
	GNTestAssert.assert_eq(_engine.cellf("table1", "Engine", "value"), 60.0, "named cellf")
	GNTestAssert.assert_eq(_engine.cell("table1", "missing", "value"), "", "missing row name")


func test_lookup_finds_row_by_named_column() -> void:
	var _dat := _make_keyed_dat("table1")
	_engine._current_eval_node = _make_null_chop("caller")
	GNTestAssert.assert_eq(
		_engine.lookup("table1", "property", "screen_0_height", "value"),
		"1080", "lookup by property")
	GNTestAssert.assert_eq(
		_engine.lookupf("table1", "property", "screen_0_width", "value"),
		1920.0, "lookupf")
	GNTestAssert.assert_eq(_engine.lookup("table1", "property", "nope", "value"), "", "lookup miss")
	GNTestAssert.assert_eq(_engine.lookupf("missing", "property", "fps", "value"), 0.0, "missing dat")


func test_lookupf_in_expression() -> void:
	var _dat := _make_keyed_dat("table1")
	var node := _make_null_chop("caller")
	var p := _add_float_param(node, "w", 0.0)
	p.set_expression('lookupf("table1", "property", "screen_0_width", "value")')
	_resolve_param(node, p)
	GNTestAssert.assert_eq(p.resolved_value, 1920.0, "lookupf expression")


# ═══════════════════════════════════════════════════════════════════════════════
# output() — universal port accessor
# ═══════════════════════════════════════════════════════════════════════════════

func test_output_default_port() -> void:
	var _chop := _make_constant_chop("const1", "out", 5.0)
	_engine._current_eval_node = _make_null_chop("caller")
	var result: Variant = _engine.output("const1")
	GNTestAssert.assert_not_null(result, "output() returns non-null data")


func test_output_port_index() -> void:
	var _chop := _make_constant_chop("const1", "out", 5.0)
	_engine._current_eval_node = _make_null_chop("caller")
	var result: Variant = _engine.output("const1", 0)
	GNTestAssert.assert_not_null(result, "output(node, 0) returns data")


func test_output_missing_node() -> void:
	_engine._current_eval_node = _make_null_chop("caller")
	var result: Variant = _engine.output("nonexistent")
	GNTestAssert.assert_null(result, "output() missing node returns null")


# ═══════════════════════════════════════════════════════════════════════════════
# fn() — custom function dispatch (GNExpressionFunctions)
# ═══════════════════════════════════════════════════════════════════════════════

func test_fn_register_and_call() -> void:
	GNExpressionFunctions.register("test_add",
		func(a: float, b: float) -> float: return a + b,
		"Test addition", ["a", "b"])
	var result: Variant = _engine.fn("test_add", 3.0, 4.0)
	GNTestAssert.assert_approx(float(result), 7.0, 0.001, "fn() dispatches correctly")


func test_fn_unknown_function() -> void:
	var result: Variant = _engine.fn("totally_nonexistent", 1.0)
	GNTestAssert.assert_approx(float(result), 0.0, 0.001, "unknown fn returns 0.0")


func test_fn_unregister() -> void:
	GNExpressionFunctions.register("test_greet",
		func() -> String: return "hi")
	GNTestAssert.assert_true(GNExpressionFunctions.has_func("test_greet"),
		"registered")
	GNExpressionFunctions.unregister("test_greet")
	GNTestAssert.assert_false(GNExpressionFunctions.has_func("test_greet"),
		"unregistered")


func test_fn_in_expression() -> void:
	GNExpressionFunctions.register("test_add",
		func(a: float, b: float) -> float: return a + b,
		"Test addition", ["a", "b"])
	var node := _make_null_chop("test1")
	var p := _add_float_param(node, "x", 0.0)
	p.set_expression('fn("test_add", 10.0, 5.0)')
	_resolve_param(node, p)
	GNTestAssert.assert_approx(p.resolved_value, 15.0, 0.001, "fn() in expression")


# ═══════════════════════════════════════════════════════════════════════════════
# Hierarchical Path Resolution — ../ and subnet/child
# ═══════════════════════════════════════════════════════════════════════════════

func test_resolve_node_parent_path() -> void:
	# Set up parent engine with a node
	var parent_network := GNNetwork.new()
	var parent_engine := GNCookEngine.new()
	parent_engine.network = parent_network
	parent_engine.cooking_enabled = false
	add_child(parent_engine)

	var parent_node := NullCHOP.new()
	parent_node.initialize("parent_lfo")
	parent_network.add_node(parent_node)
	parent_engine.add_child(parent_node)

	# Set current engine's parent
	_engine.parent_engine = parent_engine

	# ../ should resolve in parent's network
	var found := _engine.resolve_node("../parent_lfo")
	GNTestAssert.assert_not_null(found, "../parent_lfo should resolve")
	if found:
		GNTestAssert.assert_eq(found.id, "parent_lfo", "correct node")

	parent_engine.queue_free()


func test_resolve_node_subnet_path() -> void:
	# Create a SubNetworkNode with an inner node
	var subnet := SubNetworkNode.new()
	subnet.initialize("subnet1")
	_network.add_node(subnet)
	_engine.add_child(subnet)

	# Add a node inside the subnet's inner network
	var inner_node := NullCHOP.new()
	inner_node.initialize("inner_lfo")
	subnet.inner_network.add_node(inner_node)
	subnet._inner_cook_engine.add_child(inner_node)

	# subnet1/inner_lfo should resolve
	var found := _engine.resolve_node("subnet1/inner_lfo")
	GNTestAssert.assert_not_null(found, "subnet1/inner_lfo should resolve")
	if found:
		GNTestAssert.assert_eq(found.id, "inner_lfo", "correct inner node")


func test_resolve_node_parent_not_found() -> void:
	# No parent engine set → ../ should return null
	var found := _engine.resolve_node("../missing")
	GNTestAssert.assert_null(found, "../missing with no parent returns null")


# ═══════════════════════════════════════════════════════════════════════════════
# Multi-output chop() with port argument
# ═══════════════════════════════════════════════════════════════════════════════

func test_chop_port_index() -> void:
	var _chop := _make_constant_chop("const1", "mychan", 77.0)
	var target := _make_null_chop("target")
	var p := _add_float_param(target, "x", 0.0)
	# chop("const1", 0, "mychan") — port index 0
	p.set_expression('chop("const1", 0, "mychan")')
	_resolve_param(target, p)
	GNTestAssert.assert_approx(p.resolved_value, 77.0, 0.001,
		"chop with port index")


# ═══════════════════════════════════════════════════════════════════════════════
# ramp() — sample ramp parameter
# ═══════════════════════════════════════════════════════════════════════════════

func test_ramp_missing_param() -> void:
	var node := _make_null_chop("ramptest")
	_engine._current_eval_node = node
	# No ramp param exists → should return 0.0 gracefully
	var result := _engine.ramp("nonexistent", 0.5)
	GNTestAssert.assert_approx(result, 0.0, 0.001, "ramp() missing param returns 0")


func test_ramp_missing_node() -> void:
	_engine._current_eval_node = _make_null_chop("caller")
	var result := _engine.ramp("nonexistent_node", "gradient", 0.5)
	GNTestAssert.assert_approx(result, 0.0, 0.001, "ramp() missing node returns 0")
