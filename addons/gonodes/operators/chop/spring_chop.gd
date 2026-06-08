class_name SpringCHOP
extends GNChopBase
## Damped harmonic oscillator applied to CHOP channels.
## Input values act as the target position; output overshoots and oscillates
## based on stiffness and damping, creating natural springy motion.

var _pos: Dictionary = {}  # channel -> current position
var _vel: Dictionary = {}  # channel -> current velocity


func _init() -> void:
	node_type = "spring"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Target values", "In")
	add_output("out", GNFamily.Type.CHOP, "Springy values", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("stiffness", 20.0, 0.1, 500.0, 0.1,
		"Stiffness (k)", "Spring constant — higher = snappier"))
	add_parameter(GNParameter.create_float("damping", 4.0, 0.0, 50.0, 0.1,
		"Damping (c)", "Damping coefficient — higher = less overshoot"))
	add_parameter(GNParameter.create_float("mass", 1.0, 0.01, 10.0, 0.01,
		"Mass", "Object mass — higher = slower response"))
	add_parameter(GNParameter.create_bool("reset", false, "Reset", "Reset spring state"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var k: float = get_param_value("stiffness")
	var c: float = get_param_value("damping")
	var m: float = maxf(get_param_value("mass"), 0.01)
	var do_reset: bool = get_param_value("reset")
	var dt: float = current_delta

	if do_reset:
		_pos.clear(); _vel.clear()

	if dt <= 0.0:
		dt = 1.0 / 60.0

	var out: GNChannelData = _prepare_output(in_data.sample_rate)

	for ch_name in in_data.channels:
		var samples: PackedFloat32Array = in_data.channels[ch_name]
		if samples.is_empty():
			continue

		var target: float = samples[samples.size() - 1]

		if not _pos.has(ch_name):
			_pos[ch_name] = target
			_vel[ch_name] = 0.0

		# Semi-implicit Euler integration
		var pos: float = _pos[ch_name]
		var vel: float = _vel[ch_name]
		var force: float = -k * (pos - target) - c * vel
		var accel: float = force / m
		vel += accel * dt
		pos += vel * dt

		_pos[ch_name] = pos
		_vel[ch_name] = vel
		out.set_single_value(ch_name, pos)

	return out
