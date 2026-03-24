class_name SelectCHOP
extends GNChopBase
## Selects/renames specific channels from the input.
## Like TouchDesigner's Select CHOP — useful for picking out individual channels.


func _init() -> void:
	node_type = "select"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels")
	add_output("out", GNFamily.Type.CHOP, "Selected channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("pattern", "*",
		"Channel name pattern (* = all, comma-separated for multiple)", "Channel name filter pattern"))
	add_parameter(GNParameter.create_string("rename", "",
		"Rename pattern (leave empty to keep names)", "New names for selected channels"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = inputs[0] as GNChannelData if inputs.size() > 0 and inputs[0] is GNChannelData else null
	if in_data == null:
		GNLogger.warn("SelectCHOP", "'%s' — no valid input" % id)
		return null

	var pattern: String = get_param_value("pattern")
	var rename_pat: String = get_param_value("rename")

	if _cached_channel_data == null:
		_cached_channel_data = GNChannelData.new()
	else:
		_cached_channel_data.channels.clear()
		_cached_channel_data.length = 0
	_cached_channel_data.sample_rate = in_data.sample_rate

	var patterns: PackedStringArray = pattern.split(",")
	for i in range(patterns.size()):
		patterns[i] = patterns[i].strip_edges()

	var rename_list: PackedStringArray = rename_pat.split(",") if not rename_pat.is_empty() else PackedStringArray()
	for i in range(rename_list.size()):
		rename_list[i] = rename_list[i].strip_edges()

	var match_idx: int = 0
	for ch_name in in_data.channels:
		if _matches_pattern(ch_name, patterns):
			var out_name: String = ch_name
			if match_idx < rename_list.size() and not rename_list[match_idx].is_empty():
				out_name = rename_list[match_idx]

			_cached_channel_data.set_channel(out_name, in_data.channels[ch_name])
			match_idx += 1

	return _cached_channel_data


func _matches_pattern(ch_name: String, patterns: PackedStringArray) -> bool:
	for pat in patterns:
		if pat == "*":
			return true
		if pat == ch_name:
			return true
		# Simple wildcard matching (prefix*)
		if pat.ends_with("*"):
			var prefix: String = pat.left(pat.length() - 1)
			if ch_name.begins_with(prefix):
				return true
		# (*suffix)
		if pat.begins_with("*"):
			var suffix: String = pat.right(pat.length() - 1)
			if ch_name.ends_with(suffix):
				return true
	return false
