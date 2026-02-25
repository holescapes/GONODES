class_name CrossCHOP
extends GNNode
## Crossfades between two CHOP inputs channel-by-channel.
## Similar to TouchDesigner's Cross CHOP.

var _cached_channel_data: GNChannelData = null


func _init() -> void:
	node_type = "cross"
	family = GNFamily.Type.CHOP


func _init_ports() -> void:
	add_input("A", GNFamily.Type.CHOP)
	add_input("B", GNFamily.Type.CHOP)
	add_output("out", GNFamily.Type.CHOP)


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("cross", 0.5, 0.0, 1.0, 0.01, "Cross Value"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_a: GNChannelData = inputs[0] as GNChannelData if inputs.size() > 0 and inputs[0] is GNChannelData else null
	var in_b: GNChannelData = inputs[1] as GNChannelData if inputs.size() > 1 and inputs[1] is GNChannelData else null

	if in_a == null:
		GNLogger.warn("CrossCHOP", "'%s' — no valid input on port A" % id)
		return null

	var cross_val: float = get_param_value("cross")

	if _cached_channel_data == null:
		_cached_channel_data = GNChannelData.new()
	else:
		_cached_channel_data.channels.clear()
		_cached_channel_data.length = 0
	_cached_channel_data.sample_rate = in_a.sample_rate

	# Collect all channel names from both inputs
	var all_channels: Array[String] = []
	for ch_name in in_a.channels:
		if ch_name not in all_channels:
			all_channels.append(ch_name)
	if in_b != null:
		for ch_name in in_b.channels:
			if ch_name not in all_channels:
				all_channels.append(ch_name)

	for ch_name in all_channels:
		var has_a: bool = in_a.channels.has(ch_name)
		var has_b: bool = in_b != null and in_b.channels.has(ch_name)

		if has_a and has_b:
			var samples_a: PackedFloat32Array = in_a.channels[ch_name]
			var samples_b: PackedFloat32Array = in_b.channels[ch_name]
			var out_len: int = maxi(samples_a.size(), samples_b.size())
			var out_samples := PackedFloat32Array()
			out_samples.resize(out_len)

			for i in range(out_len):
				var a_val: float = samples_a[i] if i < samples_a.size() else 0.0
				var b_val: float = samples_b[i] if i < samples_b.size() else 0.0
				out_samples[i] = lerpf(a_val, b_val, cross_val)

			_cached_channel_data.set_channel(ch_name, out_samples)
		elif has_a:
			# Only A — blend towards 0
			var samples_a: PackedFloat32Array = in_a.channels[ch_name]
			var out_samples := PackedFloat32Array()
			out_samples.resize(samples_a.size())
			for i in range(samples_a.size()):
				out_samples[i] = lerpf(samples_a[i], 0.0, cross_val)
			_cached_channel_data.set_channel(ch_name, out_samples)
		elif has_b:
			# Only B — blend from 0
			var samples_b: PackedFloat32Array = in_b.channels[ch_name]
			var out_samples := PackedFloat32Array()
			out_samples.resize(samples_b.size())
			for i in range(samples_b.size()):
				out_samples[i] = lerpf(0.0, samples_b[i], cross_val)
			_cached_channel_data.set_channel(ch_name, out_samples)

	return _cached_channel_data
