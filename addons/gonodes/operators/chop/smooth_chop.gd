class_name SmoothCHOP
extends GNChopBase
## Biquad IIR filter (Butterworth) for CHOP channels.
## Modes: Low-Pass, High-Pass, Band-Pass.
## Higher quality than single-pole FilterCHOP for musical / responsive smoothing.

var _x1: Dictionary = {}  # channel -> prev input[n-1]
var _x2: Dictionary = {}  # channel -> prev input[n-2]
var _y1: Dictionary = {}  # channel -> prev output[n-1]
var _y2: Dictionary = {}  # channel -> prev output[n-2]


func _init() -> void:
	node_type = "smooth"


func update_time_dependency() -> void:
	time_dependent = _temporal_moving


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels", "In")
	add_output("out", GNFamily.Type.CHOP, "Filtered channels", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("type",
		PackedStringArray(["Low Pass", "High Pass", "Band Pass"]), 0, "",
		"Filter type"))
	add_parameter(GNParameter.create_float("cutoff", 0.2, 0.001, 1.0, 0.001,
		"Cutoff (0-1)", "Normalised cutoff frequency"))
	add_parameter(GNParameter.create_float("q", 0.707, 0.1, 10.0, 0.01,
		"Q (Resonance)", "Quality factor (0.707 = Butterworth flat)"))
	add_parameter(GNParameter.create_bool("reset", false, "Reset", "Clear filter state"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var ftype: int = get_param_value("type")
	var cutoff: float = get_param_value("cutoff")
	var q_val: float = get_param_value("q")
	var do_reset: bool = get_param_value("reset")

	if do_reset:
		_x1.clear(); _x2.clear(); _y1.clear(); _y2.clear()
		_temporal_end_state.clear()

	var out: GNChannelData = _prepare_output(in_data.sample_rate)

	# Compute biquad coefficients (Butterworth)
	var omega: float = TAU * clampf(cutoff, 0.001, 0.499)
	var sin_w: float = sin(omega)
	var cos_w: float = cos(omega)
	var alpha: float = sin_w / (2.0 * q_val)

	var b0: float; var b1: float; var b2: float
	var a0: float; var a1: float; var a2: float

	match ftype:
		0:  # Low Pass
			b0 = (1.0 - cos_w) * 0.5
			b1 = 1.0 - cos_w
			b2 = (1.0 - cos_w) * 0.5
		1:  # High Pass
			b0 = (1.0 + cos_w) * 0.5
			b1 = -(1.0 + cos_w)
			b2 = (1.0 + cos_w) * 0.5
		_:  # Band Pass
			b0 = alpha
			b1 = 0.0
			b2 = -alpha

	a0 = 1.0 + alpha
	a1 = -2.0 * cos_w
	a2 = 1.0 - alpha

	# Normalise by a0
	b0 /= a0; b1 /= a0; b2 /= a0
	a1 /= a0; a2 /= a0

	for ch_name in in_data.channels:
		var samples: PackedFloat32Array = in_data.channels[ch_name]
		var result := PackedFloat32Array()
		result.resize(samples.size())

		var xn1: float = _x1.get(ch_name, 0.0)
		var xn2: float = _x2.get(ch_name, 0.0)
		var yn1: float = _y1.get(ch_name, 0.0)
		var yn2: float = _y2.get(ch_name, 0.0)

		for i in range(samples.size()):
			var x: float = samples[i]
			var y: float = b0 * x + b1 * xn1 + b2 * xn2 - a1 * yn1 - a2 * yn2
			result[i] = y
			xn2 = xn1; xn1 = x
			yn2 = yn1; yn1 = y

		_x1[ch_name] = xn1; _x2[ch_name] = xn2
		_y1[ch_name] = yn1; _y2[ch_name] = yn2
		out.set_channel(ch_name, result)

	var moved := false
	for ch_name in _y1:
		if _temporal_sample_moved(ch_name, float(_y1[ch_name])):
			moved = true
	_finish_temporal_cook(moved)
	return out
