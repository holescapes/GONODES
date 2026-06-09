class_name AudioSpectrumCHOP
extends GNChopBase
## FFT spectrum analysis of an audio bus, output as CHOP channels.
##
## Uses Godot's built-in AudioEffectSpectrumAnalyzer to get frequency magnitude data.
## Wire an AudioInCHOP into the input to automatically route spectrum analysis to
## that node's capture bus.  When no wire is connected, the 'bus' parameter is
## used instead (defaults to "Master" for full game audio).
##
## Output channels:
##   band:0 .. band:N  — magnitude of each frequency band (0-1)
##   bass, mid, treble  — convenience aggregate channels
##
## Band count and frequency range are configurable.

# ─── Audio infrastructure ──────────────────────────────────────────────────────

var _spectrum_effect: AudioEffectSpectrumAnalyzer = null
var _spectrum_instance: AudioEffectSpectrumAnalyzerInstance = null
var _bus_name: String = "Master"
var _bus_idx: int = -1
var _effect_idx: int = -1
var _setup_done: bool = false


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "audio_spectrum"
	time_dependent = true


func _init_ports() -> void:
	add_input("audio_in", GNFamily.Type.CHOP, false, "AudioInCHOP connection — auto-routes analysis to its capture bus", "Audio In")
	add_output("out", GNFamily.Type.CHOP, "Frequency band magnitudes")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("bus", "Master", "Bus",
		"Audio bus name to analyze (e.g. 'Master')"))
	add_parameter(GNParameter.create_bool("active", true, "Active",
		"Enable/disable spectrum analysis"))
	add_parameter(GNParameter.create_int("bands", 16, 2, 128, "Bands",
		"Number of frequency bands"))
	add_parameter(GNParameter.create_float("freq_min", 20.0, 1.0, 1000.0, 1.0, "Min Hz",
		"Lowest frequency to analyze"))
	add_parameter(GNParameter.create_float("freq_max", 20000.0, 100.0, 24000.0, 100.0, "Max Hz",
		"Highest frequency to analyze"))
	add_parameter(GNParameter.create_float("smoothing", 0.8, 0.0, 0.99, 0.01, "Smoothing",
		"Temporal smoothing (0 = none, 0.99 = very smooth)"))
	add_parameter(GNParameter.create_enum("fft_size",
		PackedStringArray(["256", "512", "1024", "2048", "4096"]),
		2, "FFT Size", "FFT window size (larger = better frequency resolution, more latency)"))


## Cached smoothed band values.
var _smoothed: PackedFloat32Array = PackedFloat32Array()


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(inputs: Array[GNData]) -> GNData:
	var active: bool = get_param_value("active")
	# If an AudioInCHOP is wired in, use its dedicated capture bus; else fall back to parameter.
	var wired: GNChannelData = inputs[0] as GNChannelData if inputs.size() > 0 else null
	var bus: String = wired.source_bus if (wired != null and not wired.source_bus.is_empty()) else get_param_value("bus")
	var band_count: int = get_param_value("bands")
	var freq_min: float = get_param_value("freq_min")
	var freq_max: float = get_param_value("freq_max")
	var smooth: float = get_param_value("smoothing")
	var fft_idx: int = get_param_value("fft_size")

	if active:
		_ensure_spectrum(bus, fft_idx)
	else:
		_remove_spectrum()

	var out: GNChannelData = _prepare_output(60.0)

	# Resize smoothed buffer
	if _smoothed.size() != band_count:
		_smoothed.resize(band_count)
		_smoothed.fill(0.0)

	if _spectrum_instance == null:
		# Output zeros
		for i in range(band_count):
			out.set_single_value("band:%d" % i, 0.0)
		out.set_single_value("bass", 0.0)
		out.set_single_value("mid", 0.0)
		out.set_single_value("treble", 0.0)
		return out

	# Logarithmic frequency distribution (perceptually uniform)
	var log_min: float = log(maxf(freq_min, 1.0))
	var log_max: float = log(maxf(freq_max, freq_min + 1.0))
	var log_step: float = (log_max - log_min) / float(band_count)

	var bass_sum: float = 0.0
	var mid_sum: float = 0.0
	var treble_sum: float = 0.0
	var bass_count: int = 0
	var mid_count: int = 0
	var treble_count: int = 0

	for i in range(band_count):
		var f_low: float = exp(log_min + log_step * float(i))
		var f_high: float = exp(log_min + log_step * float(i + 1))

		var mag: Vector2 = _spectrum_instance.get_magnitude_for_frequency_range(
			f_low, f_high,
			AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE)

		# Convert to scalar magnitude (average of L+R), then to dB-ish scale
		var linear: float = (mag.x + mag.y) * 0.5
		# Simple perceptual scaling: sqrt gives a nice 0-1 range for typical audio
		var value: float = clampf(sqrt(linear) * 2.0, 0.0, 1.0)

		# Temporal smoothing
		_smoothed[i] = lerpf(value, _smoothed[i], smooth)

		out.set_single_value("band:%d" % i, _smoothed[i])

		# Aggregate into bass/mid/treble
		var center_freq: float = (f_low + f_high) * 0.5
		if center_freq < 250.0:
			bass_sum += _smoothed[i]
			bass_count += 1
		elif center_freq < 4000.0:
			mid_sum += _smoothed[i]
			mid_count += 1
		else:
			treble_sum += _smoothed[i]
			treble_count += 1

	out.set_single_value("bass", bass_sum / maxf(float(bass_count), 1.0))
	out.set_single_value("mid", mid_sum / maxf(float(mid_count), 1.0))
	out.set_single_value("treble", treble_sum / maxf(float(treble_count), 1.0))

	return out


