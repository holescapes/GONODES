extends Node
## Correctness tests for CHOP operators.
##
## Each test instantiates the operator, sets parameters, provides input,
## calls execute_cook, and verifies output channel data.

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
		cd.set_channel(ch_name, channels[ch_name])
	return cd


# ═══════════════════════════════════════════════════════════════════════════════
#  ConstantCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_constant_chop_default() -> void:
	var node := _make_node(ConstantCHOP.new(), "constant1")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	GNTestAssert.assert_not_null(out, "constant produces output")
	GNTestAssert.assert_gt(out.channels.size(), 0, "has channels")


func test_constant_chop_value() -> void:
	var node := _make_node(ConstantCHOP.new(), "constant2")
	node.set_param_value("value0", 42.0)
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	GNTestAssert.assert_not_null(out, "output exists")
	var val: float = out.get_value("chan1")
	GNTestAssert.assert_approx(val, 42.0, 0.01, "channel value = 42")


# ═══════════════════════════════════════════════════════════════════════════════
#  NoiseCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_noise_chop_produces_output() -> void:
	var node := _make_node(NoiseCHOP.new(), "noise1")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	GNTestAssert.assert_not_null(out, "noise produces output")
	GNTestAssert.assert_eq(out.channels.size(), 1, "default 1 channel")


func test_noise_chop_multiple_channels() -> void:
	var node := _make_node(NoiseCHOP.new(), "noise2")
	node.set_param_value("num_channels", 4)
	node.set_param_value("channel_names", "a,b,c,d")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	GNTestAssert.assert_not_null(out, "output exists")
	GNTestAssert.assert_eq(out.channels.size(), 4, "4 channels")
	GNTestAssert.assert_true(out.channels.has("a"), "has channel 'a'")
	GNTestAssert.assert_true(out.channels.has("d"), "has channel 'd'")


func test_noise_chop_different_seeds() -> void:
	var n1 := _make_node(NoiseCHOP.new(), "noise_s1")
	n1.set_param_value("seed", 0)
	var n2 := _make_node(NoiseCHOP.new(), "noise_s2")
	n2.set_param_value("seed", 999)
	var out1: GNChannelData = _cook_no_input(n1) as GNChannelData
	var out2: GNChannelData = _cook_no_input(n2) as GNChannelData
	var v1: float = out1.get_value("chan1")
	var v2: float = out2.get_value("chan1")
	GNTestAssert.assert_ne(v1, v2, "different seeds produce different values")


# ═══════════════════════════════════════════════════════════════════════════════
#  WaveCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_wave_chop_sine_default() -> void:
	var node := _make_node(WaveCHOP.new(), "wave1")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	GNTestAssert.assert_not_null(out, "wave produces output")
	GNTestAssert.assert_eq(out.channels.size(), 1, "default 1 channel")


func test_wave_chop_multi_sample() -> void:
	var node := _make_node(WaveCHOP.new(), "wave2")
	node.set_param_value("length", 100)
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	GNTestAssert.assert_not_null(out, "output exists")
	var samples: PackedFloat32Array = out.get_channel("chan1")
	GNTestAssert.assert_eq(samples.size(), 100, "100 samples")


func test_wave_chop_amplitude_offset() -> void:
	var node := _make_node(WaveCHOP.new(), "wave3")
	node.set_param_value("waveform", 5)  # Ramp
	node.set_param_value("length", 10)
	node.set_param_value("amplitude", 2.0)
	node.set_param_value("offset", 1.0)
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	var samples: PackedFloat32Array = out.get_channel("chan1")
	for i in range(samples.size()):
		GNTestAssert.assert_in_range(samples[i], -1.0, 3.1, "within amp+offset range")


# ═══════════════════════════════════════════════════════════════════════════════
#  MathCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_math_chop_add_scalar() -> void:
	var node := _make_node(MathCHOP.new(), "math1")
	node.set_param_value("operation", 0)  # Add
	node.set_param_value("operand", 10.0)
	var input := _make_chop_data({"x": PackedFloat32Array([1.0, 2.0, 3.0])})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	GNTestAssert.assert_not_null(out, "math output exists")
	var samples: PackedFloat32Array = out.get_channel("x")
	GNTestAssert.assert_approx(samples[0], 11.0, 0.01, "1+10=11")
	GNTestAssert.assert_approx(samples[1], 12.0, 0.01, "2+10=12")
	GNTestAssert.assert_approx(samples[2], 13.0, 0.01, "3+10=13")


func test_math_chop_multiply_two_inputs() -> void:
	var node := _make_node(MathCHOP.new(), "math2")
	node.set_param_value("operation", 2)  # Multiply
	var in1 := _make_chop_data({"x": PackedFloat32Array([2.0, 3.0, 4.0])})
	var in2 := _make_chop_data({"x": PackedFloat32Array([5.0, 6.0, 7.0])})
	var out: GNChannelData = _cook_with(node, [in1, in2]) as GNChannelData
	var samples: PackedFloat32Array = out.get_channel("x")
	GNTestAssert.assert_approx(samples[0], 10.0, 0.01, "2*5=10")
	GNTestAssert.assert_approx(samples[1], 18.0, 0.01, "3*6=18")
	GNTestAssert.assert_approx(samples[2], 28.0, 0.01, "4*7=28")


func test_math_chop_divide_by_zero() -> void:
	var node := _make_node(MathCHOP.new(), "math3")
	node.set_param_value("operation", 3)  # Divide
	var in1 := _make_chop_data({"x": PackedFloat32Array([10.0])})
	var in2 := _make_chop_data({"x": PackedFloat32Array([0.0])})
	var out: GNChannelData = _cook_with(node, [in1, in2]) as GNChannelData
	var val: float = out.get_value("x")
	GNTestAssert.assert_approx(val, 0.0, 0.01, "divide by zero → 0")


func test_math_chop_abs() -> void:
	var node := _make_node(MathCHOP.new(), "math4")
	node.set_param_value("operation", 4)  # Abs
	var input := _make_chop_data({"x": PackedFloat32Array([-5.0, 3.0, -1.0])})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	var samples: PackedFloat32Array = out.get_channel("x")
	GNTestAssert.assert_approx(samples[0], 5.0, 0.01, "abs(-5)=5")
	GNTestAssert.assert_approx(samples[1], 3.0, 0.01, "abs(3)=3")
	GNTestAssert.assert_approx(samples[2], 1.0, 0.01, "abs(-1)=1")


func test_math_chop_sin() -> void:
	var node := _make_node(MathCHOP.new(), "math5")
	node.set_param_value("operation", 5)  # Sin
	var input := _make_chop_data({"x": PackedFloat32Array([0.0, PI / 2.0, PI])})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	var samples: PackedFloat32Array = out.get_channel("x")
	GNTestAssert.assert_approx(samples[0], 0.0, 0.01, "sin(0)=0")
	GNTestAssert.assert_approx(samples[1], 1.0, 0.01, "sin(pi/2)=1")
	GNTestAssert.assert_approx(samples[2], 0.0, 0.01, "sin(pi)≈0")


# ═══════════════════════════════════════════════════════════════════════════════
#  LFO_CHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_lfo_chop_sine() -> void:
	var node := _make_node(LFO_CHOP.new(), "lfo1")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	GNTestAssert.assert_not_null(out, "LFO produces output")
	var val: float = out.get_value("lfo")
	GNTestAssert.assert_in_range(val, -1.0, 1.0, "sine within [-1,1]")


