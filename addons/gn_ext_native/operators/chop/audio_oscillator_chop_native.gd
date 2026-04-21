class_name AudioOscillatorCHOPNative
extends GNChopBase
## Native-accelerated audio oscillator — delegates to GNNativeAudioOscillatorChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "audiooscillator"
	time_dependent = true
	if ClassDB.class_exists("GNNativeAudioOscillatorChop"):
		_processor = ClassDB.instantiate("GNNativeAudioOscillatorChop")


func _init_ports() -> void:
	add_input("fm", GNFamily.Type.CHOP, true, "Frequency modulation input (Hz offset)")
	add_input("am", GNFamily.Type.CHOP, true, "Amplitude modulation input (0-1 multiplier)")
	add_output("out", GNFamily.Type.CHOP, "Generated audio waveform")


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


func _cook(inputs: Array[GNData]) -> GNData:
	if not _processor:
		return null

	var waveform: int = get_param_value("waveform")
	var freq: float = get_param_value("frequency")
	var amp: float = get_param_value("amplitude")
	var pw: float = get_param_value("pulse_width")
	var fm_depth: float = get_param_value("fm_depth")
	var stereo_phase: float = get_param_value("stereo_phase")
	var buffer_size: int = get_param_value("buffer_size")
	var sr: float = 44100.0

	# Get FM input if connected
	var fm_input := PackedFloat32Array()
	var fm_chop := _get_input_chop(inputs, 0)
	if fm_chop:
		for ch_name in fm_chop.channels:
			fm_input = fm_chop.channels[ch_name]
			break

	# Get AM input
	var am_chop := _get_input_chop(inputs, 1)

	var stereo: PackedFloat32Array = _processor.process_stereo(
		waveform, freq, amp, pw, fm_depth, stereo_phase, buffer_size, sr, fm_input)

	# Apply AM if connected
	if am_chop:
		var am_arr := PackedFloat32Array()
		for ch_name in am_chop.channels:
			am_arr = am_chop.channels[ch_name]
			break
		for i in range(mini(stereo.size(), am_arr.size())):
			stereo[i] *= am_arr[i / 2] if i / 2 < am_arr.size() else 1.0

	var out := _prepare_output(sr)
	var left := PackedFloat32Array()
	var right := PackedFloat32Array()
	left.resize(buffer_size)
	right.resize(buffer_size)
	for i in range(buffer_size):
		left[i] = stereo[i * 2]
		right[i] = stereo[i * 2 + 1]
	out.channels["left"] = left
	out.channels["right"] = right
	out.length = buffer_size
	return out
