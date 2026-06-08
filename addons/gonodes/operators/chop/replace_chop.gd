class_name ReplaceCHOP
extends GNChopBase
## Replaces channels in the first input with matching channels from the second.
## Matching is done by channel name pattern (glob or exact).
## Non-matching channels pass through from the first input unchanged.


func _init() -> void:
	node_type = "replace"


func _init_ports() -> void:
	add_input("base", GNFamily.Type.CHOP, false, "Base channels (destination)", "Base")
	add_input("replace", GNFamily.Type.CHOP, false, "Replacement channels (source)", "Replace")
	add_output("out", GNFamily.Type.CHOP, "Output with replaced channels", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("pattern", "*",
		"Pattern", "Channel name pattern to match for replacement (glob: *, ?)"))
	add_parameter(GNParameter.create_float("blend", 1.0, 0.0, 1.0, 0.01,
		"Blend", "Blend between original (0) and replacement (1)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var base_data := _get_input_chop(inputs, 0)
	if base_data == null:
		return null

	var replace_data := _get_input_chop(inputs, 1)
	var pattern: String = get_param_value("pattern")
	var blend: float = get_param_value("blend")

	var out := _prepare_output(base_data.sample_rate)
	out.length = base_data.length

	# Copy all base channels
	for ch_name in base_data.channels:
		out.channels[ch_name] = base_data.channels[ch_name].duplicate()

	# Replace matching channels from second input
	if replace_data != null:
		for ch_name in replace_data.channels:
			if not _match_pattern(ch_name, pattern):
				continue
			var rep_samples: PackedFloat32Array = replace_data.channels[ch_name]
			if not out.channels.has(ch_name):
				out.channels[ch_name] = rep_samples.duplicate()
			elif blend >= 0.999:
				out.channels[ch_name] = rep_samples.duplicate()
			else:
				var base_samples: PackedFloat32Array = out.channels[ch_name]
				var max_len: int = maxi(base_samples.size(), rep_samples.size())
				var blended := PackedFloat32Array()
				blended.resize(max_len)
				for i in range(max_len):
					var bv: float = base_samples[i] if i < base_samples.size() else 0.0
					var rv: float = rep_samples[i] if i < rep_samples.size() else 0.0
					blended[i] = lerpf(bv, rv, blend)
				out.channels[ch_name] = blended

	return out


func _match_pattern(name: String, pattern: String) -> bool:
	if pattern == "*" or pattern.is_empty():
		return true
	return name.match(pattern)
