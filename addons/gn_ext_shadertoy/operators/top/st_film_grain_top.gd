extends "res://addons/gn_ext_shadertoy/operators/top/shadertoy_base_top.gd"
## Animated film grain noise overlay.


func _init() -> void:
	node_type = "st_film_grain"
	time_dependent = true
	node_description = "Animated noise grain overlay on input texture. Original GONODES."
	_shader_path = "res://addons/gn_ext_shadertoy/shaders/st_film_grain.gdshader"
	_shadertoy_url = ""
	_credits = "Original GONODES — inspired by various Shadertoy film grain shaders"
	_is_generator = false
	_input_tex_count = 1


func _init_parameters() -> void:
	super._init_parameters()
	add_parameter(GNParameter.create_float("grain_intensity", 0.12, 0.0, 1.0, 0.01,
		"Grain Intensity", "Noise strength (0 = none, 1 = full noise)"))
	add_parameter(GNParameter.create_float("grain_speed", 1.0, 0.0, 10.0, 0.1,
		"Grain Speed", "Animation speed multiplier for noise pattern"))


func _cook(inputs: Array[GNData]) -> GNData:
	var result := super._cook(inputs)
	if result == null:
		return null
	_material.set_shader_parameter("grain_intensity", get_param_value("grain_intensity"))
	_material.set_shader_parameter("grain_speed", get_param_value("grain_speed"))
	return result
