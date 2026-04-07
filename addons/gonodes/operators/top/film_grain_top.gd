class_name FilmGrainTOP
extends GNTopBase
## Adds temporally-varying film grain noise over the image.


func _init() -> void:
	node_type = "film_grain"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Grainy texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("intensity", 0.15, 0.0, 1.0, 0.01,
		"Intensity", "Grain strength"))
	add_parameter(GNParameter.create_float("size", 1.0, 0.5, 4.0, 0.1,
		"Size", "Grain particle size (larger = coarser)"))
	add_parameter(GNParameter.create_bool("luminance_dependent", true,
		"Luminance Dependent", "More grain in midtones, less in highlights/shadows"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("FilmGrainTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/film_grain.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("intensity", get_param_value("intensity"))
	_material.set_shader_parameter("size", get_param_value("size"))
	_material.set_shader_parameter("time_val", elapsed_time)
	_material.set_shader_parameter("luminance_dependent", get_param_value("luminance_dependent"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
