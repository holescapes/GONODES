class_name GodRaysTOP
extends GNTopBase
## Generates crepuscular rays (god rays / volumetric light shafts) from
## bright areas toward a configurable light source position.


func _init() -> void:
	node_type = "god_rays"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Texture with light rays")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2("light_pos", Vector2(0.5, 0.3),
		"Light Position", "UV position of the light source"))
	add_parameter(GNParameter.create_int("samples", 64, 8, 128,
		"Samples", "Ray march samples (more = smoother, slower)"))
	add_parameter(GNParameter.create_float("density", 1.0, 0.1, 3.0, 0.05,
		"Density", "Controls how far rays extend"))
	add_parameter(GNParameter.create_float("weight", 0.01, 0.001, 0.1, 0.001,
		"Weight", "Per-sample contribution"))
	add_parameter(GNParameter.create_float("decay", 0.97, 0.9, 1.0, 0.005,
		"Decay", "Sample falloff (lower = rays fade faster)"))
	add_parameter(GNParameter.create_float("exposure", 1.0, 0.0, 5.0, 0.1,
		"Exposure", "Final ray brightness multiplier"))
	add_parameter(GNParameter.create_float("threshold", 0.5, 0.0, 1.0, 0.01,
		"Threshold", "Luminance threshold for bright areas that emit rays"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("GodRaysTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/god_rays.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("light_pos", get_param_value("light_pos"))
	_material.set_shader_parameter("num_samples", get_param_value("samples"))
	_material.set_shader_parameter("density", get_param_value("density"))
	_material.set_shader_parameter("weight", get_param_value("weight"))
	_material.set_shader_parameter("decay", get_param_value("decay"))
	_material.set_shader_parameter("exposure", get_param_value("exposure"))
	_material.set_shader_parameter("threshold", get_param_value("threshold"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
