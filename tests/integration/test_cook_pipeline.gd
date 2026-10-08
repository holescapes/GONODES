extends Node
## Integration tests for cook engine — graph operations, cook order, input hash
## guard, active set, bypass, compute guard, dirty propagation.
##
## Complements test_network.gd (pure graph model) and test_cook_engine.gd
## (expression evaluation) by testing the full cook_frame() pipeline.

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
	_engine.frame_count = 0
	_engine.current_delta = 1.0 / 60.0
	add_child(_engine)


func after_each() -> void:
	if is_instance_valid(_engine):
		_engine.queue_free()
	_engine = null
	_network = null


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _make(script_class: GDScript, id: String) -> GNNode:
	var node: GNNode = script_class.new()
	node.initialize(id)
	_network.add_node(node)
	return node


func _cook() -> void:
	_engine.cook_frame(_engine.current_delta)


func _output(node: GNNode) -> GNChannelData:
	var _ret0 := node.cached_output as GNChannelData
	return _ret0


func _make_constant(id: String, ch_name: String = "out", value: float = 1.0) -> GNNode:
	var c := _make(ConstantCHOP, id)
	c.set_param_value("name0", ch_name)
	c.set_param_value("value0", value)
	return c


func _make_null(id: String) -> GNNode:
	return _make(NullCHOP, id)


func _make_math(id: String, op: int = 0, operand: float = 0.0) -> GNNode:
	var m := _make(MathCHOP, id)
	m.set_param_value("operation", op)
	m.set_param_value("operand", operand)
	return m


func _sink(ids: Array) -> void:
	var typed: Array[String] = []
	for id in ids:
		typed.append(str(id))
	_engine.set_active_sinks(typed)


# ═══════════════════════════════════════════════════════════════════════════════
# Cook Order — nodes cook in topological order
# ═══════════════════════════════════════════════════════════════════════════════

func test_cook_order_linear_chain() -> void:
	## A → B → C: all produce output after one cook frame.
	var a := _make_constant("a", "ch", 5.0)
	var b := _make_null("b")
	var c := _make_null("c")
	_network.connect_nodes("a", 0, "b", 0)
	_network.connect_nodes("b", 0, "c", 0)
	_sink(["c"])
	_cook()
	GNTestAssert.assert_not_null(_output(c), "end of chain has output")
	GNTestAssert.assert_approx(_output(c).get_value("ch"), 5.0, 0.001, "value propagated")


func test_cook_order_diamond() -> void:
	## A → B, A → C, B → D, C → D: D sees correct input.
	var a := _make_constant("a", "v", 10.0)
	var b := _make_math("b", 2, 2.0)  # Multiply by 2 → 20
	var c := _make_math("c", 2, 3.0)  # Multiply by 3 → 30
	# D merges — MergeCHOP takes multiple inputs
	var d := _make(MergeCHOP, "d")
	_network.connect_nodes("a", 0, "b", 0)
	_network.connect_nodes("a", 0, "c", 0)
	_network.connect_nodes("b", 0, "d", 0)
	_network.connect_nodes("c", 0, "d", 1)
	_sink(["d"])
	_cook()
	var out := _output(d)
	GNTestAssert.assert_not_null(out, "merge output exists")
	# Merge combines channels from both inputs
	GNTestAssert.assert_gt(out.get_channel_count(), 0, "merge has channels")


func test_cook_order_disconnected_island() -> void:
	## Disconnected nodes cook when designated as sinks.
	var a := _make_constant("a", "x", 7.0)
	var b := _make_constant("b", "y", 3.0)
	_sink(["a", "b"])
	_cook()
	GNTestAssert.assert_not_null(_output(a), "island A cooked")
	GNTestAssert.assert_not_null(_output(b), "island B cooked")
	GNTestAssert.assert_approx(_output(a).get_value("x"), 7.0, 0.001)
	GNTestAssert.assert_approx(_output(b).get_value("y"), 3.0, 0.001)


# ═══════════════════════════════════════════════════════════════════════════════
# Active Set — only sink-reachable nodes cook
# ═══════════════════════════════════════════════════════════════════════════════

