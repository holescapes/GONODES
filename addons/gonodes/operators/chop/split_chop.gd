class_name SplitCHOP
extends GNChopBase
## Splits a multi-channel CHOP into individual single-channel outputs.
## Since GONODES has single output, this outputs one selected channel at a time
## or packs channels as ch0, ch1, etc. with a specified group size.


func _init() -> void:
	node_type = "split"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels", "In")
	add_output("out", GNFamily.Type.CHOP, "Split channels", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Select One", "Group by N"]), 0, "",
		"Split mode"))
	add_parameter(GNParameter.create_int("index", 0, 0, 999, "Channel Index",
		"Which channel to extract (Select One mode)"))
	add_parameter(GNParameter.create_int("group_size", 3, 1, 64, "Group Size",
		"Channels per group (Group by N mode)"))
	add_parameter(GNParameter.create_int("group_index", 0, 0, 999, "Group Index",
		"Which group to output (Group by N mode)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var mode: int = get_param_value("mode")
	var out: GNChannelData = _prepare_output(in_data.sample_rate)

	var names: PackedStringArray = in_data.get_channel_names()
	if names.is_empty():
		return null

	if mode == 0:
		# Select one channel by index
		var idx: int = clampi(get_param_value("index"), 0, names.size() - 1)
		out.set_channel(names[idx], in_data.channels[names[idx]])
	else:
		# Group by N
		var gsize: int = maxi(get_param_value("group_size"), 1)
		var gidx: int = get_param_value("group_index")
		var start: int = gidx * gsize
		var end_idx: int = mini(start + gsize, names.size())

		if start >= names.size():
			return null

		for i in range(start, end_idx):
			out.set_channel(names[i], in_data.channels[names[i]])

	return out
