class_name PulseCHOP
extends GNChopBase
## Generates periodic pulse trains with configurable period, width, and jitter.
##
## Unlike TriggerCHOP (which fires one-shot pulses from input crossings),
## PulseCHOP is a self-running generator that produces continuous pulse
## trains at a specified frequency — useful for driving animations, clocks,
## sequencer steps, or periodic triggers.
##
## Output channels: pulse (0 or 1), phase (0-1 ramp), count (total pulses).
##
## TouchDesigner equivalent: Pulse CHOP.

var _phase: float = 0.0
var _count: int = 0
var _was_high: bool = false


func _init() -> void:
	node_type = "pulse"
	time_dependent = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Pulse train output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("frequency", 1.0, 0.001, 1000.0, 0.01,
		"Frequency (Hz)", "Pulse repetition rate"))
	add_parameter(GNParameter.create_float("duty_cycle", 0.5, 0.0, 1.0, 0.01,
		"Duty Cycle", "Fraction of period spent high (0-1)"))
	add_parameter(GNParameter.create_float("amplitude", 1.0, 0.0, null, 0.01,
		"Amplitude", "Pulse high value"))
	add_parameter(GNParameter.create_float("offset", 0.0, null, null, 0.01,
		"Offset", "DC offset added to output"))
	add_parameter(GNParameter.create_float("jitter", 0.0, 0.0, 1.0, 0.01,
		"Jitter", "Random variation in period (0 = none, 1 = full period)"))
	add_parameter(GNParameter.create_bool("active", true,
		"Active", "Enable/disable pulse generation"))
	add_parameter(GNParameter.create_pulse("reset",
		"Reset", "Reset phase and count to zero"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var freq: float = maxf(get_param_value("frequency"), 0.001)
	var duty: float = clampf(get_param_value("duty_cycle"), 0.0, 1.0)
	var amp: float = get_param_value("amplitude")
	var off: float = get_param_value("offset")
	var jitter: float = get_param_value("jitter")
	var active: bool = get_param_value("active")
	var do_reset: bool = get_param_value("reset")

	if do_reset:
		_phase = 0.0
		_count = 0
		_was_high = false

	var out: GNChannelData = _prepare_output(60.0)

	if not active:
		out.set_single_value("pulse", off)
		out.set_single_value("phase", _phase)
		out.set_single_value("count", float(_count))
		return out

	# Advance phase
	var dt: float = current_delta
	var period: float = 1.0 / freq
	if jitter > 0.0:
		# Deterministic jitter based on count (not random per frame)
		var jitter_offset: float = sin(float(_count) * 12.9898) * jitter * 0.5
		period *= (1.0 + jitter_offset)
		period = maxf(period, dt)  # Never shorter than one frame

	_phase += dt / period
	if _phase >= 1.0:
		_phase -= 1.0
		_count += 1

	# Generate pulse
	var is_high: bool = _phase < duty
	var pulse_val: float = amp if is_high else 0.0
	pulse_val += off

	out.set_single_value("pulse", pulse_val)
	out.set_single_value("phase", _phase)
	out.set_single_value("count", float(_count))
	return out
