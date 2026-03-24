class_name ChannelMixTOP
extends GNTopBase
## Remap/swap RGBA channels with per-channel source selection and independent gain.
## Each output channel can pull from R, G, B, A, Luminance, Zero, or One.


func _init() -> void:
	node_type = "channel_mix"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Channel-remapped texture")


func _init_parameters() -> void:
	var sources := PackedStringArray(["Red", "Green", "Blue", "Alpha", "Luminance", "Zero", "One"])
	add_parameter(GNParameter.create_enum("r_source", sources, 0, "R Source", "Source channel for output Red"))
	add_parameter(GNParameter.create_enum("g_source", sources, 1, "G Source", "Source channel for output Green"))
	add_parameter(GNParameter.create_enum("b_source", sources, 2, "B Source", "Source channel for output Blue"))
	add_parameter(GNParameter.create_enum("a_source", sources, 3, "A Source", "Source channel for output Alpha"))
	add_parameter(GNParameter.create_float("r_gain", 1.0, 0.0, 4.0, 0.01, "R Gain", "Red channel gain"))
	add_parameter(GNParameter.create_float("g_gain", 1.0, 0.0, 4.0, 0.01, "G Gain", "Green channel gain"))
	add_parameter(GNParameter.create_float("b_gain", 1.0, 0.0, 4.0, 0.01, "B Gain", "Blue channel gain"))
	add_parameter(GNParameter.create_float("a_gain", 1.0, 0.0, 4.0, 0.01, "A Gain", "Alpha channel gain"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("ChannelMixTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/channel_mix.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("r_source", get_param_value("r_source"))
	_material.set_shader_parameter("g_source", get_param_value("g_source"))
	_material.set_shader_parameter("b_source", get_param_value("b_source"))
	_material.set_shader_parameter("a_source", get_param_value("a_source"))
	_material.set_shader_parameter("r_gain", get_param_value("r_gain"))
	_material.set_shader_parameter("g_gain", get_param_value("g_gain"))
	_material.set_shader_parameter("b_gain", get_param_value("b_gain"))
	_material.set_shader_parameter("a_gain", get_param_value("a_gain"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
