class_name AudioBandCHOPNative
extends GNChopBase
## Native-accelerated multi-band frequency analysis — delegates to GNNativeAudioBandChop (C++).

var _processor: RefCounted = null
var _envelopes: PackedFloat32Array = PackedFloat32Array()
var _peaks: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	node_type = "audio_band_native"
	time_dependent = true
	if ClassDB.class_exists("GNNativeAudioBandChop"):
		_processor = ClassDB.instantiate("GNNativeAudioBandChop")


func _init_ports() -> void:
	add_input("spectrum", GNFamily.Type.CHOP, false,
		"Spectrum CHOP input (AudioSpectrumCHOP band:N channels)")
	add_output("out", GNFamily.Type.CHOP, "Per-band level, peak, and normalized channels")


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

	# Parse crossover frequencies
	var crossovers := PackedFloat32Array()
	crossovers.append(freq_min)
	for s: String in cross_str.split(","):
		var v: float = s.strip_edges().to_float()
		if v > 0.0:
			crossovers.append(v)
	crossovers.append(freq_max)
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
	var input_bands := PackedFloat32Array()
	if spec_in != null:
		var idx: int = 0
		while spec_in.channels.has("band:%d" % idx):
			input_bands.append(spec_in.get_value("band:%d" % idx, -1))
			idx += 1

	# Compute smoothing coefficients
	var dt: float = maxf(current_delta, 1.0 / 60.0)
	var att_coeff: float = 1.0 - exp(-dt / maxf(attack_s, 0.001))
	var rel_coeff: float = 1.0 - exp(-dt / maxf(release_s, 0.01))

	if _processor:
		var result: Dictionary = _processor.process(input_bands, _envelopes, _peaks,
			crossovers, num_bands, gain_val, freq_min, freq_max,
			att_coeff, rel_coeff, peak_decay)

		# Update state from native result
		_envelopes = result["envelopes"]
		_peaks = result["peaks_out"]

		var levels: PackedFloat32Array = result["levels"]
		var peaks_arr: PackedFloat32Array = result["peaks_out"]
		var norms: PackedFloat32Array = result["norms"]

		for b in range(num_bands):
			var bname: String = band_names[b] if b < band_names.size() else "band_%d" % b
			out.set_single_value(bname, levels[b])
			out.set_single_value(bname + "_peak", peaks_arr[b])
			out.set_single_value(bname + "_norm", norms[b])

		out.set_single_value("total", result["total"])
		out.set_single_value("dominant_band", float(result["dominant"]))
	else:
		out.set_single_value("total", 0.0)
		out.set_single_value("dominant_band", 0.0)

	return out
