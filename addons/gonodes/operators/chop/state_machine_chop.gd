class_name StateMachineCHOP
extends GNChopBase
## Finite state machine with configurable states and transitions.
## Outputs: current_state, prev_state, time_in_state, transition_progress.
## Transitions are triggered by input channel values exceeding threshold.

var _current_state: int = 0
var _prev_state: int = 0
var _time_in_state: float = 0.0
var _transition_progress: float = 1.0
var _transition_duration: float = 0.0
var _transition_elapsed: float = 0.0
var _transitioning: bool = false
var _transition_target: int = -1


func _init() -> void:
	node_type = "statemachine"
	time_dependent = true


func _init_ports() -> void:
	add_input("trigger", GNFamily.Type.CHOP, true, "Trigger channels (trigger0, trigger1, ...)")
	add_output("out", GNFamily.Type.CHOP, "State machine output channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("num_states", 4, 2, 64,
		"Num States", "Number of states in the machine"))
	add_parameter(GNParameter.create_int("init_state", 0, 0, 63,
		"Initial State", "State index on reset"))
	add_parameter(GNParameter.create_float("threshold", 0.5, 0.0, 1.0, 0.01,
		"Threshold", "Trigger value threshold for state transition"))
	add_parameter(GNParameter.create_float("transition_time", 0.0, 0.0, 10.0, 0.01,
		"Transition Time", "Duration of transition blend in seconds"))
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Sequential", "Direct", "Ping-Pong"]), 0,
		"Mode", "Transition mode: Sequential cycles, Direct jumps, Ping-Pong bounces"))
	add_parameter(GNParameter.create_bool("loop", true,
		"Loop", "Wrap around from last state to first (Sequential/Ping-Pong)"))
	add_parameter(GNParameter.create_bool("reset", false,
		"Reset", "Reset to initial state"))


func _cook(inputs: Array[GNData]) -> GNData:
	var num_states: int = get_param_value("num_states")
	var init_state: int = get_param_value("init_state")
	var threshold: float = get_param_value("threshold")
	var trans_time: float = get_param_value("transition_time")
	var mode: int = get_param_value("mode")
	var do_loop: bool = get_param_value("loop")
	var do_reset: bool = get_param_value("reset")

	if do_reset:
		_current_state = clampi(init_state, 0, num_states - 1)
		_prev_state = _current_state
		_time_in_state = 0.0
		_transitioning = false
		_transition_progress = 1.0

	var dt: float = current_delta

	# Handle ongoing transition
	if _transitioning:
		_transition_elapsed += dt
		if _transition_duration > 0.0:
			_transition_progress = clampf(_transition_elapsed / _transition_duration, 0.0, 1.0)
		else:
			_transition_progress = 1.0
		if _transition_progress >= 1.0:
			_prev_state = _current_state
			_current_state = _transition_target
			_transitioning = false
			_time_in_state = 0.0

	_time_in_state += dt

	# Check triggers
	var trigger_data := _get_input_chop(inputs, 0)
	if trigger_data != null and not _transitioning:
		match mode:
			0: # Sequential
				var any_trigger := false
				for ch_name in trigger_data.channels:
					var s: PackedFloat32Array = trigger_data.channels[ch_name]
					if s.size() > 0 and s[s.size() - 1] >= threshold:
						any_trigger = true
						break
				if any_trigger:
					_begin_transition((_current_state + 1) % num_states if do_loop else mini(_current_state + 1, num_states - 1), trans_time)
			1: # Direct — trigger channels map to states by index
				var idx: int = 0
				for ch_name in trigger_data.channels:
					if idx >= num_states:
						break
					var s: PackedFloat32Array = trigger_data.channels[ch_name]
					if s.size() > 0 and s[s.size() - 1] >= threshold and idx != _current_state:
						_begin_transition(idx, trans_time)
						break
					idx += 1
			2: # Ping-Pong
				var any_trigger := false
				for ch_name in trigger_data.channels:
					var s: PackedFloat32Array = trigger_data.channels[ch_name]
					if s.size() > 0 and s[s.size() - 1] >= threshold:
						any_trigger = true
						break
				if any_trigger:
					var next: int = _current_state + 1
					if next >= num_states:
						next = maxi(num_states - 2, 0)
					_begin_transition(next, trans_time)

	var out := _prepare_output(60.0)
	out.length = 1
	out.channels["current_state"] = PackedFloat32Array([float(_current_state)])
	out.channels["prev_state"] = PackedFloat32Array([float(_prev_state)])
	out.channels["time_in_state"] = PackedFloat32Array([_time_in_state])
	out.channels["transition_progress"] = PackedFloat32Array([_transition_progress])
	out.channels["num_states"] = PackedFloat32Array([float(num_states)])
	return out


func _begin_transition(target: int, duration: float) -> void:
	_transition_target = target
	_transition_duration = duration
	_transition_elapsed = 0.0
	_transitioning = true
	if duration <= 0.0:
		_transition_progress = 1.0
		_prev_state = _current_state
		_current_state = target
		_transitioning = false
		_time_in_state = 0.0
	else:
		_transition_progress = 0.0
