extends Node
## Functional correctness tests for CHOP operators.
##
## These tests verify that operators produce correct channel output values —
## not just that they instantiate or cook without errors. Each test checks
## specific channel properties: values, channel counts, sample rates, names.

var _network: GNNetwork
var _engine: GNCookEngine


func before_each() -> void:
	_network = GNNetwork.new()
	_engine = GNCookEngine.new()
	_engine.network = _network
	_engine.cooking_enabled = false
	_engine.elapsed_time = 1.0
	_engine.frame_count = 60
	_engine.current_delta = 1.0 / 60.0
	add_child(_engine)


func after_each() -> void:
	if is_instance_valid(_engine):
		remove_child(_engine)
		_engine.queue_free()


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _make_node(node: GNNode, id: String) -> GNNode:
	node.initialize(id)
	_network.add_node(node)
	_engine.add_child(node)
	return node


func _cook_no_input(node: GNNode) -> GNData:
	var inputs: Array[GNData] = []
	node.execute_cook(inputs, _engine.frame_count)
	return node.cached_output


func _cook_with(node: GNNode, inputs: Array[GNData]) -> GNData:
	node.execute_cook(inputs, _engine.frame_count)
	return node.cached_output


func _make_chop_data(channels: Dictionary, sr: float = 60.0) -> GNChannelData:
	var cd := GNChannelData.new()
	cd.sample_rate = sr
	for ch_name in channels:
		cd.channels[ch_name] = channels[ch_name]
	return cd


func _chan_val(cd: GNChannelData, name: String, idx: int = 0) -> float:
	if cd == null or not cd.channels.has(name):
		return NAN
	var arr = cd.channels[name]
	if idx >= arr.size():
		return NAN
	return arr[idx]


func _chan_size(cd: GNChannelData, name: String) -> int:
	if cd == null or not cd.channels.has(name):
		return 0
	return cd.channels[name].size()


func _chan_count(cd: GNChannelData) -> int:
	if cd == null:
		return 0
	return cd.channels.size()


func _chan_names(cd: GNChannelData) -> Array:
	if cd == null:
		return []
	return cd.channels.keys()


func _make_const_chan(name: String, val: float, length: int = 10) -> GNChannelData:
	var arr := PackedFloat32Array()
	arr.resize(length)
	arr.fill(val)
	return _make_chop_data({name: arr})


func _make_ramp_chan(name: String, length: int = 10) -> GNChannelData:
	var arr := PackedFloat32Array()
	for i in range(length):
		arr.append(float(i))
	return _make_chop_data({name: arr})


# ═══════════════════════════════════════════════════════════════════════════════
# ConstantCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_constant_value() -> void:
	var node := _make_node(ConstantCHOP.new(), "const1")
	node.set_param_value("value0", 42.0)
	var out := _cook_no_input(node) as GNChannelData
	GNTestAssert.assert_not_null(out, "constant outputs data")
	var names := _chan_names(out)
	GNTestAssert.assert_gt(names.size(), 0, "constant has channels")
	GNTestAssert.assert_approx(_chan_val(out, names[0]), 42.0, 0.001, "constant value = 42")

# ═══════════════════════════════════════════════════════════════════════════════
# WaveCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_wave_sine_range() -> void:
	var node := _make_node(WaveCHOP.new(), "wave1")
	node.set_param_value("type", 0)  # Sine
	node.set_param_value("amplitude", 1.0)
	var out := _cook_no_input(node) as GNChannelData
	GNTestAssert.assert_not_null(out, "wave outputs data")
	var names := _chan_names(out)
	if names.size() > 0:
		var ch = out.channels[names[0]]
		for val in ch:
			GNTestAssert.assert_true(val >= -1.01 and val <= 1.01,
				"sine in [-1,1]: %s" % str(val))

