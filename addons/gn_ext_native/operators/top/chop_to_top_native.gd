class_name CHOPtoTOPNative
extends GNTopBase
## Native-accelerated CHOP→TOP — delegates to GNNativeChopToTop (C++).

var _processor: RefCounted = null


func _init() -> void:
	super._init()
	node_type = "choptotop"
	node_description = "Render CHOP channels as a texture — native C++ accelerated."
	if ClassDB.class_exists("GNNativeChopToTop"):
		_processor = ClassDB.instantiate("GNNativeChopToTop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, true, "Source CHOP channels")
	add_output("out", GNFamily.Type.TOP, "Rendered texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Waveform", "Heatmap", "Graph"]), 0, "Mode", ""))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 256), "Resolution", ""))
	add_parameter(GNParameter.create_color("background", Color(0.05, 0.05, 0.05, 1.0), "Background", ""))
	add_parameter(GNParameter.create_color("line_color", Color(0.2, 0.8, 0.2, 1.0), "Line Color", ""))
	add_parameter(GNParameter.create_float("line_width", 2.0, 1.0, 8.0, 1.0, "Line Width", ""))
	add_parameter(GNParameter.create_float("min_val", -1.0, -1000.0, 1000.0, 0.1, "Min Value", ""))
	add_parameter(GNParameter.create_float("max_val", 1.0, -1000.0, 1000.0, 0.1, "Max Value", ""))
	add_parameter(GNParameter.create_bool("auto_range", true, "Auto Range", ""))


func _cook(inputs: Array[GNData]) -> GNData:
	var chop: GNChannelData = inputs[0] as GNChannelData if inputs.size() > 0 and inputs[0] is GNChannelData else null
	if chop == null or chop.channels.is_empty():
		return null

	var res: Vector2i = get_param_value("resolution")
	var min_v: float = get_param_value("min_val")
	var max_v: float = get_param_value("max_val")

	var ch_names: PackedStringArray = PackedStringArray(chop.channels.keys())
	if ch_names.is_empty():
		return null

	if get_param_value("auto_range"):
		min_v = INF
		max_v = -INF
		for ch_name in ch_names:
			var data: PackedFloat32Array = chop.channels[ch_name]
			for val in data:
				min_v = minf(min_v, val)
				max_v = maxf(max_v, val)
		if absf(max_v - min_v) < 0.0001:
			min_v -= 0.5
			max_v += 0.5

	if not _processor:
		return null

	var img: Image = _processor.process(chop.channels, ch_names,
		get_param_value("mode"), res.x, res.y,
		get_param_value("background"), get_param_value("line_color"),
		get_param_value("line_width"), min_v, max_v)

	if img == null:
		return null

	var tex := ImageTexture.create_from_image(img)
	if _cached_tex_data == null:
		_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = tex
	_cached_tex_data.resolution = res
	return _cached_tex_data
