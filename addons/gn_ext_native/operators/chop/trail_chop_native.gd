class_name TrailCHOPNative
extends GNChopBase
## Native-accelerated trail recorder — delegates to GNNativeTrailChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "trail_native"
	time_dependent = true
	node_description = "Record input channels over time — native C++ accelerated."
	if ClassDB.class_exists("GNNativeTrailChop"):
		_processor = ClassDB.instantiate("GNNativeTrailChop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels to trail", "In")
	add_output("out", GNFamily.Type.CHOP, "Trailed channel history", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("length", 120, 2, 3600, "Length", "Frames to keep"))
	add_parameter(GNParameter.create_bool("active", true, "Active", "Enable/disable recording"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var trail_len: int = get_param_value("length")
	var active: bool = get_param_value("active")

	if not active:
		return _cached_channel_data if _cached_channel_data != null else _prepare_output(in_data.sample_rate)

	if _processor != null:
		var channels := {}
		for ch_name in in_data.channels:
			channels[ch_name] = in_data.channels[ch_name]
		var result: Dictionary = _processor.process(channels, trail_len)
		var out: GNChannelData = _prepare_output(in_data.sample_rate)
		for key in result:
			out.channels[key] = result[key]
		out.length = trail_len
		return out
	else:
		return null
