class_name SelectCHOP
extends GNChopBase
## Selects channels from a CHOP — by wire OR by wireless name reference.
##
## When the 'chop' parameter names a remote CHOP, its output is used as
## the source (no wire needed).  When 'chop' is empty, the wired input is
## used instead.  Channel name filtering ('pattern') and optional renaming
## apply in both modes.
##
## Matches TouchDesigner's Select CHOP: remote reference + channel filter.

var _network_cache: GNNetwork = null


func _init() -> void:
	node_type = "select"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels (used when 'chop' is empty)")
	add_output("out", GNFamily.Type.CHOP, "Selected channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_node_ref("chop", GNFamily.Type.CHOP,
		"CHOP", "Name (id) of a remote CHOP to reference (empty = use wired input)"))
	add_parameter(GNParameter.create_string("pattern", "*",
		"Channel name pattern (* = all, comma-separated for multiple)", "Channel name filter pattern"))
	add_parameter(GNParameter.create_string("rename", "",
		"Rename pattern (leave empty to keep names)", "New names for selected channels"))


func _cook(inputs: Array[GNData]) -> GNData:
	# Resolve source: wireless reference takes priority over wired input
	var in_data: GNChannelData = null
	var remote_id: String = get_param_value("chop")

	if not remote_id.is_empty():
		in_data = _resolve_remote_chop(remote_id)
	else:
		in_data = inputs[0] as GNChannelData if inputs.size() > 0 and inputs[0] is GNChannelData else null

	if in_data == null:
		if not remote_id.is_empty():
			node_warning = "Remote CHOP '%s' not found or has no output" % remote_id
		else:
			node_warning = ""
		GNLogger.warn("SelectCHOP", "'%s' — no valid input" % id)
		return null

	node_warning = ""

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


func _resolve_remote_chop(target_id: String) -> GNChannelData:
	if _network_cache == null or not is_instance_valid(_network_cache):
		var p = get_parent()
		while p != null and not (p is GNNetwork):
			p = p.get_parent()
		_network_cache = p as GNNetwork
	if _network_cache == null:
		return null
	var target: GNNode = _network_cache.get_node_by_id(target_id)
	if target == null or target.family != GNFamily.Type.CHOP:
		return null
	return target.cached_output as GNChannelData if target.cached_output is GNChannelData else null


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
