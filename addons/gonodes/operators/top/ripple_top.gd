class_name RippleTOP
extends GNTopBase
## Animated sinusoidal wave distortion — radial or directional.


func _init() -> void:
	node_type = "ripple"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Rippled texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("amplitude", 0.01, 0.0, 0.1, 0.001,
		"Amplitude", "Wave displacement amount"))
	add_parameter(GNParameter.create_float("frequency", 20.0, 1.0, 100.0, 0.5,
		"Frequency", "Number of wave cycles across the image"))
	add_parameter(GNParameter.create_float("speed", 5.0, 0.0, 20.0, 0.1,
		"Speed", "Wave animation speed"))
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Radial", "Directional"]), 0,
		"", "Wave pattern type"))
	add_parameter(GNParameter.create_vector2("center", Vector2(0.5, 0.5),
		"Center", "Radial wave origin"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("RippleTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/ripple.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("amplitude", get_param_value("amplitude"))
	_material.set_shader_parameter("frequency", get_param_value("frequency"))
	_material.set_shader_parameter("speed", get_param_value("speed"))
	_material.set_shader_parameter("mode", get_param_value("mode"))
	_material.set_shader_parameter("center", get_param_value("center"))
	_material.set_shader_parameter("time_val", elapsed_time)

	_cached_tex_data.resolution = res
	return _cached_tex_data
