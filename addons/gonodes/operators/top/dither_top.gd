class_name DitherTOP
extends GNTopBase
## Applies ordered (Bayer) dithering to reduce color depth with a pattern.


func _init() -> void:
	node_type = "dither"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Dithered texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("levels", 2, 2, 256,
		"Levels", "Number of output color levels (2 = pure 1-bit)"))
	add_parameter(GNParameter.create_enum("matrix_size",
		PackedStringArray(["2x2", "4x4", "8x8"]), 1,
		"Matrix Size", "Bayer matrix size (larger = finer pattern)"))
	add_parameter(GNParameter.create_float("spread", 0.5, 0.0, 1.0, 0.01,
		"Spread", "Dither pattern strength"))
	add_parameter(GNParameter.create_bool("color_dither", false,
		"Color", "Dither in color (true) or grayscale (false)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("DitherTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/dither.gdshader", true, true, res)

	_ensure_viewport_size(res)

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("levels", get_param_value("levels"))
	_material.set_shader_parameter("matrix_size", get_param_value("matrix_size"))
	_material.set_shader_parameter("spread", get_param_value("spread"))
	_material.set_shader_parameter("color_dither", get_param_value("color_dither"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
