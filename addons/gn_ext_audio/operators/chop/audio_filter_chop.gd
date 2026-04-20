class_name AudioFilterCHOP
extends GNChopBase
## Biquad IIR audio filter with multiple filter types.
##
## Implements standard biquad filter topologies: lowpass, highpass, bandpass,
## notch, allpass, peaking EQ, low shelf, high shelf. Processes all input
## channels at audio rate with configurable cutoff frequency and resonance.
##
## Uses Robert Bristow-Johnson's Audio EQ Cookbook formulas.


func _init() -> void:
	node_type = "audiofilter"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Audio input to filter")
	add_output("out", GNFamily.Type.CHOP, "Filtered audio output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("type",
		PackedStringArray(["Lowpass", "Highpass", "Bandpass", "Notch", "Allpass", "Peaking", "Low Shelf", "High Shelf"]), 0,
		"Filter Type", "Biquad filter topology"))
	add_parameter(GNParameter.create_float("cutoff", 1000.0, 20.0, 20000.0, 1.0,
		"Cutoff", "Filter cutoff/center frequency in Hz"))
	add_parameter(GNParameter.create_float("q", 0.707, 0.1, 30.0, 0.01,
		"Q / Resonance", "Filter quality factor (resonance)"))
	add_parameter(GNParameter.create_float("gain_db", 0.0, -24.0, 24.0, 0.1,
		"Gain (dB)", "Gain for peaking and shelf filter types"))

# Per-channel biquad state: {channel_name: [x1, x2, y1, y2]}
var _state: Dictionary = {}
# Cached coefficients
var _b0: float = 1.0
var _b1: float = 0.0
var _b2: float = 0.0
var _a1: float = 0.0
var _a2: float = 0.0
var _prev_type: int = -1
var _prev_cutoff: float = -1.0
var _prev_q: float = -1.0
var _prev_gain: float = -100.0
var _prev_sr: float = -1.0


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var sr: float = in_data.sample_rate if in_data.sample_rate > 0.0 else AudioServer.get_mix_rate()
	var out := _prepare_output(sr)

	var filter_type: int = get_param_value("type")
	var cutoff: float = get_param_value("cutoff")
	var q: float = get_param_value("q")
	var gain_db: float = get_param_value("gain_db")

	# Recompute coefficients only if parameters changed
	if filter_type != _prev_type or not is_equal_approx(cutoff, _prev_cutoff) or \
		not is_equal_approx(q, _prev_q) or not is_equal_approx(gain_db, _prev_gain) or \
		not is_equal_approx(sr, _prev_sr):
		_compute_coefficients(filter_type, cutoff, q, gain_db, sr)
		_prev_type = filter_type
		_prev_cutoff = cutoff
		_prev_q = q
		_prev_gain = gain_db
		_prev_sr = sr

	for ch_name: String in in_data.get_channel_names():
		var samples: PackedFloat32Array = in_data.get_channel(ch_name)
		if samples.size() == 0:
			continue

		# Get or create per-channel state
		if not _state.has(ch_name):
			_state[ch_name] = PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
		var st: PackedFloat64Array = _state[ch_name]
		var x1: float = st[0]
		var x2: float = st[1]
		var y1: float = st[2]
		var y2: float = st[3]

		var output := PackedFloat32Array()
		output.resize(samples.size())

		for i: int in range(samples.size()):
			var x0: float = samples[i]
			var y0: float = _b0 * x0 + _b1 * x1 + _b2 * x2 - _a1 * y1 - _a2 * y2
			output[i] = y0
			x2 = x1
			x1 = x0
			y2 = y1
			y1 = y0

		st[0] = x1
		st[1] = x2
		st[2] = y1
		st[3] = y2
		_state[ch_name] = st

		out.set_channel(ch_name, output)

	return out


