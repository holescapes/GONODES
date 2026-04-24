class_name StretchCHOPNative
extends GNChopBase
## Native-accelerated channel resampling — delegates to GNNativeStretchChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "stretch_native"
	node_description = "Resample channels to a new length — native C++ accelerated."
	if ClassDB.class_exists("GNNativeStretchChop"):
		_processor = ClassDB.instantiate("GNNativeStretchChop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels")
	add_output("out", GNFamily.Type.CHOP, "Resampled channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("length", 100, 1, 100000, "Length", "New sample count"))
	add_parameter(GNParameter.create_enum("interpolation",
		PackedStringArray(["Linear", "Cubic", "Nearest"]), 0, "Interpolation", ""))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var out: GNChannelData = _prepare_output(in_data.sample_rate)
	var new_len: int = get_param_value("length")

	if not _processor:
		return out

	var result: Dictionary = _processor.process(in_data.channels, new_len,
		get_param_value("interpolation"))

	for key in result:
		if result[key] is PackedFloat32Array:
			out.set_channel(key, result[key])
	out.length = new_len
	return out