func test_active_set_with_sink() -> void:
	## When a sink exists, only its upstream chain is active.
	var a := _make_constant("a", "ch", 1.0)
	var b := _make_null("b")
	var orphan := _make_constant("orphan", "x", 99.0)
	_network.connect_nodes("a", 0, "b", 0)

	# Designate b as the active sink
	_engine.set_active_sinks(["b"] as Array[String])

	_cook()
	# a and b should cook (b is sink, a feeds b)
	GNTestAssert.assert_true(a.is_active, "a is active (feeds sink)")
	GNTestAssert.assert_true(b.is_active, "b is active (sink)")
	# orphan has no path to any sink
	GNTestAssert.assert_false(orphan.is_active, "orphan is inactive")


func test_active_set_expression_ref_activates_node() -> void:
	## A node referenced by a chop() expression should be active even without
	## a wire connection, because the reading node depends on it implicitly.
	var lfo := _make_constant("lfo1", "out", 0.5)
	var reader := _make_null("reader")
	# reader has an expression referencing lfo1
	var p := GNParameter.create_float("x", 0.0)
	reader.add_parameter(p)
	p.set_expression('chop("lfo1", "out", 0)')

	# Only reader is a sink — lfo1 has no wire to reader
	_engine.set_active_sinks(["reader"] as Array[String])
	_cook()

	GNTestAssert.assert_true(lfo.is_active, "lfo1 activated by expression ref")
	GNTestAssert.assert_true(reader.is_active, "reader is active (sink)")


func test_active_set_script_code_body_ref_activates_node() -> void:
	## chop()/dat() inside GDScriptSCRIPT cook() body (STRING "code" param)
	## must pull referenced nodes into the active set — same as expressions.
	## (Value correctness of chop() helpers is covered by test_script_chop.)
	var lfo := _make_constant("lfo1", "out", 0.5)
	var script := _make(GDScriptSCRIPT, "script1")
	# Demand scan matches static chop("id") literals in the STRING body
	# (including comments). Keep cook() a no-op so this suite does not depend
	# on SCRIPT data-factory / extension registry setup.
	script.set_param_value("code", """# @output chop Result
# wireless demand: chop("lfo1", "out", 0)

func cook():
	pass
""".strip_edges())
	script.set_param_value("time_dependent", false)

	_engine.set_active_sinks(["script1"] as Array[String])
	_cook()

	GNTestAssert.assert_true(script.is_active, "script is active (sink)")
	GNTestAssert.assert_true(lfo.is_active, "lfo1 activated by script code-body ref")


func test_no_sinks_empty_active_set() -> void:
	## When no sinks exist, no nodes are active — nothing cooks.
	var a := _make_constant("a", "x", 1.0)
	var b := _make_constant("b", "y", 2.0)
	# No sinks set, no is_sink nodes
	_cook()
	GNTestAssert.assert_false(a.is_active, "a inactive without sinks")
	GNTestAssert.assert_false(b.is_active, "b inactive without sinks")


# ═══════════════════════════════════════════════════════════════════════════════
# Input Hash Guard (Tier 2) — skip cook when inputs unchanged
# ═══════════════════════════════════════════════════════════════════════════════

func test_hash_guard_skips_unchanged() -> void:
	## A dirty node whose hash is unchanged skips cook via the hash guard.
	var a := _make_constant("a", "ch", 5.0)
	var b := _make_null("b")
	_network.connect_nodes("a", 0, "b", 0)
	_sink(["b"])

	_cook()  # Frame 0: first cook — both cook
	GNTestAssert.assert_not_null(_output(b), "b cooked on frame 0")
	var first_output := _output(b)

	# Frame 1: force b dirty without changing params or upstream output
	b.mark_dirty()
	_engine.elapsed_time += _engine.current_delta
	_cook()

	GNTestAssert.assert_false(b.dirty, "hash skip clears dirty")
	GNTestAssert.assert_eq(_output(b), first_output, "same output object (hash skip)")


func test_hash_guard_recooks_on_param_change() -> void:
	## Changing a parameter should cause downstream to re-cook.
	var a := _make_constant("a", "ch", 5.0)
	var b := _make_null("b")
	_network.connect_nodes("a", 0, "b", 0)
	_sink(["b"])

	_cook()
	GNTestAssert.assert_approx(_output(b).get_value("ch"), 5.0, 0.001)

	# Change the constant value
	a.set_param_value("value0", 99.0)
	a.mark_dirty()

	_engine.elapsed_time += _engine.current_delta
	_cook()
	GNTestAssert.assert_approx(_output(b).get_value("ch"), 99.0, 0.001, "recook after param change")


