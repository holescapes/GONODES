class_name ChannelFilterCHOP
extends GNChopBase
## Filters and optionally renames channels from a wired CHOP input.
##
## Use a glob pattern to select a subset of channels by name, then optionally
## rename them using capture patterns (*(N) syntax).
##
## Typical use after SelectCHOP to narrow a wireless reference to specific
## channels, or inline in any wired CHOP chain.
##
## Pattern examples:
##   *          — all channels (default)
##   tx, ty, tz — exactly those three channels
##   r*         — all channels starting with 'r'
##
## Rename examples:
##   out_*(1)   — prepend 'out_' to each matched channel name


func _init() -> void:
	node_type = "channel_filter"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels", "In")
	add_output("out", GNFamily.Type.CHOP, "Filtered channels", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("pattern", "*",
		"Pattern", "Channel name filter (* = all, comma-separated, e.g. 'tx,ty,tz')"))
	add_parameter(GNParameter.create_string("rename", "",
		"Rename", "Output rename pattern — empty keeps names. Supports *(N) capture groups."))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var pattern: String = get_param_value("pattern")
	var rename_pat: String = get_param_value("rename")

	if _cached_channel_data == null:
		_cached_channel_data = GNChannelData.new()
	else:
		_cached_channel_data.channels.clear()
		_cached_channel_data.length = 0
	_cached_channel_data.sample_rate = in_data.sample_rate

	var all_names := PackedStringArray()
	for ch_name in in_data.channels:
		all_names.append(ch_name)

	var rename_map: Dictionary = {}
	if not rename_pat.is_empty():
		rename_map = GNPattern.rename_batch(all_names, pattern, rename_pat)

	for ch_name in in_data.channels:
		if GNPattern.matches_any(ch_name, pattern):
			var out_name: String = rename_map.get(ch_name, ch_name)
			_cached_channel_data.set_channel(out_name, in_data.channels[ch_name])

	return _cached_channel_data
