class_name WaveCHOPNative
extends GNChopBase
## Native-accelerated waveform generator — delegates to GNNativeWaveChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "wave_native"
	time_dependent = true
	node_description = "Advanced waveform generator — native C++ accelerated."
	if ClassDB.class_exists("GNNativeWaveChop"):
		_processor = ClassDB.instantiate("GNNativeWaveChop")


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Waveform data")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("waveform",
		PackedStringArray(["Sine", "Triangle", "Square", "Sawtooth", "Pulse", "Ramp"]), 0, "", "Waveform shape"))
	add_parameter(GNParameter.create_int("channels", 1, 1, 16, "", "Number of channels"))
	add_parameter(GNParameter.create_int("length", 1, 1, 4096, "Sample Length", "Samples per channel"))
	add_parameter(GNParameter.create_float("frequency", 1.0, 0.001, 1000.0, 0.01, "", "Wave frequency in Hz"))
	add_parameter(GNParameter.create_float("amplitude", 1.0, 0.0, null, 0.01, "", "Output amplitude"))
	add_parameter(GNParameter.create_float("offset", 0.0, null, null, 0.01, "", "DC offset"))
	add_parameter(GNParameter.create_float("phase", 0.0, 0.0, 1.0, 0.001, "", "Initial phase offset (0-1)"))
	add_parameter(GNParameter.create_float("phase_step", 0.0, 0.0, 1.0, 0.01,
		"Phase offset per channel", "Phase offset added per channel"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var wave_idx: int = get_param_value("waveform")
	var num_ch: int = get_param_value("channels")
	var samp_len: int = get_param_value("length")
	var freq: float = get_param_value("frequency")
	var amp: float = get_param_value("amplitude")
	var off: float = get_param_value("offset")
	var ph: float = get_param_value("phase")
	var ph_step: float = get_param_value("phase_step")

	if _processor != null:
		var result: Dictionary = _processor.process(wave_idx, num_ch, samp_len,
			freq, amp, off, ph, ph_step, elapsed_time)
		var out: GNChannelData = _prepare_output(60.0)
		for key in result:
			out.channels[key] = result[key]
		out.length = samp_len
		return out
	else:
		return null