func test_hash_guard_time_dependent_always_cooks() -> void:
	## Time-dependent nodes should always cook (hash includes elapsed_time).
	var lfo := _make(LFO_CHOP, "lfo1")
	_sink(["lfo1"])
	_cook()
	var val1 := _output(lfo).get_value("out") if _output(lfo) else 0.0

	_engine.elapsed_time += 0.5
	_engine.current_delta = 0.5
	_cook()
	var val2 := _output(lfo).get_value("out") if _output(lfo) else 0.0

	# LFO output changes with time — values should differ
	GNTestAssert.assert_ne(val1, val2, "time-dependent LFO produces different output each frame")


# ═══════════════════════════════════════════════════════════════════════════════
# Dirty Propagation Through Cook Frame
# ═══════════════════════════════════════════════════════════════════════════════

func test_dirty_propagation_downstream_recooks() -> void:
	## When upstream re-cooks, downstream should also re-cook.
	var a := _make_constant("a", "ch", 1.0)
	var b := _make_math("b", 0, 10.0)  # Add 10
	var c := _make_null("c")
	_network.connect_nodes("a", 0, "b", 0)
	_network.connect_nodes("b", 0, "c", 0)
	_sink(["c"])

	_cook()
	GNTestAssert.assert_approx(_output(c).get_value("ch"), 11.0, 0.001, "1+10=11")

	# Change upstream
	a.set_param_value("value0", 5.0)
	a.mark_dirty()

	_engine.elapsed_time += _engine.current_delta
	_cook()
	GNTestAssert.assert_approx(_output(c).get_value("ch"), 15.0, 0.001, "5+10=15 after change")


func test_dirty_sibling_branch_not_affected() -> void:
	## Changing one branch shouldn't re-cook sibling branches.
	#     A → B
	#     C → D
	# Changing A should dirty B but not D.
	var a := _make_constant("a", "x", 1.0)
	var b := _make_null("b")
	var c := _make_constant("c", "y", 2.0)
	var d := _make_null("d")
	_network.connect_nodes("a", 0, "b", 0)
	_network.connect_nodes("c", 0, "d", 0)
	_sink(["b", "d"])

	_cook()

	# Mark only A dirty
	a.set_param_value("value0", 99.0)
	a.mark_dirty()

	_engine.elapsed_time += _engine.current_delta
	_cook()

	GNTestAssert.assert_approx(_output(b).get_value("x"), 99.0, 0.001, "b updated")
	GNTestAssert.assert_approx(_output(d).get_value("y"), 2.0, 0.001, "d unchanged")


func test_incremental_dirty_only_direct_successors() -> void:
	## In a chain A → B → C, marking A dirty and cooking should dirty B,
	## and then if B actually re-cooks, C gets dirtied too (cascading).
	var a := _make_constant("a", "ch", 1.0)
	var b := _make_null("b")
	var c := _make_null("c")
	_network.connect_nodes("a", 0, "b", 0)
	_network.connect_nodes("b", 0, "c", 0)
	_sink(["c"])

	_cook()
	a.set_param_value("value0", 50.0)
	a.mark_dirty()

	_engine.elapsed_time += _engine.current_delta
	_cook()

	GNTestAssert.assert_approx(_output(c).get_value("ch"), 50.0, 0.001, "cascade through chain")


# ═══════════════════════════════════════════════════════════════════════════════
# Bypass Mode
# ═══════════════════════════════════════════════════════════════════════════════

func test_bypass_passes_input_through() -> void:
	## A bypassed node should pass its first non-null input through.
	var a := _make_constant("a", "ch", 42.0)
	var b := _make_math("b", 2, 10.0)  # Multiply by 10 — but bypassed
	var c := _make_null("c")
	b.bypass = true
	_network.connect_nodes("a", 0, "b", 0)
	_network.connect_nodes("b", 0, "c", 0)
	_sink(["c"])

	_cook()

	# b is bypassed — c should see a's output (42), not b's (420)
	GNTestAssert.assert_approx(_output(c).get_value("ch"), 42.0, 0.001,
		"bypassed node passes input through")


