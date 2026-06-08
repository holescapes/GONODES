class_name AudioParaEQCHOP
extends GNChopBase
## Multi-band parametric equalizer (up to 8 bands).
##
## Each band is a biquad peaking EQ filter with independent frequency,
## gain (dB), and Q controls. Bands are cascaded in series. Also provides
## a low shelf on band 1 and high shelf on band 8 when enabled.
##
## Standard audio production tool for sculpting frequency response.


func _init() -> void:
	node_type = "audioparaeq"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Audio input", "In")
	add_output("out", GNFamily.Type.CHOP, "Equalized audio output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("bands", 4, 1, 8,
		"Bands", "Number of active EQ bands"))
	# Per-band parameters (8 bands max)
	for b: int in range(8):
		var n: int = b + 1
		var prefix := "b%d_" % n
		add_parameter(GNParameter.create_float(prefix + "freq",
			_default_freq(b), 20.0, 20000.0, 1.0,
			"Band %d Freq" % n, "Center frequency for band %d" % n))
		add_parameter(GNParameter.create_float(prefix + "gain",
			0.0, -24.0, 24.0, 0.1,
			"Band %d Gain" % n, "Gain in dB for band %d" % n))
		add_parameter(GNParameter.create_float(prefix + "q",
			1.0, 0.1, 30.0, 0.01,
			"Band %d Q" % n, "Quality factor for band %d" % n))
	add_parameter(GNParameter.create_bool("low_shelf", false,
		"Low Shelf", "Use low shelf filter for band 1"))
	add_parameter(GNParameter.create_bool("high_shelf", false,
		"High Shelf", "Use high shelf filter for the last active band"))


# Per-channel, per-band biquad state: {ch_name: [[x1,x2,y1,y2], ...]}
var _state: Dictionary = {}
# Cached coefficients per band: [[b0,b1,b2,a1,a2], ...]
var _coeffs: Array = []
var _prev_hash: int = 0


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var sr: float = in_data.sample_rate if in_data.sample_rate > 0.0 else AudioServer.get_mix_rate()
	var out := _prepare_output(sr)
	var num_bands: int = get_param_value("bands")
	var use_low_shelf: bool = get_param_value("low_shelf")
	var use_high_shelf: bool = get_param_value("high_shelf")

	# Recompute coefficients if params changed
	var param_hash: int = _hash_params(num_bands, sr)
	if param_hash != _prev_hash or _coeffs.size() != num_bands:
		_coeffs.clear()
		for b: int in range(num_bands):
			var prefix := "b%d_" % (b + 1)
			var fc: float = get_param_value(prefix + "freq")
			var gain_db: float = get_param_value(prefix + "gain")
			var q: float = get_param_value(prefix + "q")
			var filter_type: int = 5  # Peaking
			if b == 0 and use_low_shelf:
				filter_type = 6  # Low shelf
			elif b == num_bands - 1 and use_high_shelf:
				filter_type = 7  # High shelf
			_coeffs.append(_biquad_coeffs(filter_type, fc, q, gain_db, sr))
		_prev_hash = param_hash

	for ch_name: String in in_data.get_channel_names():
		var samples: PackedFloat32Array = in_data.get_channel(ch_name)
		if samples.size() == 0:
			continue

		# Ensure per-channel state
		if not _state.has(ch_name) or (_state[ch_name] as Array).size() != num_bands:
			var band_states: Array = []
			for b: int in range(num_bands):
				band_states.append(PackedFloat64Array([0.0, 0.0, 0.0, 0.0]))
			_state[ch_name] = band_states

		var band_states: Array = _state[ch_name]
		var buf: PackedFloat32Array = samples

		# Cascade through bands
		for b: int in range(num_bands):
			var c: PackedFloat64Array = _coeffs[b]
			var st: PackedFloat64Array = band_states[b]
			var x1: float = st[0]
			var x2: float = st[1]
			var y1: float = st[2]
			var y2: float = st[3]

			var out_buf := PackedFloat32Array()
			out_buf.resize(buf.size())

			for i: int in range(buf.size()):
				var x0: float = buf[i]
				var y0: float = c[0] * x0 + c[1] * x1 + c[2] * x2 - c[3] * y1 - c[4] * y2
				out_buf[i] = y0
				x2 = x1
				x1 = x0
				y2 = y1
				y1 = y0

			st[0] = x1
			st[1] = x2
			st[2] = y1
			st[3] = y2
			band_states[b] = st
			buf = out_buf

		_state[ch_name] = band_states
		out.set_channel(ch_name, buf)

	return out