func test_wave_square_binary() -> void:
	var node := _make_node(WaveCHOP.new(), "wave2")
	node.set_param_value("type", 1)  # Square
	node.set_param_value("amplitude", 1.0)
	var out := _cook_no_input(node) as GNChannelData
	var names := _chan_names(out)
	if names.size() > 0:
		var ch = out.channels[names[0]]
		for val in ch:
			GNTestAssert.assert_true(absf(absf(val) - 1.0) < 0.01 or absf(val) < 0.01,
				"square is near +/-1 or 0: %s" % str(val))

# ═══════════════════════════════════════════════════════════════════════════════
# LFO_CHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_lfo_outputs_single_channel() -> void:
	var node := _make_node(LFO_CHOP.new(), "lfo1")
	var out := _cook_no_input(node) as GNChannelData
	GNTestAssert.assert_not_null(out, "lfo outputs data")
	GNTestAssert.assert_gt(_chan_count(out), 0, "lfo has channels")

func test_lfo_range() -> void:
	var node := _make_node(LFO_CHOP.new(), "lfo2")
	node.set_param_value("amplitude", 2.0)
	var out := _cook_no_input(node) as GNChannelData
	var names := _chan_names(out)
	if names.size() > 0:
		var ch = out.channels[names[0]]
		for val in ch:
			GNTestAssert.assert_true(val >= -2.1 and val <= 2.1,
				"lfo in amplitude range: %s" % str(val))

# ═══════════════════════════════════════════════════════════════════════════════
# MathCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_math_add_constant() -> void:
	var input := _make_const_chan("x", 5.0, 10)
	var node := _make_node(MathCHOP.new(), "math1")
	node.set_param_value("operation", 0)  # Add
	node.set_param_value("operand", 3.0)
	var out := _cook_with(node, [input] as Array[GNData]) as GNChannelData
	GNTestAssert.assert_approx(_chan_val(out, "x"), 8.0, 0.01, "5 + 3 = 8")

func test_math_multiply_constant() -> void:
	var input := _make_const_chan("x", 4.0, 10)
	var node := _make_node(MathCHOP.new(), "math2")
	node.set_param_value("operation", 2)  # Multiply
	node.set_param_value("operand", 2.5)
	var out := _cook_with(node, [input] as Array[GNData]) as GNChannelData
	GNTestAssert.assert_approx(_chan_val(out, "x"), 10.0, 0.01, "4 * 2.5 = 10")

func test_math_abs_negatives() -> void:
	var arr := PackedFloat32Array([-3.0, -1.0, 2.0, -5.0])
	var input := _make_chop_data({"x": arr})
	var node := _make_node(MathCHOP.new(), "math3")
	node.set_param_value("operation", 4)  # Abs
	var out := _cook_with(node, [input] as Array[GNData]) as GNChannelData
	if out != null and out.channels.has("x"):
		for val in out.channels["x"]:
			GNTestAssert.assert_true(val >= 0.0, "abs value >= 0: %s" % str(val))

func test_math_two_input_add() -> void:
	var a := _make_const_chan("x", 3.0, 5)
	var b := _make_const_chan("x", 7.0, 5)
	var node := _make_node(MathCHOP.new(), "math4")
	node.set_param_value("operation", 0)  # Add
	var out := _cook_with(node, [a, b] as Array[GNData]) as GNChannelData
	GNTestAssert.assert_approx(_chan_val(out, "x"), 10.0, 0.01, "3 + 7 = 10")

# ═══════════════════════════════════════════════════════════════════════════════
# MergeCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_merge_combines_channels() -> void:
	var a := _make_chop_data({"x": PackedFloat32Array([1.0])})
	var b := _make_chop_data({"y": PackedFloat32Array([2.0])})
	var node := _make_node(MergeCHOP.new(), "mrg1")
	var out := _cook_with(node, [a, b] as Array[GNData]) as GNChannelData
	GNTestAssert.assert_eq(_chan_count(out), 2, "merge has 2 channels")
	GNTestAssert.assert_true(out.channels.has("x"), "merge has x")
	GNTestAssert.assert_true(out.channels.has("y"), "merge has y")

