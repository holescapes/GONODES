class_name MatteTOP
extends GNTopBase
## Applies alpha from a second texture (matte) to a base image.
## Supports selecting which matte channel to use and optional premultiplication.


func _init() -> void:
	node_type = "matte"
	node_description = "Apply alpha from a second texture with channel selection."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Base input texture")
	add_input("matte", GNFamily.Type.TOP, false, "Alpha source texture")
	add_output("out", GNFamily.Type.TOP, "Matted texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("matte_channel",
		PackedStringArray(["Luminance", "Red", "Green", "Blue", "Alpha"]), 0,
		"Matte Channel", "Which channel of the matte texture to use as alpha"))
	add_parameter(GNParameter.create_bool("invert", false, "Invert", "Invert the matte value"))
	add_parameter(GNParameter.create_bool("premultiply", false, "Premultiply", "Multiply RGB by the new alpha"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_in == null:
		GNLogger.warn("MatteTOP", "'%s' — no valid input on port in" % id)
		return null

	var tex_matte: GNTextureData = _get_input_top(inputs, 1)

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/matte.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)

	if tex_matte != null:
		_material.set_shader_parameter("matte_tex", tex_matte.texture)

	_material.set_shader_parameter("matte_channel", get_param_value("matte_channel"))
	_material.set_shader_parameter("invert_matte", get_param_value("invert"))
	_material.set_shader_parameter("premultiply", get_param_value("premultiply"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
