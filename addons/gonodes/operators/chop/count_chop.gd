class_name CountCHOP
extends GNChopBase
## Counts up, down, or tracks cumulative values on each input trigger.
## Similar to TouchDesigner's Count CHOP.

var _count_values: Dictionary = {}  # channel -> float
var _prev_in: Dictionary = {}  # channel -> float (for edge detection)


func _init() -> void:
	node_type = "count"
	time_dependent = true
	node_description = "Count rising edges on input channels."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input signal for edge detection")
	add_input("reset", GNFamily.Type.CHOP, false, "Reset trigger signal")
	add_output("out", GNFamily.Type.CHOP, "Count values")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("threshold", 0.5, null, null, 0.01, "", "Edge trigger threshold"))
	add_parameter(GNParameter.create_float("step", 1.0, null, null, 0.01, "Count Step", "Amount added per trigger"))
	add_parameter(GNParameter.create_float("limit_min", 0.0, null, null, 0.01, "", "Minimum count value"))
	add_parameter(GNParameter.create_float("limit_max", 1000000.0, null, null, 0.01, "", "Maximum count value"))
	add_parameter(GNParameter.create_enum("overflow",
		PackedStringArray(["Clamp", "Loop"]), 0, "", "Behaviour when count exceeds limits"))
	add_parameter(GNParameter.create_bool("reset_all", false, "Reset All", "Reset all counters to zero"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = inputs[0] as GNChannelData if inputs.size() > 0 and inputs[0] is GNChannelData else null
	var reset_data: GNChannelData = inputs[1] as GNChannelData if inputs.size() > 1 and inputs[1] is GNChannelData else null

	if in_data == null:
		GNLogger.warn("CountCHOP", "'%s' — no valid input" % id)
		return null

	var thresh: float = get_param_value("threshold")
	var step_val: float = get_param_value("step")
	var lo: float = get_param_value("limit_min")
	var hi: float = get_param_value("limit_max")
	var overflow_mode: int = get_param_value("overflow")
	var reset_all: bool = get_param_value("reset_all")

	if reset_all:
		_count_values.clear()
		_prev_in.clear()

	if _cached_channel_data == null:
		_cached_channel_data = GNChannelData.new()
	else:
		_cached_channel_data.channels.clear()
		_cached_channel_data.length = 0
	_cached_channel_data.sample_rate = 60.0

	# Check if reset input is triggered
	var do_reset: bool = false
	if reset_data != null:
		for ch_name in reset_data.channels:
			var r_samples: PackedFloat32Array = reset_data.channels[ch_name]
			if r_samples.size() > 0 and r_samples[r_samples.size() - 1] >= thresh:
				do_reset = true
				break

	if do_reset:
		_count_values.clear()

	for ch_name in in_data.channels:
		var samples: PackedFloat32Array = in_data.channels[ch_name]
		if samples.size() == 0:
			continue

		var current_val: float = samples[samples.size() - 1]
		var prev_val: float = _prev_in.get(ch_name, 0.0)
		_prev_in[ch_name] = current_val

		if not _count_values.has(ch_name):
			_count_values[ch_name] = lo

		# Rising edge detection
		if prev_val < thresh and current_val >= thresh:
			_count_values[ch_name] += step_val

		# Apply limits
		var count: float = _count_values[ch_name]
		if count > hi:
			count = lo if overflow_mode == 1 else hi
		elif count < lo:
			count = hi if overflow_mode == 1 else lo
		_count_values[ch_name] = count

		_cached_channel_data.set_single_value(ch_name, count)

	return _cached_channel_data