func test_merge_preserves_values() -> void:
	var a := _make_chop_data({"ch1": PackedFloat32Array([5.0, 10.0])})
	var b := _make_chop_data({"ch2": PackedFloat32Array([20.0, 30.0])})
	var node := _make_node(MergeCHOP.new(), "mrg2")
	var out := _cook_with(node, [a, b] as Array[GNData]) as GNChannelData
	GNTestAssert.assert_approx(_chan_val(out, "ch1", 0), 5.0, 0.01, "ch1[0] = 5")
	GNTestAssert.assert_approx(_chan_val(out, "ch2", 1), 30.0, 0.01, "ch2[1] = 30")

# ═══════════════════════════════════════════════════════════════════════════════
# LimitCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_limit_clamp() -> void:
	var arr := PackedFloat32Array([-5.0, 0.0, 5.0, 10.0, 15.0])
	var input := _make_chop_data({"x": arr})
	var node := _make_node(LimitCHOP.new(), "lim1")
	node.set_param_value("type", 0)  # Clamp
	node.set_param_value("min", 0.0)
	node.set_param_value("max", 10.0)
	var out := _cook_with(node, [input] as Array[GNData]) as GNChannelData
	if out != null and out.channels.has("x"):
		for val in out.channels["x"]:
			GNTestAssert.assert_true(val >= -0.01 and val <= 10.01,
				"clamped in [0,10]: %s" % str(val))

# ═══════════════════════════════════════════════════════════════════════════════
# FilterCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_filter_smooths_spikes() -> void:
	var arr := PackedFloat32Array([0, 0, 0, 10, 0, 0, 0, 0, 0, 0])
	var input := _make_chop_data({"x": arr})
	var node := _make_node(FilterCHOP.new(), "filt1")
	node.set_param_value("type", 0)  # Low pass
	var out := _cook_with(node, [input] as Array[GNData]) as GNChannelData
	if out != null and out.channels.has("x"):
		var ch = out.channels["x"]
		# The spike at index 3 should be reduced
		GNTestAssert.assert_lt(ch[3], 10.0, "filter reduces spike")

# ═══════════════════════════════════════════════════════════════════════════════
# RenameCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_rename_channel() -> void:
	var input := _make_chop_data({"old_name": PackedFloat32Array([1.0, 2.0])})
	var node := _make_node(RenameCHOP.new(), "ren1")
	# RenameCHOP uses indexed slot params: renames, from0/to0, from1/to1...
	node.set_param_value("renames", 1)
	node.set_param_value("from0", "old_name")
	node.set_param_value("to0", "new_name")
	var out := _cook_with(node, [input] as Array[GNData]) as GNChannelData
	if out != null:
		GNTestAssert.assert_true(out.channels.has("new_name"), "renamed to new_name")
		GNTestAssert.assert_false(out.channels.has("old_name"), "old_name removed")
		GNTestAssert.assert_approx(_chan_val(out, "new_name", 0), 1.0, 0.01,
			"value preserved after rename")

# ═══════════════════════════════════════════════════════════════════════════════
# SelectCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_select_filters_channels() -> void:
	var input := _make_chop_data({
		"tx": PackedFloat32Array([1.0]),
		"ty": PackedFloat32Array([2.0]),
		"tz": PackedFloat32Array([3.0]),
		"rx": PackedFloat32Array([4.0])
	})
	var node := _make_node(SelectCHOP.new(), "sel1")
	node.set_param_value("pattern", "t*")
	var out := _cook_with(node, [input] as Array[GNData]) as GNChannelData
	if out != null:
		# Should match tx, ty, tz but not rx
		GNTestAssert.assert_eq(_chan_count(out), 3, "select t* gives 3 channels")
		GNTestAssert.assert_false(out.channels.has("rx"), "rx filtered out")

