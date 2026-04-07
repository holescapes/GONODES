class_name GlitchTOP
extends GNTopBase
## Digital glitch effect — block displacement, channel shift, and artifacts.


func _init() -> void:
	node_type = "glitch"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Glitched texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("intensity", 0.3, 0.0, 1.0, 0.01,
		"Intensity", "Probability and strength of glitch blocks"))
	add_parameter(GNParameter.create_float("block_size", 32.0, 4.0, 128.0, 1.0,
		"Block Size", "Glitch block size in pixels"))
	add_parameter(GNParameter.create_float("channel_shift", 0.01, 0.0, 0.05, 0.001,
		"Channel Shift", "RGB channel separation amount"))
	add_parameter(GNParameter.create_float("speed", 8.0, 0.1, 30.0, 0.1,
		"Speed", "Glitch animation speed"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("GlitchTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/glitch.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("intensity", get_param_value("intensity"))
	_material.set_shader_parameter("block_size", get_param_value("block_size"))
	_material.set_shader_parameter("channel_shift", get_param_value("channel_shift"))
	_material.set_shader_parameter("speed", get_param_value("speed"))
	_material.set_shader_parameter("time_val", elapsed_time)

	_cached_tex_data.resolution = res
	return _cached_tex_data
