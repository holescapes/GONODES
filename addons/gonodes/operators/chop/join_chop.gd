class_name JoinCHOP
extends GNChopBase
## Concatenates sample arrays from multiple CHOP inputs end-to-end.
## Matching channel names across inputs are joined in time.
## Uses dynamic auto-grow input ports.


func _init() -> void:
	node_type = "join"
	node_description = "Concatenate channels from multiple inputs in time."


func _init_ports() -> void:
	_enable_dynamic_inputs(GNFamily.Type.CHOP, "ch", "CHOP Input")
	add_output("out", GNFamily.Type.CHOP, "Joined channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("overlap", 0, 0, 10000, "Overlap",
		"Number of samples to crossfade between segments"))


func _cook(inputs: Array[GNData]) -> GNData:
	var overlap: int = maxi(get_param_value("overlap"), 0)

	# Gather all valid inputs in order
	var segments: Array[GNChannelData] = []
	var sr: float = 60.0
	for inp in inputs:
		var ch_data: GNChannelData = inp as GNChannelData if inp is GNChannelData else null
		if ch_data == null:
			continue
		segments.append(ch_data)
		sr = ch_data.sample_rate

	if segments.is_empty():
		return null

	var out: GNChannelData = _prepare_output(sr)

	# Collect all channel names across all segments
	var all_names: Dictionary = {}
	for seg in segments:
		for ch in seg.channels:
			all_names[ch] = true

	for ch_name in all_names:
		var result := PackedFloat32Array()

		for seg_idx in range(segments.size()):
			var seg: GNChannelData = segments[seg_idx]
			var samples: PackedFloat32Array = seg.channels.get(ch_name, PackedFloat32Array())
			if samples.is_empty():
				continue

			if result.is_empty() or overlap <= 0:
				result.append_array(samples)
			else:
				# Crossfade overlap region
				var xf: int = mini(overlap, mini(result.size(), samples.size()))
				var base_len: int = result.size()
				for i in range(xf):
					var t: float = float(i + 1) / float(xf + 1)
					result[base_len - xf + i] = lerpf(
						result[base_len - xf + i], samples[i], t)
				# Append non-overlapped portion
				if xf < samples.size():
					result.append_array(samples.slice(xf))

		out.set_channel(ch_name, result)

	return out