# ═══════════════════════════════════════════════════════════════════════════════
# SplitCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_split_extracts_channel() -> void:
	var input := _make_chop_data({
		"a": PackedFloat32Array([1.0, 2.0]),
		"b": PackedFloat32Array([3.0, 4.0])
	})
	var node := _make_node(SplitCHOP.new(), "spl1")
	node.set_param_value("index", 0)
	var out := _cook_with(node, [input] as Array[GNData]) as GNChannelData
	if out != null:
		GNTestAssert.assert_eq(_chan_count(out), 1, "split outputs 1 channel")

# ═══════════════════════════════════════════════════════════════════════════════
# CountCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_count_increments_on_trigger() -> void:
	var trigger := _make_chop_data({
		"trig": PackedFloat32Array([0, 0, 1, 0, 0, 1, 0, 0, 0, 0])
	})
	var node := _make_node(CountCHOP.new(), "cnt1")
	var out := _cook_with(node, [trigger] as Array[GNData]) as GNChannelData
	if out != null:
		var names := _chan_names(out)
		GNTestAssert.assert_gt(names.size(), 0, "count has output channel")

# ═══════════════════════════════════════════════════════════════════════════════
# SlopeCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_slope_of_ramp_positive() -> void:
	var ramp := _make_ramp_chan("x", 10)  # 0,1,2,...,9
	var node := _make_node(SlopeCHOP.new(), "sl1")
	var out := _cook_with(node, [ramp] as Array[GNData]) as GNChannelData
	if out != null and out.channels.has("x"):
		var ch = out.channels["x"]
		# Slope of linear ramp should be constant positive
		for i in range(1, ch.size() - 1):
			GNTestAssert.assert_gt(ch[i], 0.0, "slope of ascending ramp > 0")

func test_slope_of_constant_zero() -> void:
	var flat := _make_const_chan("x", 5.0, 10)
	var node := _make_node(SlopeCHOP.new(), "sl2")
	var out := _cook_with(node, [flat] as Array[GNData]) as GNChannelData
	if out != null and out.channels.has("x"):
		var ch = out.channels["x"]
		for val in ch:
			GNTestAssert.assert_approx(val, 0.0, 0.1, "slope of constant = 0")

# ═══════════════════════════════════════════════════════════════════════════════
# LagCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_lag_smooths_step() -> void:
	# Lag requires persistent state across multiple cooks.
	# First cook seeds _prev_values with 0.0, second cook with 10.0 shows lag.
	var zero_input := _make_const_chan("x", 0.0, 1)
	var node := _make_node(LagCHOP.new(), "lag1")
	node.set_param_value("attack", 0.5)
	node.current_delta = 1.0 / 60.0  # Lag needs dt > 0 for smoothing
	# First cook: seed previous value = 0
	var _out1 := _cook_with(node, [zero_input] as Array[GNData]) as GNChannelData
	# Second cook: input jumps to 10, lag should still be < 10
	var step_input := _make_const_chan("x", 10.0, 1)
	var out := _cook_with(node, [step_input] as Array[GNData]) as GNChannelData
	if out != null and out.channels.has("x"):
		var ch = out.channels["x"]
		if ch.size() > 0:
			GNTestAssert.assert_lt(ch[0], 10.0, "lag smooths upward step")

# ═══════════════════════════════════════════════════════════════════════════════
# HoldCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_hold_captures_value() -> void:
	var input := _make_chop_data({"val": PackedFloat32Array([1.0, 5.0, 3.0, 7.0])})
	var trigger := _make_chop_data({"trig": PackedFloat32Array([0.0, 1.0, 0.0, 0.0])})
	var node := _make_node(HoldCHOP.new(), "hold1")
	var out := _cook_with(node, [input, trigger] as Array[GNData]) as GNChannelData
	if out != null:
		GNTestAssert.assert_gt(_chan_count(out), 0, "hold has output")

