class_name AnalyzeCHOP
extends GNChopBase
## Computes per-channel statistics: min, max, average, RMS, sum, or range.
## Outputs a single value per channel.


func _init() -> void:
	node_type = "analyze"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels", "In")
	add_output("out", GNFamily.Type.CHOP, "Statistics", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("function",
		PackedStringArray(["Average", "Minimum", "Maximum", "Sum", "RMS", "Range", "Count"]),
		0, "", "Statistic to compute"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var func_type: int = get_param_value("function")
	var out: GNChannelData = _prepare_output(in_data.sample_rate)

	for ch_name in in_data.channels:
		var samples: PackedFloat32Array = in_data.channels[ch_name]
		if samples.is_empty():
			out.set_single_value(ch_name, 0.0)
			continue

		var result: float = 0.0
		match func_type:
			0:  # Average
				var total: float = 0.0
				for s in samples:
					total += s
				result = total / samples.size()
			1:  # Minimum
				result = samples[0]
				for i in range(1, samples.size()):
					result = minf(result, samples[i])
			2:  # Maximum
				result = samples[0]
				for i in range(1, samples.size()):
					result = maxf(result, samples[i])
			3:  # Sum
				for s in samples:
					result += s
			4:  # RMS
				var sum_sq: float = 0.0
				for s in samples:
					sum_sq += s * s
				result = sqrt(sum_sq / samples.size())
			5:  # Range (max - min)
				var lo: float = samples[0]
				var hi: float = samples[0]
				for i in range(1, samples.size()):
					lo = minf(lo, samples[i])
					hi = maxf(hi, samples[i])
				result = hi - lo
			6:  # Count
				result = float(samples.size())

		out.set_single_value(ch_name, result)

	return out
