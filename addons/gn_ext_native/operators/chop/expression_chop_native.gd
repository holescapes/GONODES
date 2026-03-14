class_name ExpressionCHOPNative
extends GNChopBase
## Native-accelerated expression CHOP — delegates to GNNativeExpressionChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "expression"
	time_dependent = true
	node_description = "Evaluate per-channel math expressions — native C++ accelerated."
	if ClassDB.class_exists("GNNativeExpressionChop"):
		_processor = ClassDB.instantiate("GNNativeExpressionChop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, true, "Input channels (optional)")
	add_output("out", GNFamily.Type.CHOP, "Expression result")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("expr", "sin(t * 3.0)", "Expression", ""))
	add_parameter(GNParameter.create_int("samples", 1, 1, 10000, "Samples", ""))
	add_parameter(GNParameter.create_string("channels", "chan1", "Channel names (comma-sep)", ""))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	var expr_str: String = get_param_value("expr")
	var t: float = elapsed_time
	var dt: float = current_delta

	var out: GNChannelData = _prepare_output(60.0 if in_data == null else in_data.sample_rate)

	var channel_list: PackedStringArray
	var base_length: int

	if in_data != null:
		channel_list = in_data.get_channel_names()
		base_length = in_data.length
	else:
		channel_list = PackedStringArray()
		for part in get_param_value("channels").split(","):
			var trimmed: String = part.strip_edges()
			if not trimmed.is_empty():
				channel_list.append(trimmed)
		base_length = maxi(get_param_value("samples"), 1)

	if channel_list.is_empty() or not _processor:
		return out

	var in_channels: Dictionary = {}
	if in_data:
		in_channels = in_data.channels

	var result: Dictionary = _processor.process(expr_str, in_channels, channel_list,
		base_length, t, dt)

	if result.has("error"):
		return out

	for ch_name in channel_list:
		if result.has(ch_name):
			out.set_channel(ch_name, result[ch_name])

	out.length = base_length
	return out
