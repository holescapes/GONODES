extends "res://addons/gn_ext_shadertoy/operators/top/shadertoy_base_top.gd"
## CMYK halftone dot pattern post-processing — translated from Shadertoy.


func _init() -> void:
	node_type = "st_halftone"
	time_dependent = false
	node_description = "CMYK halftone dot rendering. Shadertoy conversion."
	_shader_path = "res://addons/gn_ext_shadertoy/shaders/st_halftone.gdshader"
	_shadertoy_url = "https://www.shadertoy.com/view/Mdf3Dn"
	_credits = "\"CMYK Halftone\" by tsone"
	_is_generator = false
	_input_tex_count = 1


func _init_parameters() -> void:
	super._init_parameters()
	add_parameter(GNParameter.create_float("dot_size", 1.48, 0.1, 5.0, 0.01,
		"Dot Size", "CMYK halftone dot radius"))
	add_parameter(GNParameter.create_float("dot_scale", 10.0, 2.0, 50.0, 0.5,
		"Dot Scale", "Halftone grid cell size in pixels"))


func _cook(inputs: Array[GNData]) -> GNData:
	var result := super._cook(inputs)
	if result == null:
		return null
	_material.set_shader_parameter("dot_size", get_param_value("dot_size"))
	_material.set_shader_parameter("dot_scale", get_param_value("dot_scale"))
	return result
