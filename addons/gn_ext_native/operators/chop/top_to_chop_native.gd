class_name TOPtoCHOPNative
extends GNChopBase
## Native-accelerated TOP→CHOP — delegates to GNNativeTopToChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "toptochop"
	node_description = "Sample TOP texture pixels as CHOP channels — native C++ accelerated."
	if ClassDB.class_exists("GNNativeTopToChop"):
		_processor = ClassDB.instantiate("GNNativeTopToChop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Source TOP texture")
	add_output("out", GNFamily.Type.CHOP, "Sampled colour channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Average", "CenterPixel", "RowAverage", "ColumnAverage"]), 0, "Mode", ""))
	add_parameter(GNParameter.create_bool("channel_r", true, "Red", ""))
	add_parameter(GNParameter.create_bool("channel_g", true, "Green", ""))
	add_parameter(GNParameter.create_bool("channel_b", true, "Blue", ""))
	add_parameter(GNParameter.create_bool("channel_a", false, "Alpha", ""))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_data: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_data == null or tex_data.texture == null:
		return null

	var img: Image = tex_data.texture.get_image()
	if img == null:
		return null

	var out: GNChannelData = _prepare_output(60.0)
	if not _processor:
		return out

	var result: Dictionary = _processor.process(img, get_param_value("mode"),
		get_param_value("channel_r"), get_param_value("channel_g"),
		get_param_value("channel_b"), get_param_value("channel_a"))

	for key in result:
		if key == "length":
			out.length = result[key]
		elif result[key] is PackedFloat32Array:
			out.set_channel(key, result[key])

	return out
