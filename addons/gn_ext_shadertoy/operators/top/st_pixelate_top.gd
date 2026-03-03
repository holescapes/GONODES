extends "res://addons/gn_ext_shadertoy/operators/top/shadertoy_base_top.gd"
## Mosaic / pixelation post-processing effect.


func _init() -> void:
	node_type = "st_pixelate"
	time_dependent = false
	node_description = "Mosaic pixelation of input texture. Original GONODES."
	_shader_path = "res://addons/gn_ext_shadertoy/shaders/st_pixelate.gdshader"
	_shadertoy_url = ""
	_credits = "Original GONODES — inspired by various Shadertoy mosaic shaders"
	_is_generator = false
	_input_tex_count = 1


func _init_parameters() -> void:
	super._init_parameters()
	add_parameter(GNParameter.create_float("pixel_size", 8.0, 1.0, 128.0, 1.0,
		"Pixel Size", "Mosaic block size in pixels"))


func _cook(inputs: Array[GNData]) -> GNData:
	var result := super._cook(inputs)
	if result == null:
		return null
	_material.set_shader_parameter("pixel_size", get_param_value("pixel_size"))
	return result