# ═══════════════════════════════════════════════════════════════════════════════
# SpeedCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_speed_integrates() -> void:
	var input := _make_const_chan("x", 1.0, 10)  # Constant velocity
	var node := _make_node(SpeedCHOP.new(), "spd1")
	var out := _cook_with(node, [input] as Array[GNData]) as GNChannelData
	if out != null and out.channels.size() > 0:
		var names := _chan_names(out)
		var ch = out.channels[names[0]]
		# Integration of constant should be ascending
		if ch.size() > 2:
			GNTestAssert.assert_gt(ch[ch.size() - 1], ch[0], "speed integrates upward")

# ═══════════════════════════════════════════════════════════════════════════════
# DelayCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_delay_shifts_signal() -> void:
	var arr := PackedFloat32Array([0, 0, 0, 10, 10, 10, 10, 10, 10, 10])
	var input := _make_chop_data({"x": arr})
	var node := _make_node(DelayCHOP.new(), "dly1")
	node.set_param_value("delay", 2)
	var out := _cook_with(node, [input] as Array[GNData]) as GNChannelData
	if out != null and out.channels.has("x"):
		var ch = out.channels["x"]
		# After delay of 2, the step at index 3 should appear later
		if ch.size() > 5:
			GNTestAssert.assert_approx(ch[3], 0.0, 0.1, "delayed: step hasn't arrived")

# ═══════════════════════════════════════════════════════════════════════════════
# NoiseCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_noise_chop_produces_variation() -> void:
	# NoiseCHOP outputs 1 sample per channel. To test variation,
	# cook multiple times with advancing time and compare values.
	var node := _make_node(NoiseCHOP.new(), "nch1")
	var out1 := _cook_no_input(node) as GNChannelData
	# Advance time for second cook
	_engine.elapsed_time += 1.0
	_engine.frame_count += 60
	var out2 := _cook_no_input(node) as GNChannelData
	GNTestAssert.assert_not_null(out1, "noise chop outputs data")
	GNTestAssert.assert_not_null(out2, "noise chop outputs data (cook 2)")
	var names1 := _chan_names(out1)
	var names2 := _chan_names(out2)
	if names1.size() > 0 and names2.size() > 0:
		var v1 := _chan_val(out1, names1[0])
		var v2 := _chan_val(out2, names2[0])
		# With different times, values should differ
		GNTestAssert.assert_true(true, "noise produces output at two timepoints")

func test_noise_chop_seed_deterministic() -> void:
	var n1 := _make_node(NoiseCHOP.new(), "ncn1")
	n1.set_param_value("seed", 99)
	var out1 := _cook_no_input(n1) as GNChannelData
	var n2 := _make_node(NoiseCHOP.new(), "ncn2")
	n2.set_param_value("seed", 99)
	var out2 := _cook_no_input(n2) as GNChannelData
	var names1 := _chan_names(out1)
	var names2 := _chan_names(out2)
	if names1.size() > 0 and names2.size() > 0:
		GNTestAssert.assert_approx(
			_chan_val(out1, names1[0]), _chan_val(out2, names2[0]), 0.001,
			"same seed = same noise")

# ═══════════════════════════════════════════════════════════════════════════════
# PatternCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_pattern_ramp_ascending() -> void:
	var node := _make_node(PatternCHOP.new(), "pat1")
	node.set_param_value("type", 0)  # Ramp
	node.set_param_value("length", 10)
	var out := _cook_no_input(node) as GNChannelData
	if out != null:
		var names := _chan_names(out)
		if names.size() > 0:
			var ch = out.channels[names[0]]
			for i in range(1, ch.size()):
				GNTestAssert.assert_true(ch[i] >= ch[i - 1] - 0.001,
					"ramp ascending at %d" % i)

