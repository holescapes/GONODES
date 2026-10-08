class_name LagCHOP
extends GNChopBase
## Applies attack/release smoothing to CHOP channels.
## When a value rises, it follows the attack speed; when it falls, the release speed.
## Similar to TouchDesigner's Lag CHOP.

var _prev_values: Dictionary = {}  # channel_name -> float


func _init() -> void:
	node_type = "lag"


func update_time_dependency() -> void:
	time_dependent = _temporal_moving


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels", "In")
	add_output("out", GNFamily.Type.CHOP, "Smoothed channels", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("attack", 0.2, 0.0, 10.0, 0.01,
		"Attack Time (sec)", "Rise smoothing time in seconds"))
	add_parameter(GNParameter.create_float("release", 0.2, 0.0, 10.0, 0.01,
		"Release Time (sec)", "Fall smoothing time in seconds"))
	add_parameter(GNParameter.create_bool("reset", false, "Reset", "Clear smooth state"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		GNLogger.warn("LagCHOP", "'%s' — no valid input" % id)
		return null

	var attack: float = get_param_value("attack")
	var release: float = get_param_value("release")
	var do_reset: bool = get_param_value("reset")
	var dt: float = current_delta

	if do_reset:
		_prev_values.clear()
		_temporal_end_state.clear()

	if _cached_channel_data == null:
		_cached_channel_data = GNChannelData.new()
	else:
		_cached_channel_data.channels.clear()
		_cached_channel_data.length = 0
	_cached_channel_data.sample_rate = in_data.sample_rate

	for ch_name in in_data.channels:
		var samples: PackedFloat32Array = in_data.channels[ch_name]
		var out_samples := PackedFloat32Array()
		out_samples.resize(samples.size())

		var prev: float = _prev_values.get(ch_name, samples[0]) if samples.size() > 0 else 0.0

		for i in range(samples.size()):
			var target: float = samples[i]
			var tau: float = attack if target > prev else release
			if tau <= 0.0:
				prev = target
			else:
				var alpha: float = 1.0 - exp(-dt / tau) if dt > 0.0 else 1.0
				prev = prev + alpha * (target - prev)
			out_samples[i] = prev

		_prev_values[ch_name] = prev
		_cached_channel_data.set_channel(ch_name, out_samples)

	var moved := false
	for ch_name in _prev_values:
		if _temporal_sample_moved(ch_name, float(_prev_values[ch_name])):
			moved = true
	_finish_temporal_cook(moved)
	return _cached_channel_data