func test_bypass_after_cook_replaces_cached_output() -> void:
	## Bypass toggled after a real cook must not keep that cook's result.
	var a := _make_constant("a", "ch", 42.0)
	var b := _make_math("b", 2, 10.0)
	var c := _make_null("c")
	_network.connect_nodes("a", 0, "b", 0)
	_network.connect_nodes("b", 0, "c", 0)
	_sink(["c"])

	_cook()
	GNTestAssert.assert_approx(_output(c).get_value("ch"), 420.0, 0.001, "math cooks before bypass")

	b.bypass = true
	b.mark_dirty()
	_cook()
	GNTestAssert.assert_approx(_output(c).get_value("ch"), 42.0, 0.001,
		"bypass after cook passes the input through")

	b.bypass = false
	b.mark_dirty()
	_cook()
	GNTestAssert.assert_approx(_output(c).get_value("ch"), 420.0, 0.001,
		"clearing bypass cooks again")


func test_bypass_cook_time_zero() -> void:
	## A bypassed node should report 0 cook time.
	var a := _make_constant("a", "ch", 1.0)
	var b := _make_null("b")
	b.bypass = true
	_network.connect_nodes("a", 0, "b", 0)
	_sink(["b"])

	_cook()
	GNTestAssert.assert_approx(b.cook_time_ms, 0.0, 0.001, "bypass cook time is zero")


# ═══════════════════════════════════════════════════════════════════════════════
# Compute Guard — skip nodes requiring compute on Compatibility renderer
# ═══════════════════════════════════════════════════════════════════════════════

func test_compute_guard_flag_default() -> void:
	## Regular nodes should not require compute by default.
	var a := _make_null("a")
	GNTestAssert.assert_false(a.requires_compute(), "NullCHOP doesn't require compute")


func test_supported_renderers_default_all() -> void:
	## Regular nodes support all three renderers by default.
	var a := _make_null("a")
	var renderers := a.supported_renderers()
	GNTestAssert.assert_true(renderers.has("forward_plus"), "default supports forward_plus")
	GNTestAssert.assert_true(renderers.has("mobile"), "default supports mobile")
	GNTestAssert.assert_true(renderers.has("gl_compatibility"), "default supports gl_compatibility")


func test_supported_platforms_default_all() -> void:
	## Regular nodes support all six platforms by default.
	var a := _make_null("a")
	var platforms := a.supported_platforms()
	GNTestAssert.assert_true(platforms.has("windows"), "default supports windows")
	GNTestAssert.assert_true(platforms.has("macos"), "default supports macos")
	GNTestAssert.assert_true(platforms.has("linux"), "default supports linux")
	GNTestAssert.assert_true(platforms.has("android"), "default supports android")
	GNTestAssert.assert_true(platforms.has("ios"), "default supports ios")
	GNTestAssert.assert_true(platforms.has("web"), "default supports web")


func test_ffmpeg_out_platform_restricted() -> void:
	## FFmpegOUT should be restricted to desktop platforms only.
	var op := _make(FFmpegOUT, "ffout")
	var platforms := op.supported_platforms()
	GNTestAssert.assert_true(platforms.has("windows"), "FFmpegOUT supports windows")
	GNTestAssert.assert_true(platforms.has("macos"), "FFmpegOUT supports macos")
	GNTestAssert.assert_true(platforms.has("linux"), "FFmpegOUT supports linux")
	GNTestAssert.assert_false(platforms.has("android"), "FFmpegOUT excludes android")
	GNTestAssert.assert_false(platforms.has("ios"), "FFmpegOUT excludes ios")
	GNTestAssert.assert_false(platforms.has("web"), "FFmpegOUT excludes web")


func test_window_out_supports_all_platforms() -> void:
	## WindowOUT should support all platforms (platform-adaptive, not restricted).
	var op := _make(WindowOUT, "win")
	var platforms := op.supported_platforms()
	GNTestAssert.assert_eq(platforms.size(), 6, "WindowOUT supports all 6 platforms")
	var renderers := op.supported_renderers()
	GNTestAssert.assert_eq(renderers.size(), 3, "WindowOUT supports all 3 renderers")


# ═══════════════════════════════════════════════════════════════════════════════
# Connection Topology Changes — cook after reconnect
# ═══════════════════════════════════════════════════════════════════════════════

