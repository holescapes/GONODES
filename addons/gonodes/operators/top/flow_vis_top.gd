class_name FlowVisTOP
extends GNTopBase
## Visualizes a 2-channel vector field (e.g. CurlNoiseTOP output) using Line Integral Convolution.
## Produces streaky, organic flow images with directional HSV coloring.
## Input must encode velocity as R=X, G=Y in [0,1] range (0.5 = zero velocity).


func _init() -> void:
	node_type = "flow_vis"


func _init_ports() -> void:
	add_input("field", GNFamily.Type.TOP, false, "Vector field texture (RG = XY velocity)", "Field")
	add_output("out", GNFamily.Type.TOP, "Flow visualization", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("num_steps", 24, 4, 64,
		"Steps", "LIC integration steps (more = longer streaks)"))
	add_parameter(GNParameter.create_float("step_size", 0.004, 0.0005, 0.02, 0.0005,
		"Step Size", "Distance per integration step in UV space"))
	add_parameter(GNParameter.create_float("noise_scale", 80.0, 1.0, 200.0, 1.0,
		"Noise Scale", "Base noise frequency for LIC texture"))
	add_parameter(GNParameter.create_enum("color_mode",
		PackedStringArray(["Magnitude", "Direction", "LIC Only", "LIC + Direction"]), 3,
		"Color Mode", "How the flow field is colorized"))
	add_parameter(GNParameter.create_float("contrast", 1.8, 0.5, 4.0, 0.1,
		"Contrast", "LIC streak contrast"))
	add_parameter(GNParameter.create_float("brightness", 1.0, 0.0, 2.0, 0.05,
		"Brightness", "Overall brightness"))
	add_parameter(GNParameter.create_float("saturation", 0.75, 0.0, 1.0, 0.05,
		"Saturation", "Color saturation for directional modes"))
	add_parameter(GNParameter.create_float("speed_tint", 1.5, 0.0, 4.0, 0.1,
		"Speed Tint", "How much velocity magnitude affects brightness"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("FlowVisTOP", "'%s' — no vector field input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/flow_vis.gdshader", true, false, res)

	if _viewport.size != res:
		_viewport.size = res

	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("num_steps", get_param_value("num_steps"))
	_material.set_shader_parameter("step_size", get_param_value("step_size"))
	_material.set_shader_parameter("noise_scale", get_param_value("noise_scale"))
	_material.set_shader_parameter("color_mode", get_param_value("color_mode"))
	_material.set_shader_parameter("contrast", get_param_value("contrast"))
	_material.set_shader_parameter("brightness", get_param_value("brightness"))
	_material.set_shader_parameter("saturation", get_param_value("saturation"))
	_material.set_shader_parameter("speed_tint", get_param_value("speed_tint"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
