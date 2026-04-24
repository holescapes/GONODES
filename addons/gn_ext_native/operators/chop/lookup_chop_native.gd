class_name LookupCHOPNative
extends GNChopBase
## Native-accelerated table lookup — delegates to GNNativeLookupChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "lookup_native"
	node_description = "Table lookup using one channel to index another — native C++ accelerated."
	if ClassDB.class_exists("GNNativeLookupChop"):
		_processor = ClassDB.instantiate("GNNativeLookupChop")


func _init_ports() -> void:
	add_input("table", GNFamily.Type.CHOP, false, "Lookup table channel")
	add_input("index", GNFamily.Type.CHOP, false, "Index channel (0..1)")
	add_output("out", GNFamily.Type.CHOP, "Looked-up values")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("interpolation",
		PackedStringArray(["Linear", "Nearest"]), 0, "Interpolation", ""))
	add_parameter(GNParameter.create_enum("extend",
		PackedStringArray(["Clamp", "Cycle", "Mirror"]), 0, "Extend", ""))


func _cook(inputs: Array[GNData]) -> GNData:
	var table_data: GNChannelData = _get_input_chop(inputs, 0)
	var index_data: GNChannelData = _get_input_chop(inputs, 1)
	if table_data == null or index_data == null:
		return null

	var out: GNChannelData = _prepare_output(index_data.sample_rate)
	if not _processor:
		return out

	var idx_names: PackedStringArray = index_data.get_channel_names()
	var result: Dictionary = _processor.process(table_data.channels,
		index_data.channels, idx_names,
		get_param_value("interpolation"), get_param_value("extend"))

	for key in result:
		if result[key] is PackedFloat32Array:
			out.set_channel(key, result[key])
	out.length = index_data.length
	return out