func _hash_params(num_bands: int, sr: float) -> int:
	var h: int = hash(num_bands) ^ hash(sr)
	for b: int in range(num_bands):
		var prefix := "b%d_" % (b + 1)
		h ^= hash(get_param_value(prefix + "freq"))
		h ^= hash(get_param_value(prefix + "gain"))
		h ^= hash(get_param_value(prefix + "q"))
	h ^= hash(get_param_value("low_shelf"))
	h ^= hash(get_param_value("high_shelf"))
	return h


static func _default_freq(band: int) -> float:
	var defaults := [80.0, 250.0, 800.0, 2500.0, 5000.0, 8000.0, 12000.0, 16000.0]
	return defaults[band] if band < defaults.size() else 1000.0


## Compute biquad coefficients. Types: 5=peaking, 6=lowshelf, 7=highshelf.
static func _biquad_coeffs(type: int, fc: float, q: float, gain_db: float, sr: float) -> PackedFloat64Array:
	var w0: float = TAU * fc / sr
	var cos_w0: float = cos(w0)
	var sin_w0: float = sin(w0)
	var alpha: float = sin_w0 / (2.0 * q)
	var a_lin: float = pow(10.0, gain_db / 40.0)

	var b0: float
	var b1: float
	var b2: float
	var a0: float
	var a1: float
	var a2: float

	if type == 5:  # Peaking
		b0 = 1.0 + alpha * a_lin
		b1 = -2.0 * cos_w0
		b2 = 1.0 - alpha * a_lin
		a0 = 1.0 + alpha / a_lin
		a1 = -2.0 * cos_w0
		a2 = 1.0 - alpha / a_lin
	elif type == 6:  # Low Shelf
		var sq_a: float = sqrt(a_lin)
		var tsa: float = 2.0 * sq_a * alpha
		b0 = a_lin * ((a_lin + 1.0) - (a_lin - 1.0) * cos_w0 + tsa)
		b1 = 2.0 * a_lin * ((a_lin - 1.0) - (a_lin + 1.0) * cos_w0)
		b2 = a_lin * ((a_lin + 1.0) - (a_lin - 1.0) * cos_w0 - tsa)
		a0 = (a_lin + 1.0) + (a_lin - 1.0) * cos_w0 + tsa
		a1 = -2.0 * ((a_lin - 1.0) + (a_lin + 1.0) * cos_w0)
		a2 = (a_lin + 1.0) + (a_lin - 1.0) * cos_w0 - tsa
	else:  # High Shelf
		var sq_a: float = sqrt(a_lin)
		var tsa: float = 2.0 * sq_a * alpha
		b0 = a_lin * ((a_lin + 1.0) + (a_lin - 1.0) * cos_w0 + tsa)
		b1 = -2.0 * a_lin * ((a_lin - 1.0) + (a_lin + 1.0) * cos_w0)
		b2 = a_lin * ((a_lin + 1.0) + (a_lin - 1.0) * cos_w0 - tsa)
		a0 = (a_lin + 1.0) - (a_lin - 1.0) * cos_w0 + tsa
		a1 = 2.0 * ((a_lin - 1.0) - (a_lin + 1.0) * cos_w0)
		a2 = (a_lin + 1.0) - (a_lin - 1.0) * cos_w0 - tsa

	return PackedFloat64Array([b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0])