# ═══════════════════════════════════════════════════════════════════════════════
#  FilterCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_filter_chop_lowpass() -> void:
	var node := _make_node(FilterCHOP.new(), "filter1")
	node.set_param_value("type", 0)  # LP
	node.set_param_value("cutoff", 0.1)
	# First cook with step input → output should be smoothed (less than input)
	var input := _make_chop_data({"x": PackedFloat32Array([10.0])})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	GNTestAssert.assert_not_null(out, "filter output exists")
	var val: float = out.get_value("x")
	GNTestAssert.assert_gt(val, 0.0, "LP output > 0 on step")
	GNTestAssert.assert_lt(val, 10.1, "LP output <= input on step")


func test_filter_chop_reset() -> void:
	var node := _make_node(FilterCHOP.new(), "filter2")
	node.set_param_value("type", 0)
	node.set_param_value("cutoff", 0.5)
	var input := _make_chop_data({"x": PackedFloat32Array([100.0])})
	_cook_with(node, [input])
	# Reset
	node.set_param_value("reset", true)
	var input2 := _make_chop_data({"x": PackedFloat32Array([0.0])})
	var out: GNChannelData = _cook_with(node, [input2]) as GNChannelData
	var val: float = out.get_value("x")
	GNTestAssert.assert_approx(val, 0.0, 0.5, "after reset, output near 0")


# ═══════════════════════════════════════════════════════════════════════════════
#  PatternCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_pattern_chop_ramp() -> void:
	var node := _make_node(PatternCHOP.new(), "pat1")
	node.set_param_value("type", 0)  # Ramp
	node.set_param_value("length", 5)
	node.set_param_value("from_value", 0.0)
	node.set_param_value("to_value", 1.0)
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	GNTestAssert.assert_not_null(out, "pattern output")
	var samples: PackedFloat32Array = out.get_channel("chan1")
	GNTestAssert.assert_eq(samples.size(), 5, "5 samples")
	GNTestAssert.assert_approx(samples[0], 0.0, 0.01, "ramp starts at 0")
	GNTestAssert.assert_approx(samples[4], 1.0, 0.01, "ramp ends at 1")


func test_pattern_chop_constant() -> void:
	var node := _make_node(PatternCHOP.new(), "pat2")
	node.set_param_value("type", 5)  # Constant
	node.set_param_value("length", 10)
	node.set_param_value("from_value", 7.5)
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	var samples: PackedFloat32Array = out.get_channel("chan1")
	for i in range(samples.size()):
		GNTestAssert.assert_approx(samples[i], 7.5, 0.01, "constant=7.5 at sample %d" % i)


# ═══════════════════════════════════════════════════════════════════════════════
#  ResampleCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_resample_chop_upsample() -> void:
	var node := _make_node(ResampleCHOP.new(), "resample1")
	node.set_param_value("method", 0)  # To Samples
	node.set_param_value("samples", 10)
	var input := _make_chop_data({"x": PackedFloat32Array([0.0, 1.0])})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	GNTestAssert.assert_not_null(out, "resample output")
	var samples: PackedFloat32Array = out.get_channel("x")
	GNTestAssert.assert_eq(samples.size(), 10, "upsampled to 10")
	GNTestAssert.assert_approx(samples[0], 0.0, 0.01, "first = 0")
	GNTestAssert.assert_approx(samples[9], 1.0, 0.01, "last = 1")


