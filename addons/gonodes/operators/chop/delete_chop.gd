class_name DeleteCHOP
extends GNChopBase
## Removes channels by name pattern, index range, or keeps only matching ones.
## Inverse of SelectCHOP — designed for exclusion rather than inclusion.


func _init() -> void:
	node_type = "delete"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels", "In")
	add_output("out", GNFamily.Type.CHOP, "Remaining channels", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("scope",
		PackedStringArray(["By Pattern", "By Index", "Keep Only Pattern", "By Index Range"]),
		0, "", "What to delete / keep"))
	add_parameter(GNParameter.create_string("pattern", "chan1",
		"Name pattern (comma-separated, supports *, ?, [abc], !exclude)", "Channel names to delete/keep"))
	add_parameter(GNParameter.create_int("start_index", 0, 0, 999, "Start Index",
		"First channel index to delete (By Index mode)"))
	add_parameter(GNParameter.create_int("end_index", 0, 0, 999, "End Index",
		"Last channel index to delete (By Index mode, inclusive)"))
	add_parameter(GNParameter.create_string("index_range", "0-10:2",
		"Index Range", "Range expression: 0-10, 0-10:2, *:3, !5-10 (By Index Range mode)"))
	parameters["index_range"].visibility_rule = {"param": "scope", "values": [3]}


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var scope: int = get_param_value("scope")
	var pattern: String = get_param_value("pattern")
	var start_idx: int = get_param_value("start_index")
	var end_idx: int = get_param_value("end_index")

	var out: GNChannelData = _prepare_output(in_data.sample_rate)

	var names: PackedStringArray = in_data.get_channel_names()

	# Pre-compute index range set for mode 3
	var idx_range_set: Dictionary = {}
	if scope == 3:
		var range_str: String = get_param_value("index_range")
		var indices := GNPattern.parse_index_range(range_str, names.size())
		for idx in indices:
			idx_range_set[idx] = true

	for i in range(names.size()):
		var ch_name: String = names[i]
		var keep: bool = true

		match scope:
			0:  # By Pattern — delete matching
				if GNPattern.matches_any(ch_name, pattern):
					keep = false
			1:  # By Index — delete range
				if i >= start_idx and i <= end_idx:
					keep = false
			2:  # Keep Only Pattern — delete non-matching
				if not GNPattern.matches_any(ch_name, pattern):
					keep = false
			3:  # By Index Range — delete by range expression
				if idx_range_set.has(i):
					keep = false

		if keep:
			out.set_channel(ch_name, in_data.channels[ch_name])

	return out


# Pattern matching now delegated to GNPattern (see addons/gonodes/core/gn_pattern.gd)