func test_reconnect_updates_data_flow() -> void:
	## Changing a wire should cause the downstream node to see new upstream data.
	var a := _make_constant("a", "ch", 10.0)
	var b := _make_constant("b", "ch", 20.0)
	var c := _make_null("c")
	_network.connect_nodes("a", 0, "c", 0)
	_sink(["c"])

	_cook()
	GNTestAssert.assert_approx(_output(c).get_value("ch"), 10.0, 0.001, "initially from a")

	# Rewire: b → c (replaces a → c)
	_network.connect_nodes("b", 0, "c", 0)
	c.mark_dirty()

	_engine.elapsed_time += _engine.current_delta
	_cook()
	GNTestAssert.assert_approx(_output(c).get_value("ch"), 20.0, 0.001, "now from b after reconnect")


func test_disconnect_nulls_input() -> void:
	## Disconnecting a wire should cause the downstream node to receive null input.
	var a := _make_constant("a", "ch", 5.0)
	var b := _make_null("b")
	_network.connect_nodes("a", 0, "b", 0)
	_sink(["b"])

	_cook()
	GNTestAssert.assert_not_null(_output(b), "b has output initially")

	# Disconnect
	_network.disconnect_nodes("a", 0, "b", 0)
	b.mark_dirty()

	_engine.elapsed_time += _engine.current_delta
	_cook()

	# NullCHOP with no input returns null output
	GNTestAssert.assert_null(_output(b), "b output null after disconnect")


# ═══════════════════════════════════════════════════════════════════════════════
# Multi-Frame Stability
# ═══════════════════════════════════════════════════════════════════════════════

func test_multi_frame_stable_output() -> void:
	## Non-time-dependent network should produce same output across frames.
	var a := _make_constant("a", "ch", 7.0)
	var b := _make_math("b", 0, 3.0)  # Add 3 → 10
	_network.connect_nodes("a", 0, "b", 0)
	_sink(["b"])

	_cook()
	var v1 := _output(b).get_value("ch")

	_engine.elapsed_time += _engine.current_delta
	_cook()
	var v2 := _output(b).get_value("ch")

	_engine.elapsed_time += _engine.current_delta
	_cook()
	var v3 := _output(b).get_value("ch")

	GNTestAssert.assert_approx(v1, 10.0, 0.001)
	GNTestAssert.assert_approx(v2, 10.0, 0.001)
	GNTestAssert.assert_approx(v3, 10.0, 0.001)


func test_max_cooks_per_frame_respected() -> void:
	## With max_cooks_per_frame = 1, only one node should cook per frame.
	var a := _make_constant("a", "ch", 1.0)
	var b := _make_null("b")
	_network.connect_nodes("a", 0, "b", 0)
	_sink(["b"])

	_engine.max_cooks_per_frame = 1
	_cook()

	# After one frame with limit=1, at most 1 node cooked.
	# On the next frame the remaining node(s) catch up.
	_engine.elapsed_time += _engine.current_delta
	_cook()

	# After 2 frames, both should have output
	GNTestAssert.assert_not_null(_output(b), "b eventually cooks after multiple frames")


# ═══════════════════════════════════════════════════════════════════════════════
# Expression-Driven Dirty
# ═══════════════════════════════════════════════════════════════════════════════

func test_expression_chop_ref_triggers_recook() -> void:
	## When a node referenced by a chop() expression re-cooks with a new value,
	## the expression-reading node should re-evaluate and re-cook.
	var src := _make_constant("src", "out", 3.0)
	var reader := _make_null("reader")

	var p := GNParameter.create_float("val", 0.0)
	reader.add_parameter(p)
	p.set_expression('chop("src", "out", 0)')
	_sink(["reader"])

	_cook()
	# reader's "val" param should have resolved to 3.0
	var resolved_1: float = reader.get_param_value("val")
	GNTestAssert.assert_approx(resolved_1, 3.0, 0.001, "expression reads src output")

	# Change the source value
	src.set_param_value("value0", 7.0)
	src.mark_dirty()

	_engine.elapsed_time += _engine.current_delta
	_cook()

	var resolved_2: float = reader.get_param_value("val")
	GNTestAssert.assert_approx(resolved_2, 7.0, 0.001, "expression updated after src change")