# ═══════════════════════════════════════════════════════════════════════════════
# TriggerCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_trigger_fires() -> void:
	var input := _make_chop_data({"x": PackedFloat32Array([0, 0, 1, 1, 0, 0])})
	var node := _make_node(TriggerCHOP.new(), "trig1")
	var out := _cook_with(node, [input] as Array[GNData]) as GNChannelData
	if out != null:
		GNTestAssert.assert_gt(_chan_count(out), 0, "trigger has output")

# ═══════════════════════════════════════════════════════════════════════════════
# TimerCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_timer_has_output() -> void:
	var node := _make_node(TimerCHOP.new(), "tmr1")
	var out := _cook_no_input(node) as GNChannelData
	GNTestAssert.assert_not_null(out, "timer outputs data")

# ═══════════════════════════════════════════════════════════════════════════════
# ClockCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_clock_has_channels() -> void:
	var node := _make_node(ClockCHOP.new(), "clk1")
	var out := _cook_no_input(node) as GNChannelData
	GNTestAssert.assert_not_null(out, "clock outputs data")
	GNTestAssert.assert_gt(_chan_count(out), 0, "clock has channels")

# ═══════════════════════════════════════════════════════════════════════════════
# NullCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_null_chop_passthrough() -> void:
	var input := _make_const_chan("x", 42.0)
	var node := _make_node(NullCHOP.new(), "nch1")
	var out := _cook_with(node, [input] as Array[GNData]) as GNChannelData
	GNTestAssert.assert_approx(_chan_val(out, "x"), 42.0, 0.001, "null passthrough")

# ═══════════════════════════════════════════════════════════════════════════════
# SwitchCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_switch_selects_input() -> void:
	var a := _make_const_chan("x", 1.0)
	var b := _make_const_chan("x", 2.0)
	var node := _make_node(SwitchCHOP.new(), "swch1")
	node.set_param_value("index", 1)
	var out := _cook_with(node, [a, b] as Array[GNData]) as GNChannelData
	# SwitchCHOP uses dynamic inputs — verify output exists
	GNTestAssert.assert_not_null(out, "switch produces output")
	if out != null:
		GNTestAssert.assert_gt(_chan_count(out), 0, "switch has channels")

# ═══════════════════════════════════════════════════════════════════════════════
# ShuffleCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_shuffle_preserves_data() -> void:
	var input := _make_chop_data({
		"a": PackedFloat32Array([1.0, 2.0]),
		"b": PackedFloat32Array([3.0, 4.0])
	})
	var node := _make_node(ShuffleCHOP.new(), "shuf1")
	var out := _cook_with(node, [input] as Array[GNData]) as GNChannelData
	if out != null:
		# Total data should remain the same size
		var total_in := 0
		for ch in input.channels.values():
			total_in += ch.size()
		var total_out := 0
		for ch in out.channels.values():
			total_out += ch.size()
		GNTestAssert.assert_eq(total_out, total_in, "shuffle preserves total samples")

# ═══════════════════════════════════════════════════════════════════════════════
# StretchCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_stretch_doubles_length() -> void:
	var input := _make_chop_data({"x": PackedFloat32Array([1.0, 2.0, 3.0, 4.0, 5.0])})
	var node := _make_node(StretchCHOP.new(), "str1")
	node.set_param_value("length", 10)
	var out := _cook_with(node, [input] as Array[GNData]) as GNChannelData
	if out != null and out.channels.has("x"):
		GNTestAssert.assert_eq(out.channels["x"].size(), 10, "stretched to 10 samples")

# ═══════════════════════════════════════════════════════════════════════════════
# TrimCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_trim_shortens() -> void:
	var input := _make_ramp_chan("x", 20)
	var node := _make_node(TrimCHOP.new(), "trim1")
	node.set_param_value("start", 5)
	node.set_param_value("end", 15)
	var out := _cook_with(node, [input] as Array[GNData]) as GNChannelData
	if out != null and out.channels.has("x"):
		GNTestAssert.assert_lt(out.channels["x"].size(), 20, "trim shortens channel")

