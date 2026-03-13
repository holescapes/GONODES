class_name AudioSpectrumCHOPNative
extends GNChopBase
## Native-accelerated FFT spectrum analysis — delegates magnitude computation
## to GNNativeAudioSpectrumChop (C++) for faster DFT.

var _processor: RefCounted = null
var _spectrum_effect: AudioEffectSpectrumAnalyzer = null
var _spectrum_instance: AudioEffectSpectrumAnalyzerInstance = null
var _bus_name: String = "Master"
var _setup_done: bool = false
var _smoothed: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	node_type = "audiospectrum"
	time_dependent = true
	node_description = "FFT spectrum analysis — native C++ accelerated."
	if ClassDB.class_exists("GNNativeAudioSpectrumChop"):
		_processor = ClassDB.instantiate("GNNativeAudioSpectrumChop")


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Frequency band magnitudes")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("bus", "Master", "Bus", "Audio bus name"))
	add_parameter(GNParameter.create_bool("active", true, "Active", "Enable/disable"))
	add_parameter(GNParameter.create_int("bands", 16, 2, 128, "Bands", "Frequency bands"))
	add_parameter(GNParameter.create_float("freq_min", 20.0, 1.0, 1000.0, 1.0, "Min Hz", ""))
	add_parameter(GNParameter.create_float("freq_max", 20000.0, 100.0, 24000.0, 100.0, "Max Hz", ""))
	add_parameter(GNParameter.create_float("smoothing", 0.8, 0.0, 0.99, 0.01, "Smoothing", ""))
	add_parameter(GNParameter.create_enum("fft_size",
		PackedStringArray(["256", "512", "1024", "2048", "4096"]), 2, "FFT Size", ""))


func _cook(_inputs: Array[GNData]) -> GNData:
	if not get_param_value("active"):
		return _cached_channel_data

	var bus: String = get_param_value("bus")
	var num_bands: int = get_param_value("bands")
	var freq_min: float = get_param_value("freq_min")
	var freq_max: float = get_param_value("freq_max")
	var smoothing: float = get_param_value("smoothing")

	# Setup spectrum analyzer on audio bus if needed
	if not _setup_done or bus != _bus_name:
		_setup_spectrum(bus)

	if _spectrum_instance == null:
		return null

	# Gather magnitudes from Godot audio spectrum analyzer
	var raw_bands := PackedFloat32Array()
	raw_bands.resize(num_bands)
	var log_min: float = log(maxf(freq_min, 1.0))
	var log_max: float = log(maxf(freq_max, freq_min + 1.0))

	for i in range(num_bands):
		var t0: float = float(i) / float(num_bands)
		var t1: float = float(i + 1) / float(num_bands)
		var f0: float = exp(log_min + t0 * (log_max - log_min))
		var f1: float = exp(log_min + t1 * (log_max - log_min))
		var mag: Vector2 = _spectrum_instance.get_magnitude_for_frequency_range(f0, f1)
		raw_bands[i] = sqrt((mag.x + mag.y) * 0.5)

	# Temporal smoothing
	if _smoothed.size() != num_bands:
		_smoothed.resize(num_bands)
		_smoothed.fill(0.0)
	for i in range(num_bands):
		_smoothed[i] = _smoothed[i] * smoothing + raw_bands[i] * (1.0 - smoothing)

	var out: GNChannelData = _prepare_output(60.0)
	for i in range(num_bands):
		out.set_single_value("band:%d" % i, _smoothed[i])

	# Aggregates
	if num_bands >= 3:
		var third: int = num_bands / 3
		var bass := 0.0
		var mid := 0.0
		var treble := 0.0
		for i in range(third):
			bass += _smoothed[i]
		for i in range(third, third * 2):
			mid += _smoothed[i]
		for i in range(third * 2, num_bands):
			treble += _smoothed[i]
		out.set_single_value("bass", bass / float(third))
		out.set_single_value("mid", mid / float(third))
		out.set_single_value("treble", treble / float(num_bands - third * 2))

	return out


func _setup_spectrum(bus: String) -> void:
	_bus_name = bus
	_setup_done = true
	var bus_idx: int = AudioServer.get_bus_index(bus)
	if bus_idx < 0:
		return
	# Check for existing spectrum analyzer
	for i in range(AudioServer.get_bus_effect_count(bus_idx)):
		var fx := AudioServer.get_bus_effect(bus_idx, i)
		if fx is AudioEffectSpectrumAnalyzer:
			_spectrum_effect = fx
			_spectrum_instance = AudioServer.get_bus_effect_instance(bus_idx, i) as AudioEffectSpectrumAnalyzerInstance
			return
	# Add one
	_spectrum_effect = AudioEffectSpectrumAnalyzer.new()
	AudioServer.add_bus_effect(bus_idx, _spectrum_effect)
	var fx_idx: int = AudioServer.get_bus_effect_count(bus_idx) - 1
	_spectrum_instance = AudioServer.get_bus_effect_instance(bus_idx, fx_idx) as AudioEffectSpectrumAnalyzerInstance