func test_par_cross_node_updates_on_change() -> void:
	## par("other", "value0") should update when the referenced param changes.
	var other := _make_constant("other", "ch", 1.0)
	var reader := _make_null("reader")

	var p := GNParameter.create_float("x", 0.0)
	reader.add_parameter(p)
	p.set_expression('par("other", "value0")')
	_sink(["reader"])

	_cook()
	GNTestAssert.assert_approx(reader.get_param_value("x"), 1.0, 0.1,
		"par() reads initial value")

	other.set_param_value("value0", 50.0)
	other.mark_dirty()

	_engine.elapsed_time += _engine.current_delta
	_cook()
	GNTestAssert.assert_approx(reader.get_param_value("x"), 50.0, 0.1,
		"par() updated after source change")


# ═══════════════════════════════════════════════════════════════════════════════
# Frame State Injection
# ═══════════════════════════════════════════════════════════════════════════════

func test_frame_state_injected() -> void:
	## Nodes should receive current_delta, elapsed_time, current_frame from engine.
	var a := _make_constant("a", "ch", 1.0)
	_engine.elapsed_time = 5.5
	_engine.current_delta = 1.0 / 30.0
	_engine.frame_count = 100
	_sink(["a"])

	_cook()

	GNTestAssert.assert_approx(a.elapsed_time, 5.5, 0.001, "elapsed_time injected")
	GNTestAssert.assert_approx(a.current_delta, 1.0 / 30.0, 0.001, "current_delta injected")
	GNTestAssert.assert_eq(a.current_frame, 100, "current_frame injected")


# ═══════════════════════════════════════════════════════════════════════════════
# Wireless Select — demand + consumer dirty (no blanket time_dependent)
# ═══════════════════════════════════════════════════════════════════════════════

func test_select_chop_wireless_updates_without_time_dependent() -> void:
	## SelectCHOP must pick up target value changes via wireless consumer dirty
	## + input-hash remote deps — without cooking every frame as time_dependent.
	var src := _make_constant("src", "v", 1.0)
	var sel := _make(SelectCHOP, "sel")
	sel.set_param_value("chop", "src")
	GNTestAssert.assert_false(sel.time_dependent,
		"SelectCHOP is not blanket time_dependent")
	var sink_n := _make_null("out")
	_network.connect_nodes("sel", 0, "out", 0)
	_sink(["out"])

	_cook()
	GNTestAssert.assert_true(src.is_active, "src demanded by Select node_ref")
	GNTestAssert.assert_not_null(_output(sel), "Select produced output")
	if _output(sel) != null:
		GNTestAssert.assert_approx(_output(sel).get_value("v", -1), 1.0, 0.01,
			"Select reads initial src value")

	src.set_param_value("value0", 7.0)
	src.mark_dirty()
	_engine.elapsed_time += _engine.current_delta
	_cook()

	GNTestAssert.assert_not_null(_output(sel), "Select still has output")
	if _output(sel) != null:
		GNTestAssert.assert_approx(_output(sel).get_value("v", -1), 7.0, 0.01,
			"Select refreshed after src cooked (wireless dirty/hash)")


func test_image_file_in_async_keep_dirty_via_cook_frame() -> void:
	## async_load must re-queue through cook_frame (keep_dirty_after_cook),
	## not rely on call_deferred("mark_dirty") fighting clear_dirty / hash skip.
	var path := "user://_test_async_img_%d.png" % Time.get_ticks_usec()
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.4, 0.6, 1.0))
	var err := img.save_png(path)
	GNTestAssert.assert_eq(err, OK, "wrote temp png")

	var node := _make(ImageFileInIMG, "filein1") as ImageFileInIMG
	node.set_param_value("async_load", true)
	node.set_param_value("file", path)
	node.set_param_value("resolution", Vector2i(0, 0))
	_sink(["filein1"])

	var ready := false
	for _i in range(60):
		_engine.elapsed_time += _engine.current_delta
		_cook()
		if node.is_load_ready():
			ready = true
			break
		OS.delay_msec(10)

	GNTestAssert.assert_true(ready, "async ImageFileIn became ready via cook_frame")
	var out := node.cached_output as GNImageData
	GNTestAssert.assert_not_null(out, "has GNImageData")
	if out != null and out.image != null:
		GNTestAssert.assert_eq(out.image.get_width(), 8, "loaded width")
		GNTestAssert.assert_eq(out.image.get_height(), 8, "loaded height")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# ═══════════════════════════════════════════════════════════════════════════════
