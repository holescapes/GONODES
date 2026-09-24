class_name FilmGrainTOP
extends GNTopBase
## Adds temporally-varying film grain noise over the image.


func _init() -> void:
	node_type = "film_grain"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Grainy texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("intensity", 0.15, 0.0, 1.0, 0.01,
		"Intensity", "Grain strength"))
	add_parameter(GNParameter.create_float("size", 1.0, 0.5, 4.0, 0.1,
		"Size", "Grain particle size (larger = coarser)"))
	add_parameter(GNParameter.create_bool("luminance_dependent", true,
		"Luminance Dependent", "More grain in midtones, less in highlights/shadows"))
	add_parameter(GNParameter.create_bool("colored", false,
		"Colored", "Independent RGB noise channels instead of monochromatic"))
	add_parameter(GNParameter.create_bool("manual_time", false,
		"Manual Time", "Control animation time manually instead of auto-animating"))
	add_parameter(GNParameter.create_float("time", 0.0, 0.0, 10000.0, 0.01,
		"Time", "Manual time value (only used when Manual Time is enabled)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("FilmGrainTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/film_grain.gdshader", true, true, res)

	_ensure_viewport_size(res)

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("intensity", get_param_value("intensity"))
	_material.set_shader_parameter("size", get_param_value("size"))
	var manual: bool = get_param_value("manual_time")
	var t: float = get_param_value("time") if manual else elapsed_time
	_material.set_shader_parameter("time_val", t)
	_material.set_shader_parameter("luminance_dependent", get_param_value("luminance_dependent"))
	_material.set_shader_parameter("colored", get_param_value("colored"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
