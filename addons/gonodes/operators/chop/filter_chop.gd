class_name FilterCHOP
extends GNNode
## Smooths/filters CHOP channel data using single-pole IIR (low-pass) or
## simple differencing (high-pass).
## Similar to TouchDesigner's Filter CHOP.

var _prev_values: Dictionary = {}  # channel_name -> float (state for IIR)
var _cached_channel_data: GNChannelData = null


func _init() -> void:
	node_type = "filter"
	family = GNFamily.Type.CHOP
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP)
	add_output("out", GNFamily.Type.CHOP)


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("type",
		PackedStringArray(["Low Pass", "High Pass"]), 0))
	add_parameter(GNParameter.create_float("cutoff", 0.1, 0.001, 1.0, 0.001,
		"Filter Cutoff (0-1)"))
	add_parameter(GNParameter.create_bool("reset", false))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = inputs[0] as GNChannelData if inputs.size() > 0 and inputs[0] is GNChannelData else null
	if in_data == null:
		GNLogger.warn("FilterCHOP", "'%s' — no valid input" % id)
		return null

	var filter_type: int = get_param_value("type")
	var cutoff: float = get_param_value("cutoff")
	var do_reset: bool = get_param_value("reset")

	if do_reset:
		_prev_values.clear()

	if _cached_channel_data == null:
		_cached_channel_data = GNChannelData.new()
	else:
		_cached_channel_data.channels.clear()
		_cached_channel_data.length = 0
	_cached_channel_data.sample_rate = in_data.sample_rate

	var alpha: float = clampf(cutoff, 0.001, 1.0)

	for ch_name in in_data.channels:
		var samples: PackedFloat32Array = in_data.channels[ch_name]
		var out_samples := PackedFloat32Array()
		out_samples.resize(samples.size())

		var prev: float = _prev_values.get(ch_name, samples[0]) if samples.size() > 0 else 0.0

		for i in range(samples.size()):
			var raw: float = samples[i]
			if filter_type == 0:
				# Low pass: y = y_prev + alpha * (x - y_prev)
				var filtered: float = prev + alpha * (raw - prev)
				out_samples[i] = filtered
				prev = filtered
			else:
				# High pass: y = x - low_pass
				var lp: float = prev + alpha * (raw - prev)
				out_samples[i] = raw - lp
				prev = lp

		_prev_values[ch_name] = prev
		_cached_channel_data.set_channel(ch_name, out_samples)

	return _cached_channel_data
