class_name WaveCHOP
extends GNChopBase
## Advanced waveform generator with multi-channel support and time controls.
## More flexible than LFO_CHOP — supports different wave shapes per channel,
## time range, and sample count.

enum Waveform { SINE, TRIANGLE, SQUARE, SAWTOOTH, PULSE, RAMP }


func _init() -> void:
	node_type = "wave"
	time_dependent = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Waveform data")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("waveform",
		PackedStringArray(["Sine", "Triangle", "Square", "Sawtooth", "Pulse", "Ramp"]), 0, "", "Waveform shape"))
	add_parameter(GNParameter.create_int("channels", 1, 1, 16, "Channels", "Number of channels"))
	add_parameter(GNParameter.create_int("length", 1, 1, 4096, "Sample Length", "Samples per channel"))
	add_parameter(GNParameter.create_float("frequency", 1.0, 0.001, 1000.0, 0.01, "Frequency", "Wave frequency in Hz"))
	add_parameter(GNParameter.create_float("amplitude", 1.0, 0.0, null, 0.01, "Amplitude", "Output amplitude"))
	add_parameter(GNParameter.create_float("offset", 0.0, null, null, 0.01, "Offset", "DC offset"))
	add_parameter(GNParameter.create_float("phase", 0.0, 0.0, 1.0, 0.001, "Phase", "Initial phase offset (0-1)"))
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

	if _cached_channel_data == null:
		_cached_channel_data = GNChannelData.new()
	else:
		_cached_channel_data.channels.clear()
		_cached_channel_data.length = 0
	_cached_channel_data.sample_rate = 60.0

	var t: float = elapsed_time

	for ch in range(num_ch):
		var ch_name: String = "chan%d" % (ch + 1)
		var ch_phase: float = ph + ph_step * ch

		if samp_len == 1:
			# Single-sample mode — use current time
			var phase_val: float = fmod(t * freq + ch_phase, 1.0)
			if phase_val < 0.0:
				phase_val += 1.0
			var value: float = _evaluate(wave_idx, phase_val) * amp + off
			_cached_channel_data.set_single_value(ch_name, value)
		else:
			# Multi-sample mode — fill array
			var samples := PackedFloat32Array()
			samples.resize(samp_len)
			for i in range(samp_len):
				var norm: float = float(i) / float(samp_len)
				var phase_val: float = fmod(norm * freq + ch_phase, 1.0)
				if phase_val < 0.0:
					phase_val += 1.0
				samples[i] = _evaluate(wave_idx, phase_val) * amp + off
			_cached_channel_data.set_channel(ch_name, samples)

	return _cached_channel_data


func _evaluate(wave_idx: int, phase: float) -> float:
	match wave_idx:
		Waveform.SINE:
			return sin(phase * TAU)
		Waveform.TRIANGLE:
			return 1.0 - 4.0 * absf(phase - 0.5)
		Waveform.SQUARE:
			return 1.0 if phase < 0.5 else -1.0
		Waveform.SAWTOOTH:
			return 2.0 * phase - 1.0
		Waveform.PULSE:
			return 1.0 if phase < 0.25 else 0.0
		Waveform.RAMP:
			return phase
		_:
			return 0.0
