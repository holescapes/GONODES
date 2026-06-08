class_name BilateralBlurTOP
extends GNTopBase
## Edge-preserving blur that smooths flat regions while keeping edges sharp.


func _init() -> void:
	node_type = "bilateral_blur"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Smoothed texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("radius", 3, 1, 10,
		"Radius", "Blur kernel radius in pixels"))
	add_parameter(GNParameter.create_float("sigma_spatial", 3.0, 0.1, 20.0, 0.1,
		"Spatial Sigma", "Spatial Gaussian spread"))
	add_parameter(GNParameter.create_float("sigma_range", 0.1, 0.01, 1.0, 0.01,
		"Range Sigma", "Intensity similarity threshold (lower = sharper edges)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("BilateralBlurTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/bilateral_blur.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("radius", get_param_value("radius"))
	_material.set_shader_parameter("sigma_spatial", get_param_value("sigma_spatial"))
	_material.set_shader_parameter("sigma_range", get_param_value("sigma_range"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
