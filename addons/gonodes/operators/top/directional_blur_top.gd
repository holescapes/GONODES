class_name DirectionalBlurTOP
extends GNTopBase
## Motion blur along an arbitrary angle.


func _init() -> void:
	node_type = "directional_blur"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Blurred texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("strength", 10.0, 0.0, 100.0, 0.5,
		"Strength", "Blur distance in pixels"))
	add_parameter(GNParameter.create_float("angle", 0.0, 0.0, 360.0, 1.0,
		"Angle", "Blur direction in degrees (0 = horizontal right)"))
	add_parameter(GNParameter.create_int("samples", 16, 3, 64,
		"Samples", "Number of blur samples (more = smoother, slower)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("DirectionalBlurTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/directional_blur.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("strength", get_param_value("strength"))
	_material.set_shader_parameter("angle", get_param_value("angle"))
	_material.set_shader_parameter("samples", get_param_value("samples"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