# Graph Mutation During Cooking Disabled (structural safety)
# ═══════════════════════════════════════════════════════════════════════════════

func test_add_node_between_cooks() -> void:
	## Adding a node between cook frames should work and the new node should cook.
	var a := _make_constant("a", "ch", 1.0)
	_sink(["a"])
	_cook()

	var b := _make_null("b")
	_network.connect_nodes("a", 0, "b", 0)
	b.mark_dirty()
	_sink(["b"])

	_engine.elapsed_time += _engine.current_delta
	_cook()

	GNTestAssert.assert_not_null(_output(b), "newly added node cooked")
	GNTestAssert.assert_approx(_output(b).get_value("ch"), 1.0, 0.001)


func test_remove_node_between_cooks() -> void:
	## Removing a node between cook frames should clean up connections.
	var a := _make_constant("a", "ch", 1.0)
	var b := _make_null("b")
	var c := _make_null("c")
	_network.connect_nodes("a", 0, "b", 0)
	_network.connect_nodes("b", 0, "c", 0)
	_sink(["c"])

	_cook()
	GNTestAssert.assert_approx(_output(c).get_value("ch"), 1.0, 0.001)

	# Remove b — c loses its input
	_network.remove_node("b")
	c.mark_dirty()

	_engine.elapsed_time += _engine.current_delta
	_cook()

	# c now has no input → null output
	GNTestAssert.assert_null(_output(c), "c output null after b removed")


# ═══════════════════════════════════════════════════════════════════════════════
# Side-effect ledger + async keep_dirty (WebDAT / FileInDAT)
# ═══════════════════════════════════════════════════════════════════════════════

func test_side_effect_ledger_records_script_set_par() -> void:
	var target := _make_constant("target", "value0", 1.0)
	var script := _make(GDScriptSCRIPT, "writer")
	script.set_param_value("code", """
func cook():
	set_par("target", "value0", 2.0)
""".strip_edges())
	script.set_param_value("time_dependent", false)
	_sink(["writer"])
	_cook()

	var target_summary := _engine.get_dependency_summary("target")
	var written_by: Array = target_summary.get("written_by", [])
	GNTestAssert.assert_true(written_by.size() > 0,
			"target has runtime written_by entry")
	if written_by.size() > 0:
		GNTestAssert.assert_eq(written_by[0].get("writer_id", ""), "writer",
				"writer recorded as side-effect source")

	var writer_summary := _engine.get_dependency_summary("writer")
	var writes_to: Array = writer_summary.get("writes_to", [])
	GNTestAssert.assert_true(writes_to.size() > 0, "writer has writes_to entry")
	GNTestAssert.assert_approx(target.get_param_value("value0"), 2.0, 0.001,
			"set_par applied target value")


func test_web_dat_keep_dirty_while_fetch_pending() -> void:
	## Headless may fail to start HTTPRequest; simulate in-flight fetch directly.
	var web := _make(WebDAT, "web1")
	web.set_param_value("url", "https://example.com/")
	web._request_pending = true
	_sink(["web1"])
	_cook()
	GNTestAssert.assert_true(web.dirty,
			"WebDAT stays dirty while HTTP fetch is pending")


func test_file_in_dat_async_keep_dirty_via_cook_frame() -> void:
	var path := "user://_test_async_dat_%d.csv" % Time.get_ticks_usec()
	var f := FileAccess.open(path, FileAccess.WRITE)
	GNTestAssert.assert_not_null(f, "created temp csv")
	f.store_string("x,y\n1,2\n")
	f.close()

	var node := _make(FileInDAT, "fin1") as FileInDAT
	node.set_param_value("async_load", true)
	node.set_param_value("filepath", path)
	_sink(["fin1"])

	var ready := false
	for _i in range(60):
		_engine.elapsed_time += _engine.current_delta
		_cook()
		var out := node.cached_output as GNTableData
		if out != null and out.is_table and out.num_rows() > 0:
			ready = true
			break
		OS.delay_msec(10)

	GNTestAssert.assert_true(ready, "async FileInDAT loaded table via cook_frame")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