## Compute biquad coefficients using Audio EQ Cookbook formulas.
func _compute_coefficients(type: int, fc: float, q: float, gain_db: float, sr: float) -> void:
	var w0: float = TAU * fc / sr
	var cos_w0: float = cos(w0)
	var sin_w0: float = sin(w0)
	var alpha: float = sin_w0 / (2.0 * q)
	var a_lin: float = pow(10.0, gain_db / 40.0)

	var b0: float = 0.0
	var b1: float = 0.0
	var b2: float = 0.0
	var a0: float = 1.0
	var a1: float = 0.0
	var a2: float = 0.0

	match type:
		0:  # Lowpass
			b0 = (1.0 - cos_w0) / 2.0
			b1 = 1.0 - cos_w0
			b2 = (1.0 - cos_w0) / 2.0
			a0 = 1.0 + alpha
			a1 = -2.0 * cos_w0
			a2 = 1.0 - alpha
		1:  # Highpass
			b0 = (1.0 + cos_w0) / 2.0
			b1 = -(1.0 + cos_w0)
			b2 = (1.0 + cos_w0) / 2.0
			a0 = 1.0 + alpha
			a1 = -2.0 * cos_w0
			a2 = 1.0 - alpha
		2:  # Bandpass
			b0 = alpha
			b1 = 0.0
			b2 = -alpha
			a0 = 1.0 + alpha
			a1 = -2.0 * cos_w0
			a2 = 1.0 - alpha
		3:  # Notch
			b0 = 1.0
			b1 = -2.0 * cos_w0
			b2 = 1.0
			a0 = 1.0 + alpha
			a1 = -2.0 * cos_w0
			a2 = 1.0 - alpha
		4:  # Allpass
			b0 = 1.0 - alpha
			b1 = -2.0 * cos_w0
			b2 = 1.0 + alpha
			a0 = 1.0 + alpha
			a1 = -2.0 * cos_w0
			a2 = 1.0 - alpha
		5:  # Peaking EQ
			b0 = 1.0 + alpha * a_lin
			b1 = -2.0 * cos_w0
			b2 = 1.0 - alpha * a_lin
			a0 = 1.0 + alpha / a_lin
			a1 = -2.0 * cos_w0
			a2 = 1.0 - alpha / a_lin
		6:  # Low Shelf
			var sq_a: float = sqrt(a_lin)
			var two_sq_a_alpha: float = 2.0 * sq_a * alpha
			b0 = a_lin * ((a_lin + 1.0) - (a_lin - 1.0) * cos_w0 + two_sq_a_alpha)
			b1 = 2.0 * a_lin * ((a_lin - 1.0) - (a_lin + 1.0) * cos_w0)
			b2 = a_lin * ((a_lin + 1.0) - (a_lin - 1.0) * cos_w0 - two_sq_a_alpha)
			a0 = (a_lin + 1.0) + (a_lin - 1.0) * cos_w0 + two_sq_a_alpha
			a1 = -2.0 * ((a_lin - 1.0) + (a_lin + 1.0) * cos_w0)
			a2 = (a_lin + 1.0) + (a_lin - 1.0) * cos_w0 - two_sq_a_alpha
		7:  # High Shelf
			var sq_a: float = sqrt(a_lin)
			var two_sq_a_alpha: float = 2.0 * sq_a * alpha
			b0 = a_lin * ((a_lin + 1.0) + (a_lin - 1.0) * cos_w0 + two_sq_a_alpha)
			b1 = -2.0 * a_lin * ((a_lin - 1.0) + (a_lin + 1.0) * cos_w0)
			b2 = a_lin * ((a_lin + 1.0) + (a_lin - 1.0) * cos_w0 - two_sq_a_alpha)
			a0 = (a_lin + 1.0) - (a_lin - 1.0) * cos_w0 + two_sq_a_alpha
			a1 = 2.0 * ((a_lin - 1.0) - (a_lin + 1.0) * cos_w0)
			a2 = (a_lin + 1.0) - (a_lin - 1.0) * cos_w0 - two_sq_a_alpha

	# Normalize
	_b0 = b0 / a0
	_b1 = b1 / a0
	_b2 = b2 / a0
	_a1 = a1 / a0
	_a2 = a2 / a0
