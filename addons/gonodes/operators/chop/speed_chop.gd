class_name SpeedCHOP
extends GNNode
## Integrates input values over time (velocity → position).
## Each frame, the output accumulates: position += input * dt.
## Similar to TouchDesigner's Speed CHOP.

var _accum: Dictionary = {}  # channel_name -> float
var _cached_channel_data: GNChannelData = null


func _init() -> void:
	node_type = "speed"
	family = GNFamily.Type.CHOP
	time_dependent = true
	node_description = "Integrate input over time (velocity to position)."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Velocity input")
	add_input("reset", GNFamily.Type.CHOP, false, "Reset trigger")
	add_output("out", GNFamily.Type.CHOP, "Accumulated position")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("scale", 1.0, null, null, 0.01, "", "Velocity multiplier"))
	add_parameter(GNParameter.create_bool("clamp", false, "", "Clamp output to min/max range"))
	add_parameter(GNParameter.create_float("min", -1000.0, null, null, 0.01, "", "Minimum clamp value"))
	add_parameter(GNParameter.create_float("max", 1000.0, null, null, 0.01, "", "Maximum clamp value"))
	add_parameter(GNParameter.create_bool("reset_all", false, "Reset", "Reset all accumulators"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = inputs[0] as GNChannelData if inputs.size() > 0 and inputs[0] is GNChannelData else null
	var reset_data: GNChannelData = inputs[1] as GNChannelData if inputs.size() > 1 and inputs[1] is GNChannelData else null

	if in_data == null:
		GNLogger.warn("SpeedCHOP", "'%s' — no valid input" % id)
		return null

	var scl: float = get_param_value("scale")
	var do_clamp: bool = get_param_value("clamp")
	var lo: float = get_param_value("min")
	var hi: float = get_param_value("max")
	var do_reset: bool = get_param_value("reset_all")
	var dt: float = current_delta

	if do_reset:
		_accum.clear()

	# Check reset input
	if reset_data != null:
		for ch_name in reset_data.channels:
			var s: PackedFloat32Array = reset_data.channels[ch_name]
			if s.size() > 0 and s[s.size() - 1] >= 0.5:
				_accum.clear()
				break

	if _cached_channel_data == null:
		_cached_channel_data = GNChannelData.new()
	else:
		_cached_channel_data.channels.clear()
		_cached_channel_data.length = 0
	_cached_channel_data.sample_rate = in_data.sample_rate

	for ch_name in in_data.channels:
		var samples: PackedFloat32Array = in_data.channels[ch_name]
		if samples.size() == 0:
			continue

		if not _accum.has(ch_name):
			_accum[ch_name] = 0.0

		var velocity: float = samples[samples.size() - 1]
		_accum[ch_name] += velocity * scl * dt

		if do_clamp:
			_accum[ch_name] = clampf(_accum[ch_name], lo, hi)

		_cached_channel_data.set_single_value(ch_name, _accum[ch_name])

	return _cached_channel_data
