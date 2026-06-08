class_name AudioBandCHOP
extends GNChopBase
## Multi-band frequency analysis with per-band envelope followers.
##
## Takes an AudioSpectrumCHOP (or any CHOP with band:N channels) as input
## and groups frequency bands into configurable ranges (default: bass, low-mid,
## mid, high-mid, treble).  Each band gets an envelope follower with
## attack/release smoothing — essential for music-reactive VJ visuals.
##
## Output channels per band:
##   {name}        — smoothed band level (0–1)
##   {name}_peak   — peak-hold level (decays slowly)
##   {name}_norm   — level normalized against recent peak (auto-gain)
##
## Also outputs:
##   total         — overall combined energy
##   dominant_band — index of the loudest band (float)

var _envelopes: PackedFloat32Array = PackedFloat32Array()
var _peaks: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	node_type = "audio_band"
	time_dependent = true


func _init_ports() -> void:
	add_input("spectrum", GNFamily.Type.CHOP, false,
		"Spectrum CHOP input (AudioSpectrumCHOP band:N channels)", "Spectrum")
	add_output("out", GNFamily.Type.CHOP, "Per-band level, peak, and normalized channels", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("num_bands", 5, 1, 16,
		"Bands", "Number of output frequency bands"))
	add_parameter(GNParameter.create_string("band_names",
		"bass,low_mid,mid,high_mid,treble",
		"Names", "Comma-separated band names"))
	add_parameter(GNParameter.create_string("crossovers",
		"80,250,2000,6000",
		"Crossovers (Hz)", "Comma-separated crossover frequencies between bands"))
	add_parameter(GNParameter.create_float("attack", 0.02, 0.001, 1.0, 0.001,
		"Attack (s)", "Envelope attack time in seconds"))
	add_parameter(GNParameter.create_float("release", 0.15, 0.01, 2.0, 0.01,
		"Release (s)", "Envelope release time in seconds"))
	add_parameter(GNParameter.create_float("peak_decay", 0.98, 0.9, 0.999, 0.001,
		"Peak Decay", "Per-frame peak hold decay (higher = slower falloff)"))
	add_parameter(GNParameter.create_float("gain", 1.0, 0.1, 10.0, 0.1,
		"Gain", "Overall input gain multiplier"))
	add_parameter(GNParameter.create_float("freq_min", 20.0, 1.0, 1000.0, 1.0,
		"Min Hz", "Assumed lowest frequency of input spectrum"))
	add_parameter(GNParameter.create_float("freq_max", 20000.0, 100.0, 24000.0, 100.0,
		"Max Hz", "Assumed highest frequency of input spectrum"))


func _cook(inputs: Array[GNData]) -> GNData:
	var num_bands: int = get_param_value("num_bands")
	var names_str: String = get_param_value("band_names")
	var cross_str: String = get_param_value("crossovers")
	var attack_s: float = get_param_value("attack")
	var release_s: float = get_param_value("release")
	var peak_decay: float = get_param_value("peak_decay")
	var gain_val: float = get_param_value("gain")
	var freq_min: float = get_param_value("freq_min")
	var freq_max: float = get_param_value("freq_max")

	var out: GNChannelData = _prepare_output(60.0)

	# Parse band names
	var band_names: PackedStringArray = names_str.split(",")
	while band_names.size() < num_bands:
		band_names.append("band_%d" % band_names.size())

	# Parse crossover frequencies — define the edges between bands
	var crossovers: Array[float] = []
	crossovers.append(freq_min)
	for s: String in cross_str.split(","):
		var v: float = s.strip_edges().to_float()
		if v > 0.0:
			crossovers.append(v)
	crossovers.append(freq_max)
	# Ensure we have num_bands + 1 edges
	while crossovers.size() < num_bands + 1:
		crossovers.append(freq_max)

	# Resize envelope/peak arrays
	if _envelopes.size() != num_bands:
		_envelopes.resize(num_bands)
		_envelopes.fill(0.0)
		_peaks.resize(num_bands)
		_peaks.fill(0.0)

	# Read input spectrum bands
	var spec_in: GNChannelData = _get_input_chop(inputs, 0)
	var input_bands: Array[float] = []
	var input_count: int = 0
	if spec_in != null:
		# Collect all band:N channels in order
		var idx: int = 0
		while spec_in.channels.has("band:%d" % idx):
			input_bands.append(spec_in.get_value("band:%d" % idx, -1))
			idx += 1
		input_count = input_bands.size()

	# Map input bands to output bands based on frequency crossovers
	var raw_levels: PackedFloat32Array = PackedFloat32Array()
	raw_levels.resize(num_bands)
	raw_levels.fill(0.0)

	if input_count > 0:
		# Map each input band to its frequency and accumulate into output bands
		var log_min: float = log(maxf(freq_min, 1.0))
		var log_max: float = log(maxf(freq_max, freq_min + 1.0))

		for i in range(input_count):
			# Compute center frequency of this input band (log-distributed)
			var t: float = (float(i) + 0.5) / float(input_count)
			var center_freq: float = exp(log_min + t * (log_max - log_min))

			# Find which output band this belongs to
			for b in range(num_bands):
				var lo: float = crossovers[b] if b < crossovers.size() else freq_min
				var hi: float = crossovers[b + 1] if (b + 1) < crossovers.size() else freq_max
				if center_freq >= lo and center_freq < hi:
					raw_levels[b] += input_bands[i]
					break

		# Normalize by number of input bands per output band (approximate)
		for b in range(num_bands):
			raw_levels[b] = clampf(raw_levels[b] * gain_val, 0.0, 1.0)

	# Apply envelope followers (attack/release) and peak hold
	var dt: float = maxf(current_delta, 1.0 / 60.0)
	var att_coeff: float = 1.0 - exp(-dt / maxf(attack_s, 0.001))
	var rel_coeff: float = 1.0 - exp(-dt / maxf(release_s, 0.01))

	var total_energy: float = 0.0
	var max_level: float = 0.0
	var dominant: int = 0

	for b in range(num_bands):
		var raw: float = raw_levels[b]

		# Envelope follower
		if raw > _envelopes[b]:
			_envelopes[b] = lerpf(_envelopes[b], raw, att_coeff)
		else:
			_envelopes[b] = lerpf(_envelopes[b], raw, rel_coeff)

		# Peak hold with decay
		if _envelopes[b] > _peaks[b]:
			_peaks[b] = _envelopes[b]
		else:
			_peaks[b] *= peak_decay

		# Normalized (auto-gain against recent peak)
		var norm: float = _envelopes[b] / maxf(_peaks[b], 0.001)

		var name: String = band_names[b] if b < band_names.size() else "band_%d" % b
		out.set_single_value(name, _envelopes[b])
		out.set_single_value(name + "_peak", _peaks[b])
		out.set_single_value(name + "_norm", clampf(norm, 0.0, 1.0))

		total_energy += _envelopes[b]
		if _envelopes[b] > max_level:
			max_level = _envelopes[b]
			dominant = b

	out.set_single_value("total", clampf(total_energy / maxf(float(num_bands), 1.0), 0.0, 1.0))
	out.set_single_value("dominant_band", float(dominant))

	return out
