class_name HalftoneTOP
extends GNTopBase
## Converts an image into a halftone dot pattern (BW or CMYK).


func _init() -> void:
	node_type = "halftone"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Halftone output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("dot_size", 8.0, 1.0, 50.0, 0.5,
		"Dot Size", "Size of halftone dots in pixels"))
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["BW", "CMYK"]), 0,
		"", "BW = black & white dots, CMYK = color separation"))
	add_parameter(GNParameter.create_float("angle_c", 15.0, 0.0, 90.0, 1.0,
		"Angle C", "Cyan screen angle (CMYK mode)"))
	add_parameter(GNParameter.create_float("angle_m", 75.0, 0.0, 90.0, 1.0,
		"Angle M", "Magenta screen angle (CMYK mode)"))
	add_parameter(GNParameter.create_float("angle_y", 0.0, 0.0, 90.0, 1.0,
		"Angle Y", "Yellow screen angle (CMYK mode)"))
	add_parameter(GNParameter.create_float("angle_k", 45.0, 0.0, 90.0, 1.0,
		"Angle K", "Black/key screen angle"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("HalftoneTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/halftone.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("dot_size", get_param_value("dot_size"))
	_material.set_shader_parameter("mode", get_param_value("mode"))
	_material.set_shader_parameter("angle_c", get_param_value("angle_c"))
	_material.set_shader_parameter("angle_m", get_param_value("angle_m"))
	_material.set_shader_parameter("angle_y", get_param_value("angle_y"))
	_material.set_shader_parameter("angle_k", get_param_value("angle_k"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
