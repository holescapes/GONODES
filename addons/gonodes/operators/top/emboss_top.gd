class_name EmbossTOP
extends GNTopBase
## Emboss convolution filter — creates a relief/bump texture effect.
## Uses a directional emboss kernel shader.

func _init() -> void:
	node_type = "emboss"
	node_description = "Emboss relief filter with adjustable angle and strength."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Embossed texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("strength", 1.0, 0.0, 5.0, 0.01,
		"Strength", "Emboss intensity"))
	add_parameter(GNParameter.create_float("angle", 135.0, 0.0, 360.0, 1.0,
		"Angle", "Light direction angle in degrees"))
	add_parameter(GNParameter.create_float("height", 0.5, 0.0, 2.0, 0.01,
		"Height", "Mid-gray offset (0.5 = neutral relief)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("EmbossTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/emboss.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("strength", get_param_value("strength"))
	_material.set_shader_parameter("angle", get_param_value("angle"))
	_material.set_shader_parameter("height", get_param_value("height"))

	if _canvas is TextureRect:
		(_canvas as TextureRect).texture = tex_in.texture

	_cached_tex_data.resolution = res
	return _cached_tex_data