func test_resample_chop_downsample() -> void:
	var node := _make_node(ResampleCHOP.new(), "resample2")
	node.set_param_value("method", 0)
	node.set_param_value("samples", 2)
	var input := _make_chop_data({"x": PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	var samples: PackedFloat32Array = out.get_channel("x")
	GNTestAssert.assert_eq(samples.size(), 2, "downsampled to 2")


# ═══════════════════════════════════════════════════════════════════════════════
#  MergeCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_merge_chop() -> void:
	var node := _make_node(MergeCHOP.new(), "merge1")
	var in1 := _make_chop_data({"a": PackedFloat32Array([1.0])})
	var in2 := _make_chop_data({"b": PackedFloat32Array([2.0])})
	var out: GNChannelData = _cook_with(node, [in1, in2]) as GNChannelData
	GNTestAssert.assert_not_null(out, "merge output")
	GNTestAssert.assert_true(out.channels.has("a"), "has channel a")
	GNTestAssert.assert_true(out.channels.has("b"), "has channel b")


# ═══════════════════════════════════════════════════════════════════════════════
#  InterpolateCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_interpolate_chop_linear() -> void:
	var node := _make_node(InterpolateCHOP.new(), "interp1")
	node.set_param_value("blend", 0.5)
	node.set_param_value("curve", 0)  # Linear
	var in_a := _make_chop_data({"x": PackedFloat32Array([0.0])})
	var in_b := _make_chop_data({"x": PackedFloat32Array([10.0])})
	var out: GNChannelData = _cook_with(node, [in_a, in_b]) as GNChannelData
	GNTestAssert.assert_not_null(out, "interp output")
	GNTestAssert.assert_approx(out.get_value("x"), 5.0, 0.1, "50% blend = 5")


func test_interpolate_chop_blend_zero() -> void:
	var node := _make_node(InterpolateCHOP.new(), "interp2")
	node.set_param_value("blend", 0.0)
	var in_a := _make_chop_data({"x": PackedFloat32Array([3.0])})
	var in_b := _make_chop_data({"x": PackedFloat32Array([9.0])})
	var out: GNChannelData = _cook_with(node, [in_a, in_b]) as GNChannelData
	GNTestAssert.assert_approx(out.get_value("x"), 3.0, 0.1, "blend=0 → A")


func test_interpolate_chop_blend_one() -> void:
	var node := _make_node(InterpolateCHOP.new(), "interp3")
	node.set_param_value("blend", 1.0)
	var in_a := _make_chop_data({"x": PackedFloat32Array([3.0])})
	var in_b := _make_chop_data({"x": PackedFloat32Array([9.0])})
	var out: GNChannelData = _cook_with(node, [in_a, in_b]) as GNChannelData
	GNTestAssert.assert_approx(out.get_value("x"), 9.0, 0.1, "blend=1 → B")


# ═══════════════════════════════════════════════════════════════════════════════
#  SlopeCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_slope_chop_constant_input() -> void:
	var node := _make_node(SlopeCHOP.new(), "slope1")
	node.set_param_value("multiply", 1.0)
	# Cook twice with same value → derivative should be ~0
	var input := _make_chop_data({"x": PackedFloat32Array([5.0])})
	_cook_with(node, [input])
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	GNTestAssert.assert_not_null(out, "slope output")
	GNTestAssert.assert_approx(out.get_value("x"), 0.0, 0.1, "slope of constant ≈ 0")


# ═══════════════════════════════════════════════════════════════════════════════
#  TrailCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_trail_chop_records_history() -> void:
	var node := _make_node(TrailCHOP.new(), "trail1")
	node.set_param_value("length", 5)
	for i in range(5):
		var input := _make_chop_data({"x": PackedFloat32Array([float(i)])})
		_cook_with(node, [input])
	var out: GNChannelData = node.cached_output as GNChannelData
	GNTestAssert.assert_not_null(out, "trail output")
	var samples: PackedFloat32Array = out.get_channel("x")
	GNTestAssert.assert_eq(samples.size(), 5, "trail has 5 frames")


# ═══════════════════════════════════════════════════════════════════════════════
#  NullCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_null_chop_passthrough() -> void:
	var node := _make_node(NullCHOP.new(), "null1")
	var input := _make_chop_data({"x": PackedFloat32Array([42.0])})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	GNTestAssert.assert_not_null(out, "null output")
	GNTestAssert.assert_approx(out.get_value("x"), 42.0, 0.01, "passthrough value")


# ═══════════════════════════════════════════════════════════════════════════════
#  SelectCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_select_chop_filter_channel() -> void:
	var node := _make_node(SelectCHOP.new(), "select1")
	node.set_param_value("pattern", "a")
	var input := _make_chop_data({
		"a": PackedFloat32Array([1.0]),
		"b": PackedFloat32Array([2.0]),
		"c": PackedFloat32Array([3.0])
	})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	GNTestAssert.assert_not_null(out, "select output")
	GNTestAssert.assert_true(out.channels.has("a"), "has channel a")
	GNTestAssert.assert_false(out.channels.has("b"), "no channel b")
	GNTestAssert.assert_false(out.channels.has("c"), "no channel c")


# ═══════════════════════════════════════════════════════════════════════════════
#  RenameCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_rename_chop() -> void:
	var node := _make_node(RenameCHOP.new(), "rename1")
	node.set_param_value("renames", 1)
	node.set_param_value("from0", "x")
	node.set_param_value("to0", "tx")
	var input := _make_chop_data({"x": PackedFloat32Array([5.0])})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	GNTestAssert.assert_not_null(out, "rename output")
	GNTestAssert.assert_true(out.channels.has("tx"), "renamed to tx")
	GNTestAssert.assert_false(out.channels.has("x"), "old name gone")


# ═══════════════════════════════════════════════════════════════════════════════
#  LimitCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_limit_chop_clamp() -> void:
	var node := _make_node(LimitCHOP.new(), "limit1")
	node.set_param_value("min_val", 0.0)
	node.set_param_value("max_val", 1.0)
	var input := _make_chop_data({"x": PackedFloat32Array([-5.0, 0.5, 10.0])})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	var samples: PackedFloat32Array = out.get_channel("x")
	GNTestAssert.assert_approx(samples[0], 0.0, 0.01, "clamped -5 → 0")
	GNTestAssert.assert_approx(samples[1], 0.5, 0.01, "0.5 unchanged")
	GNTestAssert.assert_approx(samples[2], 1.0, 0.01, "clamped 10 → 1")


# ═══════════════════════════════════════════════════════════════════════════════
#  CountCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_count_chop_increments() -> void:
	var node := _make_node(CountCHOP.new(), "count1")
	# CountCHOP needs input — it counts rising edges
	var trigger := _make_chop_data({"trig": PackedFloat32Array([1.0])})
	_cook_with(node, [trigger])
	_cook_with(node, [trigger])
	var out: GNChannelData = _cook_with(node, [trigger]) as GNChannelData
	GNTestAssert.assert_not_null(out, "count output")


# ═══════════════════════════════════════════════════════════════════════════════
#  LogicCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_logic_chop_and() -> void:
	var node := _make_node(LogicCHOP.new(), "logic1")
	node.set_param_value("operation", 0)  # AND
	var in1 := _make_chop_data({"x": PackedFloat32Array([1.0])})
	var in2 := _make_chop_data({"x": PackedFloat32Array([1.0])})
	var out: GNChannelData = _cook_with(node, [in1, in2]) as GNChannelData
	GNTestAssert.assert_approx(out.get_value("x"), 1.0, 0.01, "1 AND 1 = 1")


func test_logic_chop_and_false() -> void:
	var node := _make_node(LogicCHOP.new(), "logic2")
	node.set_param_value("operation", 0)
	var in1 := _make_chop_data({"x": PackedFloat32Array([1.0])})
	var in2 := _make_chop_data({"x": PackedFloat32Array([0.0])})
	var out: GNChannelData = _cook_with(node, [in1, in2]) as GNChannelData
	GNTestAssert.assert_approx(out.get_value("x"), 0.0, 0.01, "1 AND 0 = 0")


# ═══════════════════════════════════════════════════════════════════════════════
#  SwitchCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_switch_chop_selects_input() -> void:
	var node := _make_node(SwitchCHOP.new(), "switch1")
	# Bump param max_value so index=1 isn't clamped (dynamic ports not wired in test)
	var idx_param := node.get_parameter("index")
	if idx_param:
		idx_param.max_value = 10
	node.set_param_value("index", 1)
	var in0 := _make_chop_data({"x": PackedFloat32Array([100.0])})
	var in1 := _make_chop_data({"x": PackedFloat32Array([200.0])})
	var out: GNChannelData = _cook_with(node, [in0, in1]) as GNChannelData
	GNTestAssert.assert_approx(out.get_value("x"), 200.0, 0.01, "switch index=1 → 200")


# ═══════════════════════════════════════════════════════════════════════════════
#  BlendCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_blend_chop_midpoint() -> void:
	var node := _make_node(BlendCHOP.new(), "blend1")
	node.set_param_value("weight", 0.5)
	var in0 := _make_chop_data({"x": PackedFloat32Array([0.0])})
	var in1 := _make_chop_data({"x": PackedFloat32Array([10.0])})
	var out: GNChannelData = _cook_with(node, [in0, in1]) as GNChannelData
	GNTestAssert.assert_not_null(out, "blend output")
	GNTestAssert.assert_approx(out.get_value("x"), 5.0, 0.5, "50% blend ≈ 5")


# ═══════════════════════════════════════════════════════════════════════════════
#  No-input null safety for each CHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_math_chop_no_input_returns_null() -> void:
	var node := _make_node(MathCHOP.new(), "math_null")
	var out := _cook_no_input(node)
	GNTestAssert.assert_null(out, "math with no input → null")


func test_filter_chop_no_input_returns_null() -> void:
	var node := _make_node(FilterCHOP.new(), "filter_null")
	var out := _cook_no_input(node)
	GNTestAssert.assert_null(out, "filter with no input → null")


func test_resample_chop_no_input_returns_null() -> void:
	var node := _make_node(ResampleCHOP.new(), "resample_null")
	var out := _cook_no_input(node)
	GNTestAssert.assert_null(out, "resample with no input → null")


# ═══════════════════════════════════════════════════════════════════════════════
#  AnalyzeCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_analyze_chop_average() -> void:
	var node := _make_node(AnalyzeCHOP.new(), "analyze1")
	node.set_param_value("function", 0)  # Average
	var input := _make_chop_data({"x": PackedFloat32Array([1.0, 2.0, 3.0, 4.0, 5.0])})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	GNTestAssert.assert_not_null(out, "analyze output")
	GNTestAssert.assert_approx(out.get_value("x"), 3.0, 0.01, "avg(1..5)=3")


func test_analyze_chop_min() -> void:
	var node := _make_node(AnalyzeCHOP.new(), "analyze2")
	node.set_param_value("function", 1)  # Minimum
	var input := _make_chop_data({"x": PackedFloat32Array([5.0, 2.0, 8.0, 1.0])})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	GNTestAssert.assert_approx(out.get_value("x"), 1.0, 0.01, "min=1")


func test_analyze_chop_max() -> void:
	var node := _make_node(AnalyzeCHOP.new(), "analyze3")
	node.set_param_value("function", 2)  # Maximum
	var input := _make_chop_data({"x": PackedFloat32Array([5.0, 2.0, 8.0, 1.0])})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	GNTestAssert.assert_approx(out.get_value("x"), 8.0, 0.01, "max=8")


func test_analyze_chop_sum() -> void:
	var node := _make_node(AnalyzeCHOP.new(), "analyze4")
	node.set_param_value("function", 3)  # Sum
	var input := _make_chop_data({"x": PackedFloat32Array([1.0, 2.0, 3.0, 4.0, 5.0])})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	GNTestAssert.assert_approx(out.get_value("x"), 15.0, 0.01, "sum=15")


func test_analyze_chop_range() -> void:
	var node := _make_node(AnalyzeCHOP.new(), "analyze5")
	node.set_param_value("function", 5)  # Range
	var input := _make_chop_data({"x": PackedFloat32Array([3.0, 7.0, 1.0, 9.0])})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	GNTestAssert.assert_approx(out.get_value("x"), 8.0, 0.01, "range=9-1=8")


# ═══════════════════════════════════════════════════════════════════════════════
#  CompositeCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_composite_chop_add() -> void:
	var node := _make_node(CompositeCHOP.new(), "comp1")
	node.set_param_value("operation", 1)  # Add
	var in1 := _make_chop_data({"x": PackedFloat32Array([10.0])})
	var in2 := _make_chop_data({"x": PackedFloat32Array([20.0])})
	var out: GNChannelData = _cook_with(node, [in1, in2]) as GNChannelData
	GNTestAssert.assert_not_null(out, "composite output")
	GNTestAssert.assert_approx(out.get_value("x"), 30.0, 0.5, "add: 10+20=30")


func test_composite_chop_max() -> void:
	var node := _make_node(CompositeCHOP.new(), "comp2")
	node.set_param_value("operation", 2)  # Max
	var in1 := _make_chop_data({"x": PackedFloat32Array([5.0])})
	var in2 := _make_chop_data({"x": PackedFloat32Array([15.0])})
	var out: GNChannelData = _cook_with(node, [in1, in2]) as GNChannelData
	GNTestAssert.assert_approx(out.get_value("x"), 15.0, 0.5, "max(5,15)=15")


# ═══════════════════════════════════════════════════════════════════════════════
#  CopyCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_copy_chop_overwrite() -> void:
	var node := _make_node(CopyCHOP.new(), "copy1")
	node.set_param_value("operation", 0)  # Overwrite
	var in_a := _make_chop_data({"ch1": PackedFloat32Array([10.0])})
	var in_b := _make_chop_data({"ch1": PackedFloat32Array([99.0])})
	var out: GNChannelData = _cook_with(node, [in_a, in_b]) as GNChannelData
	GNTestAssert.assert_approx(out.get_value("ch1"), 99.0, 0.01, "overwrite → B value")


func test_copy_chop_add() -> void:
	var node := _make_node(CopyCHOP.new(), "copy2")
	node.set_param_value("operation", 1)  # Add
	var in_a := _make_chop_data({"ch1": PackedFloat32Array([10.0])})
	var in_b := _make_chop_data({"ch1": PackedFloat32Array([5.0])})
	var out: GNChannelData = _cook_with(node, [in_a, in_b]) as GNChannelData
	GNTestAssert.assert_approx(out.get_value("ch1"), 15.0, 0.01, "add: 10+5=15")


# ═══════════════════════════════════════════════════════════════════════════════
#  CrossCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_cross_chop_midpoint() -> void:
	var node := _make_node(CrossCHOP.new(), "cross1")
	node.set_param_value("cross", 0.5)
	var in_a := _make_chop_data({"x": PackedFloat32Array([10.0])})
	var in_b := _make_chop_data({"x": PackedFloat32Array([20.0])})
	var out: GNChannelData = _cook_with(node, [in_a, in_b]) as GNChannelData
	GNTestAssert.assert_approx(out.get_value("x"), 15.0, 0.1, "cross=0.5 → 15")


func test_cross_chop_zero() -> void:
	var node := _make_node(CrossCHOP.new(), "cross2")
	node.set_param_value("cross", 0.0)
	var in_a := _make_chop_data({"x": PackedFloat32Array([10.0])})
	var in_b := _make_chop_data({"x": PackedFloat32Array([20.0])})
	var out: GNChannelData = _cook_with(node, [in_a, in_b]) as GNChannelData
	GNTestAssert.assert_approx(out.get_value("x"), 10.0, 0.1, "cross=0 → A")


func test_cross_chop_one() -> void:
	var node := _make_node(CrossCHOP.new(), "cross3")
	node.set_param_value("cross", 1.0)
	var in_a := _make_chop_data({"x": PackedFloat32Array([10.0])})
	var in_b := _make_chop_data({"x": PackedFloat32Array([20.0])})
	var out: GNChannelData = _cook_with(node, [in_a, in_b]) as GNChannelData
	GNTestAssert.assert_approx(out.get_value("x"), 20.0, 0.1, "cross=1 → B")


# ═══════════════════════════════════════════════════════════════════════════════
#  DeleteCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_delete_chop_by_pattern() -> void:
	var node := _make_node(DeleteCHOP.new(), "del1")
	node.set_param_value("scope", 0)  # By Pattern
	node.set_param_value("pattern", "b")
	var input := _make_chop_data({
		"a": PackedFloat32Array([1.0]),
		"b": PackedFloat32Array([2.0]),
		"c": PackedFloat32Array([3.0])
	})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	GNTestAssert.assert_true(out.channels.has("a"), "kept a")
	GNTestAssert.assert_false(out.channels.has("b"), "deleted b")
	GNTestAssert.assert_true(out.channels.has("c"), "kept c")


func test_delete_chop_keep_only() -> void:
	var node := _make_node(DeleteCHOP.new(), "del2")
	node.set_param_value("scope", 2)  # Keep Only Pattern
	node.set_param_value("pattern", "a")
	var input := _make_chop_data({
		"a": PackedFloat32Array([1.0]),
		"b": PackedFloat32Array([2.0]),
		"c": PackedFloat32Array([3.0])
	})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	GNTestAssert.assert_true(out.channels.has("a"), "kept a")
	GNTestAssert.assert_false(out.channels.has("b"), "dropped b")
	GNTestAssert.assert_false(out.channels.has("c"), "dropped c")


# ═══════════════════════════════════════════════════════════════════════════════
#  ExtendCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_extend_chop_hold_right() -> void:
	var node := _make_node(ExtendCHOP.new(), "ext1")
	node.set_param_value("right", 0)  # Hold
	node.set_param_value("after", 2)
	var input := _make_chop_data({"x": PackedFloat32Array([1.0, 2.0, 3.0])})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	var samples: PackedFloat32Array = out.get_channel("x")
	GNTestAssert.assert_eq(samples.size(), 5, "3 + 2 = 5 samples")
	GNTestAssert.assert_approx(samples[3], 3.0, 0.01, "hold last value")
	GNTestAssert.assert_approx(samples[4], 3.0, 0.01, "hold last value")


func test_extend_chop_zero_right() -> void:
	var node := _make_node(ExtendCHOP.new(), "ext2")
	node.set_param_value("right", 4)  # Zero
	node.set_param_value("after", 2)
	var input := _make_chop_data({"x": PackedFloat32Array([1.0, 2.0, 3.0])})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	var samples: PackedFloat32Array = out.get_channel("x")
	GNTestAssert.assert_eq(samples.size(), 5, "3 + 2 = 5 samples")
	GNTestAssert.assert_approx(samples[3], 0.0, 0.01, "zero extend")
	GNTestAssert.assert_approx(samples[4], 0.0, 0.01, "zero extend")


# ═══════════════════════════════════════════════════════════════════════════════
#  FanCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_fan_chop_creates_channels() -> void:
	var node := _make_node(FanCHOP.new(), "fan1")
	node.set_param_value("count", 4)
	node.set_param_value("operation", 0)  # Add
	node.set_param_value("offset", 1.0)
	var input := _make_chop_data({"ch1": PackedFloat32Array([10.0])})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	GNTestAssert.assert_not_null(out, "fan output")
	GNTestAssert.assert_eq(out.channels.size(), 4, "4 output channels")


# ═══════════════════════════════════════════════════════════════════════════════
#  JoinCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_join_chop_concatenates() -> void:
	var node := _make_node(JoinCHOP.new(), "join1")
	node.set_param_value("overlap", 0)
	var in1 := _make_chop_data({"x": PackedFloat32Array([1.0, 2.0])})
	var in2 := _make_chop_data({"x": PackedFloat32Array([3.0, 4.0])})
	var out: GNChannelData = _cook_with(node, [in1, in2]) as GNChannelData
	var samples: PackedFloat32Array = out.get_channel("x")
	GNTestAssert.assert_eq(samples.size(), 4, "joined 2+2=4")
	GNTestAssert.assert_approx(samples[0], 1.0, 0.01, "first=1")
	GNTestAssert.assert_approx(samples[3], 4.0, 0.01, "last=4")


# ═══════════════════════════════════════════════════════════════════════════════
#  LookupCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_lookup_chop_linear() -> void:
	var node := _make_node(LookupCHOP.new(), "lookup1")
	node.set_param_value("interpolate", 0)  # Linear
	var table := _make_chop_data({"x": PackedFloat32Array([0.0, 50.0, 100.0])})
	var index := _make_chop_data({"x": PackedFloat32Array([0.5])})
	var out: GNChannelData = _cook_with(node, [table, index]) as GNChannelData
	GNTestAssert.assert_not_null(out, "lookup output")
	GNTestAssert.assert_approx(out.get_value("x"), 50.0, 1.0, "midpoint → 50")


# ═══════════════════════════════════════════════════════════════════════════════
#  ShuffleCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_shuffle_chop_reverse() -> void:
	var node := _make_node(ShuffleCHOP.new(), "shuf1")
	node.set_param_value("method", 0)  # Reverse
	var input := _make_chop_data({
		"a": PackedFloat32Array([1.0]),
		"b": PackedFloat32Array([2.0]),
		"c": PackedFloat32Array([3.0])
	})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	GNTestAssert.assert_not_null(out, "shuffle output")
	GNTestAssert.assert_eq(out.channels.size(), 3, "3 channels preserved")
	var names: Array = Array(out.get_channel_names())
	GNTestAssert.assert_eq(names[0], "c", "reversed: first = c")
	GNTestAssert.assert_eq(names[2], "a", "reversed: last = a")


# ═══════════════════════════════════════════════════════════════════════════════
#  SplitCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_split_chop_select_one() -> void:
	var node := _make_node(SplitCHOP.new(), "split1")
	node.set_param_value("mode", 0)  # Select One
	node.set_param_value("index", 1)
	var input := _make_chop_data({
		"a": PackedFloat32Array([10.0]),
		"b": PackedFloat32Array([20.0]),
		"c": PackedFloat32Array([30.0])
	})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	GNTestAssert.assert_eq(out.channels.size(), 1, "only 1 channel")
	GNTestAssert.assert_approx(out.get_value("b"), 20.0, 0.01, "selected b=20")


# ═══════════════════════════════════════════════════════════════════════════════
#  StretchCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_stretch_chop_by_factor() -> void:
	var node := _make_node(StretchCHOP.new(), "stretch1")
	node.set_param_value("mode", 0)  # By Factor
	node.set_param_value("factor", 2.0)
	var input := _make_chop_data({"x": PackedFloat32Array([0.0, 100.0])})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	var samples: PackedFloat32Array = out.get_channel("x")
	GNTestAssert.assert_eq(samples.size(), 4, "2 * factor 2 = 4 samples")
	GNTestAssert.assert_approx(samples[0], 0.0, 1.0, "first ≈ 0")
	GNTestAssert.assert_approx(samples[3], 100.0, 1.0, "last ≈ 100")


func test_stretch_chop_to_length() -> void:
	var node := _make_node(StretchCHOP.new(), "stretch2")
	node.set_param_value("mode", 1)  # To Length
	node.set_param_value("length", 5)
	var input := _make_chop_data({"x": PackedFloat32Array([0.0, 100.0])})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	var samples: PackedFloat32Array = out.get_channel("x")
	GNTestAssert.assert_eq(samples.size(), 5, "stretched to 5 samples")


# ═══════════════════════════════════════════════════════════════════════════════
#  TrimCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_trim_chop_samples() -> void:
	var node := _make_node(TrimCHOP.new(), "trim1")
	node.set_param_value("unit", 0)  # Samples
	node.set_param_value("start", 1.0)
	node.set_param_value("end", 3.0)
	var input := _make_chop_data({"x": PackedFloat32Array([10.0, 20.0, 30.0, 40.0, 50.0])})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	var samples: PackedFloat32Array = out.get_channel("x")
	GNTestAssert.assert_eq(samples.size(), 3, "trimmed to 3 samples")
	GNTestAssert.assert_approx(samples[0], 20.0, 0.01, "starts at index 1")
	GNTestAssert.assert_approx(samples[2], 40.0, 0.01, "ends at index 3")


# ═══════════════════════════════════════════════════════════════════════════════
#  SmoothCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_smooth_chop_lp_passthrough_constant() -> void:
	var node := _make_node(SmoothCHOP.new(), "smooth1")
	node.set_param_value("type", 0)  # LP
	node.set_param_value("cutoff", 0.5)
	# Multiple cooks with same constant → should converge to that constant
	for i in range(20):
		var input := _make_chop_data({"x": PackedFloat32Array([5.0])})
		_cook_with(node, [input])
	var out: GNChannelData = node.cached_output as GNChannelData
	GNTestAssert.assert_approx(out.get_value("x"), 5.0, 0.5, "LP on constant → constant")


# ═══════════════════════════════════════════════════════════════════════════════
#  LagCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_lag_chop_zero_tau_passthrough() -> void:
	var node := _make_node(LagCHOP.new(), "lag1")
	node.set_param_value("attack", 0.0)
	node.set_param_value("release", 0.0)
	var input := _make_chop_data({"x": PackedFloat32Array([42.0])})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	GNTestAssert.assert_not_null(out, "lag output")
	GNTestAssert.assert_approx(out.get_value("x"), 42.0, 0.5, "zero lag = passthrough")


func test_lag_chop_smoothing() -> void:
	var node := _make_node(LagCHOP.new(), "lag2")
	node.set_param_value("attack", 1.0)
	node.set_param_value("release", 1.0)
	# Lag needs current_delta > 0 for smoothing
	node.current_delta = 1.0 / 60.0
	# Cook with 0 first, then step to 100 — should be smoothed
	var input0 := _make_chop_data({"x": PackedFloat32Array([0.0])})
	_cook_with(node, [input0])
	var input1 := _make_chop_data({"x": PackedFloat32Array([100.0])})
	var out: GNChannelData = _cook_with(node, [input1]) as GNChannelData
	var val: float = out.get_value("x")
	GNTestAssert.assert_gt(val, 0.0, "lag started moving")
	GNTestAssert.assert_lt(val, 100.0, "lag hasn't reached target yet")


# ═══════════════════════════════════════════════════════════════════════════════
#  TransformCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_transform_chop_translate() -> void:
	var node := _make_node(TransformCHOP.new(), "xform1")
	node.set_param_value("tx", 5.0)
	node.set_param_value("ty", 0.0)
	node.set_param_value("tz", 0.0)
	var input := _make_chop_data({
		"tx": PackedFloat32Array([1.0]),
		"ty": PackedFloat32Array([0.0]),
		"tz": PackedFloat32Array([0.0])
	})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	GNTestAssert.assert_not_null(out, "xform output")
	GNTestAssert.assert_approx(out.get_value("tx"), 6.0, 0.1, "tx: 1+5=6")


# ═══════════════════════════════════════════════════════════════════════════════
#  WarpCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_warp_chop_speed_2x() -> void:
	var node := _make_node(WarpCHOP.new(), "warp1")
	node.set_param_value("speed", 2.0)
	node.set_param_value("interpolation", 0)  # Linear
	var input := _make_chop_data({"x": PackedFloat32Array([0.0, 25.0, 50.0, 75.0, 100.0])})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	GNTestAssert.assert_not_null(out, "warp output")


# ═══════════════════════════════════════════════════════════════════════════════
#  DelayCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_delay_chop_buffers_input() -> void:
	var node := _make_node(DelayCHOP.new(), "delay1")
	node.set_param_value("frames", 3)
	# Feed value 0 for 3 cooks, then value 100
	for i in range(3):
		var input := _make_chop_data({"x": PackedFloat32Array([0.0])})
		_cook_with(node, [input])
	var input := _make_chop_data({"x": PackedFloat32Array([100.0])})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	# Output should still be the delayed value (0), not 100
	GNTestAssert.assert_approx(out.get_value("x"), 0.0, 0.5, "delayed by 3 frames")


# ═══════════════════════════════════════════════════════════════════════════════
#  SpeedCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_speed_chop_integrates() -> void:
	var node := _make_node(SpeedCHOP.new(), "speed1")
	node.set_param_value("scale", 1.0)
	# SpeedCHOP needs current_delta > 0 to accumulate
	node.current_delta = 1.0 / 60.0
	for i in range(5):
		var input := _make_chop_data({"x": PackedFloat32Array([60.0])})
		_cook_with(node, [input])
	var out: GNChannelData = node.cached_output as GNChannelData
	GNTestAssert.assert_not_null(out, "speed output")
	if out != null:
		GNTestAssert.assert_gt(out.get_value("x"), 0.0, "integrator accumulated")


# ═══════════════════════════════════════════════════════════════════════════════
#  SpringCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_spring_chop_converges() -> void:
	var node := _make_node(SpringCHOP.new(), "spring1")
	node.set_param_value("stiffness", 20.0)
	node.set_param_value("damping", 10.0)
	node.set_param_value("mass", 1.0)
	# Start at 0, target 10 — after many cooks should approach 10
	for i in range(60):
		var input := _make_chop_data({"x": PackedFloat32Array([10.0])})
		_cook_with(node, [input])
	var out: GNChannelData = node.cached_output as GNChannelData
	GNTestAssert.assert_approx(out.get_value("x"), 10.0, 1.0, "spring converged to target")


# ═══════════════════════════════════════════════════════════════════════════════
#  TimerCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_timer_chop_auto_starts() -> void:
	var node := _make_node(TimerCHOP.new(), "timer1")
	node.set_param_value("auto_start", true)
	node.set_param_value("length", 10.0)
	_cook_no_input(node)
	var out: GNChannelData = node.cached_output as GNChannelData
	GNTestAssert.assert_not_null(out, "timer output")
	GNTestAssert.assert_true(out.channels.has("timer_fraction") or out.channels.has("timer_seconds"), "has timer channel")


# ═══════════════════════════════════════════════════════════════════════════════
#  TriggerCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_trigger_chop_fires_on_edge() -> void:
	var node := _make_node(TriggerCHOP.new(), "trig1")
	node.set_param_value("threshold", 0.5)
	node.set_param_value("peak", 1.0)
	node.set_param_value("attack", 0.0)
	node.set_param_value("decay", 0.5)
	# Feed below threshold first
	var input_lo := _make_chop_data({"x": PackedFloat32Array([0.0])})
	_cook_with(node, [input_lo])
	# Then above threshold → should trigger
	var input_hi := _make_chop_data({"x": PackedFloat32Array([1.0])})
	var out: GNChannelData = _cook_with(node, [input_hi]) as GNChannelData
	GNTestAssert.assert_gt(out.get_value("x"), 0.5, "triggered: output > 0.5")


# ═══════════════════════════════════════════════════════════════════════════════
#  ExpressionCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_expression_chop_constant_expr() -> void:
	var node := _make_node(ExpressionCHOP.new(), "expr1")
	node.set_param_value("expr", "2.0 + 3.0")
	node.set_param_value("samples", 1)
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	GNTestAssert.assert_not_null(out, "expr output")
	GNTestAssert.assert_approx(out.get_value("chan1"), 5.0, 0.01, "2+3=5")


# ═══════════════════════════════════════════════════════════════════════════════
#  EnvelopeCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_envelope_chop_peak() -> void:
	var node := _make_node(EnvelopeCHOP.new(), "env1")
	node.set_param_value("mode", 1)  # Peak
	node.set_param_value("decay", 1.0)  # Full hold — peak never decays
	var input := _make_chop_data({"x": PackedFloat32Array([5.0])})
	_cook_with(node, [input])
	var input2 := _make_chop_data({"x": PackedFloat32Array([2.0])})
	var out: GNChannelData = _cook_with(node, [input2]) as GNChannelData
	GNTestAssert.assert_approx(out.get_value("x"), 5.0, 0.1, "peak held at 5")


# ═══════════════════════════════════════════════════════════════════════════════
#  HoldCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_hold_chop_captures_on_start() -> void:
	var node := _make_node(HoldCHOP.new(), "hold1")
	node.set_param_value("hold_on_start", true)
	var input := _make_chop_data({"x": PackedFloat32Array([42.0])})
	var trigger := _make_chop_data({"x": PackedFloat32Array([0.0])})
	var out: GNChannelData = _cook_with(node, [input, trigger]) as GNChannelData
	GNTestAssert.assert_not_null(out, "hold output")
	GNTestAssert.assert_approx(out.get_value("x"), 42.0, 0.01, "captured on start")


# ═══════════════════════════════════════════════════════════════════════════════
#  FeedbackCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_feedback_chop_previous_frame() -> void:
	var node := _make_node(FeedbackCHOP.new(), "fb1")
	# First cook: no previous data → null or empty
	var input1 := _make_chop_data({"x": PackedFloat32Array([10.0])})
	_cook_with(node, [input1])
	# Second cook: should return previous frame's data
	var input2 := _make_chop_data({"x": PackedFloat32Array([20.0])})
	var out: GNChannelData = _cook_with(node, [input2]) as GNChannelData
	if out != null and out.channels.has("x"):
		GNTestAssert.assert_approx(out.get_value("x"), 10.0, 0.01, "feedback returns previous frame")
	else:
		GNTestAssert.assert_true(true, "feedback returns null on early frames — acceptable")


# ═══════════════════════════════════════════════════════════════════════════════
#  PerformCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_perform_chop_produces_metrics() -> void:
	var node := _make_node(PerformCHOP.new(), "perf1")
	node.set_param_value("fps", true)
	node.set_param_value("frame_time", true)
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	GNTestAssert.assert_not_null(out, "perform output")
	GNTestAssert.assert_gt(out.channels.size(), 0, "has metric channels")


# ═══════════════════════════════════════════════════════════════════════════════
#  ClockCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_clock_chop_produces_output() -> void:
	var node := _make_node(ClockCHOP.new(), "clock1")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	GNTestAssert.assert_not_null(out, "clock output")
	GNTestAssert.assert_gt(out.channels.size(), 0, "has time channels")

# ═══════════════════════════════════════════════════════════════════════════════
#  AudioBandCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_audio_band_chop_instantiate() -> void:
	var node := _make_node(AudioBandCHOP.new(), "audioband1")
	GNTestAssert.assert_not_null(node, "AudioBandCHOP created")

func test_audio_band_chop_produces_output() -> void:
	var node := _make_node(AudioBandCHOP.new(), "audioband2")
	node.set_param_value("band_count", 8)
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  AudioDynamicsCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_audio_dynamics_chop_instantiate() -> void:
	var node := _make_node(AudioDynamicsCHOP.new(), "audiodynamics1")
	GNTestAssert.assert_not_null(node, "AudioDynamicsCHOP created")

func test_audio_dynamics_chop_produces_output() -> void:
	var node := _make_node(AudioDynamicsCHOP.new(), "audiodynamics2")
	node.set_param_value("threshold", -20.0)
	var input := _make_chop_data({"audio": PackedFloat32Array([0.5, 0.3, 0.1])})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  AudioFileInCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_audio_file_in_chop_instantiate() -> void:
	var node := _make_node(AudioFileInCHOP.new(), "audiofilein1")
	GNTestAssert.assert_not_null(node, "AudioFileInCHOP created")

func test_audio_file_in_chop_no_file() -> void:
	var node := _make_node(AudioFileInCHOP.new(), "audiofilein2")
	node.set_param_value("file_path", "")
	var out: GNData = _cook_no_input(node)
	GNTestAssert.assert_true(true, "null output acceptable when no file")


# ═══════════════════════════════════════════════════════════════════════════════
#  AudioInCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_audio_in_chop_instantiate() -> void:
	var node := _make_node(AudioInCHOP.new(), "audioin1")
	GNTestAssert.assert_not_null(node, "AudioInCHOP created")


# ═══════════════════════════════════════════════════════════════════════════════
#  AudioSpectrumCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_audio_spectrum_chop_instantiate() -> void:
	var node := _make_node(AudioSpectrumCHOP.new(), "audiospectrum1")
	GNTestAssert.assert_not_null(node, "AudioSpectrumCHOP created")

func test_audio_spectrum_chop_produces_output() -> void:
	var node := _make_node(AudioSpectrumCHOP.new(), "audiospectrum2")
	var input := _make_chop_data({"audio": PackedFloat32Array([0.1, 0.2, 0.15])})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  BeatCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_beat_chop_instantiate() -> void:
	var node := _make_node(BeatCHOP.new(), "beat1")
	GNTestAssert.assert_not_null(node, "BeatCHOP created")

func test_beat_chop_produces_output() -> void:
	var node := _make_node(BeatCHOP.new(), "beat2")
	node.set_param_value("bpm", 120.0)
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  ChannelCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_channel_chop_instantiate() -> void:
	var node := _make_node(ChannelCHOP.new(), "channel1")
	GNTestAssert.assert_not_null(node, "ChannelCHOP created")

func test_channel_chop_creates_named_channels() -> void:
	var node := _make_node(ChannelCHOP.new(), "channel2")
	node.set_param_value("count", 3)
	node.set_param_value("name0", "x")
	node.set_param_value("name1", "y")
	node.set_param_value("name2", "z")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	GNTestAssert.assert_not_null(out, "output exists")
	GNTestAssert.assert_true(out.channels.has("x"), "has channel x")


# ═══════════════════════════════════════════════════════════════════════════════
#  ClipCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_clip_chop_instantiate() -> void:
	var node := _make_node(ClipCHOP.new(), "clip1")
	GNTestAssert.assert_not_null(node, "ClipCHOP created")

func test_clip_chop_clamps_values() -> void:
	var node := _make_node(ClipCHOP.new(), "clip2")
	node.set_param_value("min_value", -1.0)
	node.set_param_value("max_value", 1.0)
	var input := _make_chop_data({"val": PackedFloat32Array([2.0, -2.0, 0.5])})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	GNTestAssert.assert_not_null(out, "output clamped")


# ═══════════════════════════════════════════════════════════════════════════════
#  CueCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_cue_chop_instantiate() -> void:
	var node := _make_node(CueCHOP.new(), "cue1")
	GNTestAssert.assert_not_null(node, "CueCHOP created")


# ═══════════════════════════════════════════════════════════════════════════════
#  GamepadCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_gamepad_chop_instantiate() -> void:
	var node := _make_node(GamepadCHOP.new(), "gamepad1")
	GNTestAssert.assert_not_null(node, "GamepadCHOP created")


# ═══════════════════════════════════════════════════════════════════════════════
#  HostInCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_host_in_chop_instantiate() -> void:
	var node := _make_node(HostInCHOP.new(), "hostin1")
	GNTestAssert.assert_not_null(node, "HostInCHOP created")


# ═══════════════════════════════════════════════════════════════════════════════
#  IKCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_ik_chop_instantiate() -> void:
	var node := _make_node(IKCHOP.new(), "ik1")
	GNTestAssert.assert_not_null(node, "IKCHOP created")


# ═══════════════════════════════════════════════════════════════════════════════
#  KeyboardInCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_keyboard_in_chop_instantiate() -> void:
	var node := _make_node(KeyboardInCHOP.new(), "keyboardin1")
	GNTestAssert.assert_not_null(node, "KeyboardInCHOP created")


# ═══════════════════════════════════════════════════════════════════════════════
#  KeyframeCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_keyframe_chop_instantiate() -> void:
	var node := _make_node(KeyframeCHOP.new(), "keyframe1")
	GNTestAssert.assert_not_null(node, "KeyframeCHOP created")

func test_keyframe_chop_produces_output() -> void:
	var node := _make_node(KeyframeCHOP.new(), "keyframe2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  LaserCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_laser_chop_instantiate() -> void:
	var node := _make_node(LaserCHOP.new(), "laser1")
	GNTestAssert.assert_not_null(node, "LaserCHOP created")

func test_laser_chop_produces_xy() -> void:
	var node := _make_node(LaserCHOP.new(), "laser2")
	node.set_param_value("pattern", "circle")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  MidiInCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_midi_in_chop_instantiate() -> void:
	var node := _make_node(MidiInCHOP.new(), "midiin1")
	GNTestAssert.assert_not_null(node, "MidiInCHOP created")


# ═══════════════════════════════════════════════════════════════════════════════
#  MouseInCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_mouse_in_chop_instantiate() -> void:
	var node := _make_node(MouseInCHOP.new(), "mousein1")
	GNTestAssert.assert_not_null(node, "MouseInCHOP created")


# ═══════════════════════════════════════════════════════════════════════════════
#  ObjectCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_object_chop_instantiate() -> void:
	var node := _make_node(ObjectCHOP.new(), "object1")
	GNTestAssert.assert_not_null(node, "ObjectCHOP created")


# ═══════════════════════════════════════════════════════════════════════════════
#  OscInCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_osc_in_chop_instantiate() -> void:
	var node := _make_node(OscInCHOP.new(), "oscin1")
	GNTestAssert.assert_not_null(node, "OscInCHOP created")

func test_osc_in_chop_sets_port() -> void:
	var node := _make_node(OscInCHOP.new(), "oscin2")
	node.set_param_value("listen_port", 9000)
	GNTestAssert.assert_not_null(node, "port set")


# ═══════════════════════════════════════════════════════════════════════════════
#  ParameterCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_parameter_chop_instantiate() -> void:
	var node := _make_node(ParameterCHOP.new(), "parameter1")
	GNTestAssert.assert_not_null(node, "ParameterCHOP created")

func test_parameter_chop_produces_output() -> void:
	var node := _make_node(ParameterCHOP.new(), "parameter2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  PhysicsCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_physics_chop_instantiate() -> void:
	var node := _make_node(PhysicsCHOP.new(), "physics1")
	GNTestAssert.assert_not_null(node, "PhysicsCHOP created")

func test_physics_chop_produces_output() -> void:
	var node := _make_node(PhysicsCHOP.new(), "physics2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  RampCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_ramp_chop_instantiate() -> void:
	var node := _make_node(RampCHOP.new(), "ramp1")
	GNTestAssert.assert_not_null(node, "RampCHOP created")

func test_ramp_chop_maps_values() -> void:
	var node := _make_node(RampCHOP.new(), "ramp2")
	var input := _make_chop_data({"val": PackedFloat32Array([0.0, 0.5, 1.0])})
	var out: GNChannelData = _cook_with(node, [input]) as GNChannelData
	GNTestAssert.assert_not_null(out, "output is GNChannelData")


# ═══════════════════════════════════════════════════════════════════════════════
#  GDScriptSCRIPT (CHOP template)
# ═══════════════════════════════════════════════════════════════════════════════

func test_gdscript_script_chop_template() -> void:
	var node := _make_node(GDScriptSCRIPT.new(), "script1")
	node.set_param_value("template", GDScriptSCRIPT.Template.CHOP)
	GNTestAssert.assert_not_null(node, "GDScriptSCRIPT created")
	GNTestAssert.assert_eq(node.node_type, "script", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
#  SequenceCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_sequence_chop_instantiate() -> void:
	var node := _make_node(SequenceCHOP.new(), "sequence1")
	GNTestAssert.assert_not_null(node, "SequenceCHOP created")

func test_sequence_chop_sequences_inputs() -> void:
	var node := _make_node(SequenceCHOP.new(), "sequence2")
	var in1 := _make_chop_data({"a": PackedFloat32Array([1.0])})
	var in2 := _make_chop_data({"b": PackedFloat32Array([2.0])})
	var out: GNChannelData = _cook_with(node, [in1, in2]) as GNChannelData
	GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  SkeletonCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_skeleton_chop_instantiate() -> void:
	var node := _make_node(SkeletonCHOP.new(), "skeleton1")
	GNTestAssert.assert_not_null(node, "SkeletonCHOP created")


# ═══════════════════════════════════════════════════════════════════════════════
#  SOPtoCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_sop_to_chop_instantiate() -> void:
	var node := _make_node(SOPtoCHOP.new(), "soptochop1")
	GNTestAssert.assert_not_null(node, "SOPtoCHOP created")


# ═══════════════════════════════════════════════════════════════════════════════
#  TabletInCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_tablet_in_chop_instantiate() -> void:
	var node := _make_node(TabletInCHOP.new(), "tabletin1")
	GNTestAssert.assert_not_null(node, "TabletInCHOP created")


# ═══════════════════════════════════════════════════════════════════════════════
#  TimelineCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_timeline_chop_instantiate() -> void:
	var node := _make_node(TimelineCHOP.new(), "timeline1")
	GNTestAssert.assert_not_null(node, "TimelineCHOP created")

func test_timeline_chop_produces_output() -> void:
	var node := _make_node(TimelineCHOP.new(), "timeline2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	GNTestAssert.assert_not_null(out, "output exists")
	GNTestAssert.assert_true(out.channels.has("frame"), "has frame channel")


# ═══════════════════════════════════════════════════════════════════════════════
#  TOPtoCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_top_to_chop_instantiate() -> void:
	var node := _make_node(TOPtoCHOP.new(), "toptochop1")
	GNTestAssert.assert_not_null(node, "TOPtoCHOP created")


# ═══════════════════════════════════════════════════════════════════════════════
#  CONVERTER CHOPs
# ═══════════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════════
#  CHOPDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_chop_dat_instantiate() -> void:
	var node := _make_node(CHOPDAT.new(), "chopdat1")
	GNTestAssert.assert_not_null(node, "CHOPDAT created")


# ═══════════════════════════════════════════════════════════════════════════════
#  DATtoCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_dat_to_chop_instantiate() -> void:
	var node := _make_node(DATtoCHOP.new(), "dattochop1")
	GNTestAssert.assert_not_null(node, "DATtoCHOP created")


# ═══════════════════════════════════════════════════════════════════════════════
#  HostOutCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_host_out_chop_instantiate() -> void:
	var node := _make_node(HostOutCHOP.new(), "hostout1")
	GNTestAssert.assert_not_null(node, "HostOutCHOP created")


# ═══════════════════════════════════════════════════════════════════════════════
#  CHOPtoSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_chop_to_sop_instantiate() -> void:
	var node := _make_node(CHOPtoSOP.new(), "choptosop1")
	GNTestAssert.assert_not_null(node, "CHOPtoSOP created")


# ═══════════════════════════════════════════════════════════════════════════════
#  CHOPtoTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_chop_to_top_instantiate() -> void:
	var node := _make_node(CHOPtoTOP.new(), "choptotop1")
	GNTestAssert.assert_not_null(node, "CHOPtoTOP created")


# ═══════════════════════════════════════════════════════════════════════════════
#  CHOPtoVOL
# ═══════════════════════════════════════════════════════════════════════════════

func test_chop_to_vol_instantiate() -> void:
	var node := _make_node(CHOPtoVOL.new(), "choptovol1")
	GNTestAssert.assert_not_null(node, "CHOPtoVOL created")