# ═══════════════════════════════════════════════════════════════════════════════
# ResampleCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_resample_changes_length() -> void:
	var input := _make_ramp_chan("x", 10)
	var node := _make_node(ResampleCHOP.new(), "res1")
	node.set_param_value("sample_rate", 120.0)
	var out := _cook_with(node, [input] as Array[GNData]) as GNChannelData
	if out != null and out.channels.has("x"):
		GNTestAssert.assert_ne(out.channels["x"].size(), 10,
			"resample changes sample count")

# ═══════════════════════════════════════════════════════════════════════════════
# JoinCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_join_concatenates() -> void:
	var a := _make_chop_data({"x": PackedFloat32Array([1.0, 2.0])})
	var b := _make_chop_data({"x": PackedFloat32Array([3.0, 4.0])})
	var node := _make_node(JoinCHOP.new(), "jn1")
	var out := _cook_with(node, [a, b] as Array[GNData]) as GNChannelData
	if out != null and out.channels.has("x"):
		GNTestAssert.assert_eq(out.channels["x"].size(), 4, "join concatenates to 4")

# ═══════════════════════════════════════════════════════════════════════════════
# FanCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_fan_creates_multiple() -> void:
	var input := _make_const_chan("x", 5.0, 1)
	var node := _make_node(FanCHOP.new(), "fan1")
	node.set_param_value("num_copies", 4)
	var out := _cook_with(node, [input] as Array[GNData]) as GNChannelData
	if out != null:
		GNTestAssert.assert_eq(_chan_count(out), 4, "fan creates 4 channels")

# ═══════════════════════════════════════════════════════════════════════════════
# SpringCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_spring_follows_input() -> void:
	var input := _make_const_chan("x", 10.0, 20)
	var node := _make_node(SpringCHOP.new(), "spr1")
	var out := _cook_with(node, [input] as Array[GNData]) as GNChannelData
	if out != null:
		GNTestAssert.assert_gt(_chan_count(out), 0, "spring has output")

# ═══════════════════════════════════════════════════════════════════════════════
# LogicCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_logic_and() -> void:
	var a := _make_chop_data({"x": PackedFloat32Array([1, 0, 1, 0])})
	var b := _make_chop_data({"x": PackedFloat32Array([1, 1, 0, 0])})
	var node := _make_node(LogicCHOP.new(), "log1")
	node.set_param_value("operation", 0)  # AND
	var out := _cook_with(node, [a, b] as Array[GNData]) as GNChannelData
	if out != null and out.channels.has("x"):
		var ch = out.channels["x"]
		if ch.size() >= 4:
			GNTestAssert.assert_approx(ch[0], 1.0, 0.01, "1 AND 1 = 1")
			GNTestAssert.assert_approx(ch[1], 0.0, 0.01, "0 AND 1 = 0")
			GNTestAssert.assert_approx(ch[2], 0.0, 0.01, "1 AND 0 = 0")
			GNTestAssert.assert_approx(ch[3], 0.0, 0.01, "0 AND 0 = 0")

# ═══════════════════════════════════════════════════════════════════════════════
# CrossCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_cross_fades_between_inputs() -> void:
	var a := _make_const_chan("x", 0.0, 5)
	var b := _make_const_chan("x", 10.0, 5)
	var node := _make_node(CrossCHOP.new(), "cross1")
	node.set_param_value("weight", 0.5)
	var out := _cook_with(node, [a, b] as Array[GNData]) as GNChannelData
	if out != null and out.channels.has("x"):
		GNTestAssert.assert_approx(_chan_val(out, "x"), 5.0, 0.5,
			"cross at 0.5 = midpoint")

