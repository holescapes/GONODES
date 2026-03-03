extends "res://addons/gn_ext_shadertoy/operators/top/shadertoy_base_top.gd"
## CRT monitor effect — barrel distortion, scanlines, vignette.


func _init() -> void:
	node_type = "st_crt"
	time_dependent = false
	node_description = "CRT monitor barrel distortion with scanlines and vignette. Original GONODES."
	_shader_path = "res://addons/gn_ext_shadertoy/shaders/st_crt.gdshader"
	_shadertoy_url = ""
	_credits = "Original GONODES — inspired by various Shadertoy CRT shaders"
	_is_generator = false
	_input_tex_count = 1


func _init_parameters() -> void:
	super._init_parameters()
	add_parameter(GNParameter.create_float("curvature", 4.0, 0.0, 20.0, 0.1,
		"Curvature", "Barrel distortion strength (0 = flat)"))
	add_parameter(GNParameter.create_float("scanline_weight", 0.15, 0.0, 1.0, 0.01,
		"Scanline Weight", "Scanline darkness intensity"))
	add_parameter(GNParameter.create_float("vignette_strength", 0.4, 0.0, 2.0, 0.01,
		"Vignette", "Vignette darkening power"))


func _cook(inputs: Array[GNData]) -> GNData:
	var result := super._cook(inputs)
	if result == null:
		return null
	_material.set_shader_parameter("curvature", get_param_value("curvature"))
	_material.set_shader_parameter("scanline_weight", get_param_value("scanline_weight"))
	_material.set_shader_parameter("vignette_strength", get_param_value("vignette_strength"))
	return result
