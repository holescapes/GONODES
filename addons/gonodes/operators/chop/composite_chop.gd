class_name CompositeCHOP
extends GNChopBase
## Weighted blend of channels from multiple inputs.
## Each input can have a weight; all matching channel names are combined.
## Uses dynamic auto-grow input ports.


func _init() -> void:
	node_type = "composite"
	node_description = "Weighted blend of channels from multiple inputs."


func _init_ports() -> void:
	_enable_dynamic_inputs(GNFamily.Type.CHOP, "ch", "CHOP Input")
	add_output("out", GNFamily.Type.CHOP, "Composited channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("operation",
		PackedStringArray(["Weighted Average", "Add", "Max", "Min"]),
		0, "", "How to combine channels"))
	add_parameter(GNParameter.create_string("weights", "1,1,1,1",
		"Comma-separated weights per input", "Per-input blend weights"))


func _cook(inputs: Array[GNData]) -> GNData:
	var op: int = get_param_value("operation")
	var weights_str: String = get_param_value("weights")

	# Parse weights
	var weight_parts: PackedStringArray = weights_str.split(",")
	var weights: PackedFloat32Array = PackedFloat32Array()
	for w in weight_parts:
		weights.append(w.strip_edges().to_float() if not w.strip_edges().is_empty() else 1.0)

	# Collect valid inputs
	var valid_inputs: Array[GNChannelData] = []
	var sr: float = 60.0
	for inp in inputs:
		var ch_data: GNChannelData = inp as GNChannelData if inp is GNChannelData else null
		if ch_data == null:
			continue
		valid_inputs.append(ch_data)
		sr = ch_data.sample_rate

	if valid_inputs.is_empty():
		return null

	var out: GNChannelData = _prepare_output(sr)

	# Collect all channel names
	var all_names: Dictionary = {}
	for vi in valid_inputs:
		for ch in vi.channels:
			all_names[ch] = true

	for ch_name in all_names:
		var values: Array[float] = []
		var w_list: Array[float] = []

		for idx in range(valid_inputs.size()):
			var vi: GNChannelData = valid_inputs[idx]
			if not vi.channels.has(ch_name):
				continue
			var samples: PackedFloat32Array = vi.channels[ch_name]
			if samples.is_empty():
				continue
			var val: float = samples[samples.size() - 1]
			var w: float = weights[idx] if idx < weights.size() else 1.0
			values.append(val)
			w_list.append(w)

		if values.is_empty():
			continue

		var result: float = 0.0
		match op:
			0:  # Weighted Average
				var total_w: float = 0.0
				for i in range(values.size()):
					result += values[i] * w_list[i]
					total_w += w_list[i]
				result = result / maxf(total_w, 0.0001)
			1:  # Add
				for i in range(values.size()):
					result += values[i] * w_list[i]
			2:  # Max
				result = values[0]
				for i in range(1, values.size()):
					result = maxf(result, values[i])
			3:  # Min
				result = values[0]
				for i in range(1, values.size()):
					result = minf(result, values[i])

		out.set_single_value(ch_name, result)

	return out