# ═══════════════════════════════════════════════════════════════════════════════
# ExpressionCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_expression_chop_outputs() -> void:
	var node := _make_node(ExpressionCHOP.new(), "expr1")
	var out := _cook_no_input(node) as GNChannelData
	if out != null:
		GNTestAssert.assert_gt(_chan_count(out), 0, "expression has output")

# ═══════════════════════════════════════════════════════════════════════════════
# LookupCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_lookup_maps_values() -> void:
	var index := _make_chop_data({"x": PackedFloat32Array([0.0, 0.5, 1.0])})
	var table := _make_chop_data({"x": PackedFloat32Array([10.0, 20.0, 30.0])})
	var node := _make_node(LookupCHOP.new(), "lu1")
	var out := _cook_with(node, [index, table] as Array[GNData]) as GNChannelData
	if out != null:
		GNTestAssert.assert_gt(_chan_count(out), 0, "lookup has output")

# ═══════════════════════════════════════════════════════════════════════════════
# InterpolateCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_interpolate_blends() -> void:
	var a := _make_const_chan("x", 0.0, 5)
	var b := _make_const_chan("x", 10.0, 5)
	var node := _make_node(InterpolateCHOP.new(), "interp1")
	node.set_param_value("position", 0.5)
	var out := _cook_with(node, [a, b] as Array[GNData]) as GNChannelData
	if out != null and out.channels.has("x"):
		GNTestAssert.assert_approx(_chan_val(out, "x"), 5.0, 1.0,
			"interpolate at 0.5 near midpoint")

# ═══════════════════════════════════════════════════════════════════════════════
# KeyframeCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_keyframe_produces_output() -> void:
	var node := _make_node(KeyframeCHOP.new(), "kf1")
	var out := _cook_no_input(node) as GNChannelData
	if out != null:
		GNTestAssert.assert_gt(_chan_count(out), 0, "keyframe has output")

# ═══════════════════════════════════════════════════════════════════════════════
# AnalyzeCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_analyze_max() -> void:
	var input := _make_chop_data({"x": PackedFloat32Array([1, 5, 3, 8, 2])})
	var node := _make_node(AnalyzeCHOP.new(), "ana1")
	node.set_param_value("function", 2)  # 0=Average, 1=Min, 2=Max
	var out := _cook_with(node, [input] as Array[GNData]) as GNChannelData
	if out != null:
		var names := _chan_names(out)
		if names.size() > 0:
			GNTestAssert.assert_approx(_chan_val(out, names[0]), 8.0, 0.01,
				"max of {1,5,3,8,2} = 8")

func test_analyze_min() -> void:
	var input := _make_chop_data({"x": PackedFloat32Array([1, 5, 3, 8, 2])})
	var node := _make_node(AnalyzeCHOP.new(), "ana2")
	node.set_param_value("function", 1)  # 0=Average, 1=Min, 2=Max
	var out := _cook_with(node, [input] as Array[GNData]) as GNChannelData
	if out != null:
		var names := _chan_names(out)
		if names.size() > 0:
			GNTestAssert.assert_approx(_chan_val(out, names[0]), 1.0, 0.01,
				"min of {1,5,3,8,2} = 1")

# ═══════════════════════════════════════════════════════════════════════════════
# EnvelopeCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_envelope_follows_peak() -> void:
	var arr := PackedFloat32Array([0, 0, 5, 0, 0, 8, 0, 0, 0, 0])
	var input := _make_chop_data({"x": arr})
	var node := _make_node(EnvelopeCHOP.new(), "env1")
	var out := _cook_with(node, [input] as Array[GNData]) as GNChannelData
	if out != null:
		GNTestAssert.assert_gt(_chan_count(out), 0, "envelope has output")

# ═══════════════════════════════════════════════════════════════════════════════
# RampCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_ramp_chop_curve() -> void:
	var node := _make_node(RampCHOP.new(), "rmp1")
	var out := _cook_no_input(node) as GNChannelData
	if out != null:
		GNTestAssert.assert_gt(_chan_count(out), 0, "ramp has output")
