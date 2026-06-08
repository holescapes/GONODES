class_name AudioOscillatorCHOP
extends GNChopBase
## Audio-rate waveform generator with FM and AM modulation.
##
## Generates sine, saw, square, triangle, pulse, and white noise at audio
## sample rates (44100/48000 Hz). Supports frequency modulation via the
## second input and amplitude modulation via the third input.
##
## Outputs stereo channels (left, right) with configurable phase offset
## between channels for stereo width.

const TWO_PI := TAU


func _init() -> void:
	node_type = "audiooscillator"
	time_dependent = true


func _init_ports() -> void:
	add_input("fm", GNFamily.Type.CHOP, true, "Frequency modulation input (Hz offset)", "Fm")
	add_input("am", GNFamily.Type.CHOP, true, "Amplitude modulation input (0-1 multiplier)", "Am")
	add_output("out", GNFamily.Type.CHOP, "Generated audio waveform", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("waveform",
		PackedStringArray(["Sine", "Saw", "Square", "Triangle", "Pulse", "Noise"]), 0,
		"Waveform", "Oscillator waveform shape"))
	add_parameter(GNParameter.create_float("frequency", 440.0, 0.001, 20000.0, 0.1,
		"Frequency", "Base frequency in Hz"))
	add_parameter(GNParameter.create_float("amplitude", 1.0, 0.0, 2.0, 0.01,
		"Amplitude", "Output amplitude"))
	add_parameter(GNParameter.create_float("pulse_width", 0.5, 0.01, 0.99, 0.01,
		"Pulse Width", "Duty cycle for pulse waveform"))
	add_parameter(GNParameter.create_float("fm_depth", 1.0, 0.0, 10000.0, 1.0,
		"FM Depth", "Frequency modulation depth in Hz"))
	add_parameter(GNParameter.create_float("stereo_phase", 0.0, 0.0, 1.0, 0.01,
		"Stereo Phase", "Phase offset between L/R channels (0=mono, 0.5=widest)"))
	add_parameter(GNParameter.create_int("buffer_size", 512, 64, 8192,
		"Buffer Size", "Samples per cook (latency vs CPU trade-off)"))

var _phase_l: float = 0.0
var _phase_r: float = 0.0
var _rng := RandomNumberGenerator.new()


func _cook(inputs: Array[GNData]) -> GNData:
	var sr: float = AudioServer.get_mix_rate()
	var out := _prepare_output(sr)

	var waveform: int = get_param_value("waveform")
	var freq: float = get_param_value("frequency")
	var amp: float = get_param_value("amplitude")
	var pw: float = get_param_value("pulse_width")
	var fm_depth: float = get_param_value("fm_depth")
	var stereo_offset: float = get_param_value("stereo_phase")
	var buf_size: int = get_param_value("buffer_size")

	var fm_data: GNChannelData = _get_input_chop(inputs, 0)
	var am_data: GNChannelData = _get_input_chop(inputs, 1)

	var left := PackedFloat32Array()
	left.resize(buf_size)
	var right := PackedFloat32Array()
	right.resize(buf_size)

	var phase_inc_base: float = freq / sr

	for i: int in range(buf_size):
		# FM modulation
		var fm_val: float = 0.0
		if fm_data != null:
			var fm_samples: PackedFloat32Array = fm_data.get_channel(fm_data.get_channel_names()[0]) if fm_data.get_channel_names().size() > 0 else PackedFloat32Array()
			if fm_samples.size() > 0:
				fm_val = fm_samples[mini(i, fm_samples.size() - 1)]
		var mod_freq: float = freq + fm_val * fm_depth
		var phase_inc: float = mod_freq / sr

		# Generate L/R
		var val_l: float = _evaluate_waveform(waveform, _phase_l, pw)
		var val_r: float = _evaluate_waveform(waveform, fmod(_phase_r + stereo_offset, 1.0), pw)

		# AM modulation
		var am_val: float = 1.0
		if am_data != null:
			var am_samples: PackedFloat32Array = am_data.get_channel(am_data.get_channel_names()[0]) if am_data.get_channel_names().size() > 0 else PackedFloat32Array()
			if am_samples.size() > 0:
				am_val = am_samples[mini(i, am_samples.size() - 1)]

		left[i] = val_l * amp * am_val
		right[i] = val_r * amp * am_val

		_phase_l = fmod(_phase_l + phase_inc, 1.0)
		_phase_r = fmod(_phase_r + phase_inc, 1.0)

	out.set_channel("left", left)
	out.set_channel("right", right)
	return out


func _evaluate_waveform(waveform: int, phase: float, pw: float) -> float:
	match waveform:
		0:  # Sine
			return sin(phase * TWO_PI)
		1:  # Saw
			return 2.0 * phase - 1.0
		2:  # Square
			return 1.0 if phase < 0.5 else -1.0
		3:  # Triangle
			return 4.0 * absf(phase - 0.5) - 1.0
		4:  # Pulse
			return 1.0 if phase < pw else -1.0
		5:  # Noise
			return _rng.randf_range(-1.0, 1.0)
		_:
			return 0.0
