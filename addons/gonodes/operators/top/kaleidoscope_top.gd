class_name KaleidoscopeTOP
extends GNTopBase
## N-fold angular mirror symmetry kaleidoscope effect.


func _init() -> void:
	node_type = "kaleidoscope"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Kaleidoscope texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("segments", 6, 2, 32,
		"Segments", "Number of mirror segments"))
	add_parameter(GNParameter.create_float("rotation", 0.0, 0.0, 360.0, 1.0,
		"Rotation", "Pattern rotation in degrees"))
	add_parameter(GNParameter.create_vector2("center", Vector2(0.5, 0.5),
		"Center", "Center point of the kaleidoscope"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("KaleidoscopeTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/kaleidoscope.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("segments", get_param_value("segments"))
	_material.set_shader_parameter("rotation", get_param_value("rotation"))
	_material.set_shader_parameter("center", get_param_value("center"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
