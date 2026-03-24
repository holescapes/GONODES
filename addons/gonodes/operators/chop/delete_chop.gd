class_name DeleteCHOP
extends GNChopBase
## Removes channels by name pattern, index range, or keeps only matching ones.
## Inverse of SelectCHOP — designed for exclusion rather than inclusion.


func _init() -> void:
	node_type = "delete"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels")
	add_output("out", GNFamily.Type.CHOP, "Remaining channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("scope",
		PackedStringArray(["By Pattern", "By Index", "Keep Only Pattern"]),
		0, "", "What to delete / keep"))
	add_parameter(GNParameter.create_string("pattern", "chan1",
		"Name pattern (comma-separated, supports *)", "Channel names to delete/keep"))
	add_parameter(GNParameter.create_int("start_index", 0, 0, 999, "Start Index",
		"First channel index to delete (By Index mode)"))
	add_parameter(GNParameter.create_int("end_index", 0, 0, 999, "End Index",
		"Last channel index to delete (By Index mode, inclusive)"))


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
	var patterns: PackedStringArray = pattern.split(",")
	for i in range(patterns.size()):
		patterns[i] = patterns[i].strip_edges()

	for i in range(names.size()):
		var ch_name: String = names[i]
		var keep: bool = true

		match scope:
			0:  # By Pattern — delete matching
				if _matches(ch_name, patterns):
					keep = false
			1:  # By Index — delete range
				if i >= start_idx and i <= end_idx:
					keep = false
			2:  # Keep Only Pattern — delete non-matching
				if not _matches(ch_name, patterns):
					keep = false

		if keep:
			out.set_channel(ch_name, in_data.channels[ch_name])

	return out


func _matches(name: String, patterns: PackedStringArray) -> bool:
	for pat in patterns:
		if pat == "*" or pat == name:
			return true
		if pat.ends_with("*") and name.begins_with(pat.left(pat.length() - 1)):
			return true
		if pat.begins_with("*") and name.ends_with(pat.right(pat.length() - 1)):
			return true
	return false