# ═══════════════════════════════════════════════════════════════════════════════
# Spectrum Analyzer Management
# ═══════════════════════════════════════════════════════════════════════════════

## Map FFT size enum index to AudioEffectSpectrumAnalyzer constant.
static var FFT_SIZES: Array[int] = [
	AudioEffectSpectrumAnalyzer.FFT_SIZE_256,
	AudioEffectSpectrumAnalyzer.FFT_SIZE_512,
	AudioEffectSpectrumAnalyzer.FFT_SIZE_1024,
	AudioEffectSpectrumAnalyzer.FFT_SIZE_2048,
	AudioEffectSpectrumAnalyzer.FFT_SIZE_4096,
]


func _ensure_spectrum(bus: String, fft_idx: int) -> void:
	# Find bus index by name
	var target_idx: int = -1
	for i in range(AudioServer.bus_count):
		if AudioServer.get_bus_name(i) == bus:
			target_idx = i
			break
	if target_idx < 0:
		if _setup_done:
			push_warning("AudioSpectrumCHOP: bus '%s' not found" % bus)
		_spectrum_instance = null
		return

	# Check if already set up on the correct bus
	if _setup_done and _bus_name == bus and _bus_idx == target_idx:
		return

	_remove_spectrum()

	_bus_name = bus
	_bus_idx = target_idx

	# Create and add the spectrum analyzer effect
	_spectrum_effect = AudioEffectSpectrumAnalyzer.new()
	_spectrum_effect.fft_size = FFT_SIZES[clampi(fft_idx, 0, FFT_SIZES.size() - 1)]
	_spectrum_effect.buffer_length = 0.5

	_effect_idx = AudioServer.get_bus_effect_count(_bus_idx)
	AudioServer.add_bus_effect(_bus_idx, _spectrum_effect)

	# Get the instance for reading magnitude data
	_spectrum_instance = AudioServer.get_bus_effect_instance(_bus_idx, _effect_idx)

	_setup_done = true
	GNLogger.info("AudioSpectrumCHOP", "Spectrum analyzer on bus '%s' (idx %d)" % [bus, _bus_idx])


func _remove_spectrum() -> void:
	if not _setup_done:
		return

	# Remove the effect we added (find our effect by checking the bus)
	if _bus_idx >= 0 and _bus_idx < AudioServer.bus_count and _effect_idx >= 0:
		if _effect_idx < AudioServer.get_bus_effect_count(_bus_idx):
			AudioServer.remove_bus_effect(_bus_idx, _effect_idx)

	_spectrum_effect = null
	_spectrum_instance = null
	_bus_idx = -1
	_effect_idx = -1
	_setup_done = false


## Clean up on node removal.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_remove_spectrum()
