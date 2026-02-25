class_name ConstantCHOP
extends GNNode
## Outputs one or more channels with constant (static) values.
## Each channel name and value can be configured via parameters.

var _cached_channel_data: GNChannelData = null


func _init() -> void:
	node_type = "constant"
	family = GNFamily.Type.CHOP
	node_description = "Output constant channel values."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Channel data output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("name0", "chan1", "", "Name for channel slot 0"))
	add_parameter(GNParameter.create_float("value0", 0.0, null, null, 0.01, "", "Constant value for channel 0"))
	add_parameter(GNParameter.create_string("name1", "", "", "Name for channel slot 1 (empty = skip)"))
	add_parameter(GNParameter.create_float("value1", 0.0, null, null, 0.01, "", "Constant value for channel 1"))
	add_parameter(GNParameter.create_string("name2", "", "", "Name for channel slot 2 (empty = skip)"))
	add_parameter(GNParameter.create_float("value2", 0.0, null, null, 0.01, "", "Constant value for channel 2"))


func _cook(_inputs: Array[GNData]) -> GNData:
	if _cached_channel_data == null:
		_cached_channel_data = GNChannelData.new()
	else:
		_cached_channel_data.channels.clear()
		_cached_channel_data.length = 0
	_cached_channel_data.sample_rate = 60.0

	for i in range(3):
		var ch_name: String = get_param_value("name%d" % i)
		if ch_name.is_empty():
			continue
		var ch_val: float = get_param_value("value%d" % i)
		_cached_channel_data.set_single_value(ch_name, ch_val)

	return _cached_channel_data
