class_name LFO_CHOP
extends GNNode
## Low-Frequency Oscillator — generates a single "out" channel with a periodic waveform.
## Always time-dependent (cooks every frame).

## Waveform types available for the LFO.
enum Waveform { SINE, TRIANGLE, SQUARE, SAWTOOTH, PULSE }

## Internal phase accumulator (wraps 0→1 continuously).
var _phase_accum: float = 0.0

## Reusable output data object (created once, updated each cook).
var _cached_channel_data: GNChannelData = null


func _init() -> void:
	node_type = "lfo"
	family = GNFamily.Type.CHOP
	time_dependent = true
	node_description = "Low-frequency oscillator (sine, triangle, square, etc.)."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "LFO waveform output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("waveform",
		PackedStringArray(["Sine", "Triangle", "Square", "Sawtooth", "Pulse"]), 0, "", "Waveform shape"))
	add_parameter(GNParameter.create_float("frequency", 1.0, 0.001, 100.0, 0.01, "", "Oscillation frequency in Hz"))
	add_parameter(GNParameter.create_float("amplitude", 1.0, 0.0, null, 0.01, "", "Output amplitude"))
	add_parameter(GNParameter.create_float("offset", 0.0, null, null, 0.01, "", "DC offset added to output"))
	add_parameter(GNParameter.create_float("phase", 0.0, 0.0, 1.0, 0.001, "", "Phase offset (0-1)"))
	add_parameter(GNParameter.create_float("duty_cycle", 0.5, 0.0, 1.0, 0.01, "", "Pulse width for pulse waveform"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var freq: float = get_param_value("frequency")
	var amp: float = get_param_value("amplitude")
	var off: float = get_param_value("offset")
	var ph: float = get_param_value("phase")
	var waveform_idx: int = get_param_value("waveform")
	var duty: float = get_param_value("duty_cycle")

	# Advance phase accumulator using engine-injected delta.
	_phase_accum += freq * current_delta
	_phase_accum = fmod(_phase_accum, 1.0)

	var phase_total: float = fmod(_phase_accum + ph, 1.0)
	var value: float = _evaluate_waveform(waveform_idx, phase_total, duty)
	value = value * amp + off

	if _cached_channel_data == null:
		_cached_channel_data = GNChannelData.new()
	_cached_channel_data.set_single_value("out", value)
	_cached_channel_data.sample_rate = 60.0
	return _cached_channel_data


## Evaluates the selected waveform at a given phase [0, 1).
func _evaluate_waveform(waveform_idx: int, phase: float, duty: float) -> float:
	match waveform_idx:
		Waveform.SINE:
			return sin(phase * TAU)
		Waveform.TRIANGLE:
			return 1.0 - 4.0 * absf(phase - 0.5)
		Waveform.SQUARE:
			return 1.0 if phase < 0.5 else -1.0
		Waveform.SAWTOOTH:
			return 2.0 * phase - 1.0
		Waveform.PULSE:
			return 1.0 if phase < duty else -1.0
		_:
			return 0.0
