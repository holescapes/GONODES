class_name FanCHOPNative
extends GNChopBase
## Native-accelerated channel fan — delegates to GNNativeFanChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "fan_native"
	node_description = "Fan a single channel into multiple with offset — native C++ accelerated."
	if ClassDB.class_exists("GNNativeFanChop"):
		_processor = ClassDB.instantiate("GNNativeFanChop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channel", "In")
	add_output("out", GNFamily.Type.CHOP, "Fanned channels", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("count", 4, 1, 64,
		"Count", "Number of output channels"))
	add_parameter(GNParameter.create_float("offset", 0.1, -100.0, 100.0, 0.01,
		"Offset", "Per-channel offset value"))
	add_parameter(GNParameter.create_enum("operation",
		PackedStringArray(["Add", "Multiply", "Phase Shift"]), 0,
		"Operation", "How offset is applied"))
	add_parameter(GNParameter.create_string("prefix", "ch",
		"Prefix", "Output channel name prefix"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null or not _processor:
		return null

	# Get first channel samples
	var names: PackedStringArray = in_data.get_channel_names()
	if names.is_empty():
		return null
	var src: PackedFloat32Array = in_data.get_channel(names[0])

	var result: Dictionary = _processor.process(src,
		get_param_value("count"), get_param_value("offset"),
		get_param_value("operation"), get_param_value("prefix"))

	var out: GNChannelData = _prepare_output(in_data.sample_rate)
	for ch_name in result:
		out.channels[ch_name] = result[ch_name]
	out.length = src.size()
	return out
