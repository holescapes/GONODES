class_name BlendCHOP
extends GNChopBase
## Sample-by-sample weighted blend between multiple CHOP inputs.
## Unlike CompositeCHOP (which blends only last sample), this blends
## every sample across the full channel arrays.

func _init() -> void:
	node_type = "blend"


func _init_ports() -> void:
	_enable_dynamic_inputs(GNFamily.Type.CHOP, "in", "Input", 2)
	add_output("out", GNFamily.Type.CHOP, "Blended output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("weight", 0.5, 0.0, 1.0, 0.01,
		"Blend Weight", "0 = first input, 1 = last input (interpolates across all)"))
	add_parameter(GNParameter.create_enum("method",
		PackedStringArray(["Linear", "Ease In", "Ease Out", "Smooth Step"]),
		0, "Method", "Interpolation curve"))


func _cook(inputs: Array[GNData]) -> GNData:
	# Collect valid CHOP inputs
	var valid_inputs: Array[GNChannelData] = []
	for inp in inputs:
		if inp is GNChannelData:
			valid_inputs.append(inp as GNChannelData)

	if valid_inputs.is_empty():
		return null

	if valid_inputs.size() == 1:
		return valid_inputs[0]

	var weight: float = clampf(get_param_value("weight"), 0.0, 1.0)
	var method: int = get_param_value("method")

	# Map weight to a position across the input array
	var num_inputs: int = valid_inputs.size()
	var scaled: float = weight * (num_inputs - 1)
	var idx_a: int = clampi(int(scaled), 0, num_inputs - 2)
	var idx_b: int = idx_a + 1
	var t: float = scaled - idx_a

	# Apply easing
	t = _apply_easing(t, method)

	var data_a: GNChannelData = valid_inputs[idx_a]
	var data_b: GNChannelData = valid_inputs[idx_b]

	if _cached_channel_data == null:
		_cached_channel_data = GNChannelData.new()
	else:
		_cached_channel_data.channels.clear()
		_cached_channel_data.length = 0
	_cached_channel_data.sample_rate = data_a.sample_rate

	# Blend all channels that exist in either input
	var all_channels: Dictionary = {}
	for ch_name in data_a.channels:
		all_channels[ch_name] = true
	for ch_name in data_b.channels:
		all_channels[ch_name] = true

	for ch_name in all_channels:
		var samples_a: PackedFloat32Array = data_a.channels.get(ch_name, PackedFloat32Array())
		var samples_b: PackedFloat32Array = data_b.channels.get(ch_name, PackedFloat32Array())
		var max_len: int = maxi(samples_a.size(), samples_b.size())
		if max_len == 0:
			continue

		var out_samples := PackedFloat32Array()
		out_samples.resize(max_len)
		for i in range(max_len):
			var va: float = samples_a[i] if i < samples_a.size() else (samples_a[samples_a.size() - 1] if samples_a.size() > 0 else 0.0)
			var vb: float = samples_b[i] if i < samples_b.size() else (samples_b[samples_b.size() - 1] if samples_b.size() > 0 else 0.0)
			out_samples[i] = lerpf(va, vb, t)

		_cached_channel_data.set_channel(ch_name, out_samples)

	return _cached_channel_data


func _apply_easing(t: float, method: int) -> float:
	match method:
		0: return t  # Linear
		1: return t * t  # Ease In
		2: return 1.0 - (1.0 - t) * (1.0 - t)  # Ease Out
		3: return t * t * (3.0 - 2.0 * t)  # Smooth Step
		_: return t
