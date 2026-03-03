extends "res://addons/gn_ext_shadertoy/operators/top/shadertoy_base_top.gd"
## RGB channel offset for chromatic aberration post-processing.


func _init() -> void:
	node_type = "st_chromatic_ab"
	time_dependent = false
	node_description = "Radial RGB channel offset (chromatic aberration). Original GONODES."
	_shader_path = "res://addons/gn_ext_shadertoy/shaders/st_chromatic_aberration.gdshader"
	_shadertoy_url = ""
	_credits = "Original GONODES — inspired by various Shadertoy chromatic aberration shaders"
	_is_generator = false
	_input_tex_count = 1


func _init_parameters() -> void:
	super._init_parameters()
	add_parameter(GNParameter.create_float("intensity", 3.0, 0.0, 50.0, 0.1,
		"Intensity", "Pixel offset amount for colour fringing"))
	add_parameter(GNParameter.create_float("radial_weight", 1.0, 0.0, 1.0, 0.01,
		"Radial Weight", "0 = uniform offset everywhere, 1 = stronger near edges"))


func _cook(inputs: Array[GNData]) -> GNData:
	var result := super._cook(inputs)
	if result == null:
		return null
	_material.set_shader_parameter("intensity", get_param_value("intensity"))
	_material.set_shader_parameter("radial_weight", get_param_value("radial_weight"))
	return result
