class_name PaletteTOP
extends GNTopBase
## Quantizes an input image to the nearest colors in a palette texture.
## Supports optional ordered (Bayer) dithering before quantization.


func _init() -> void:
	node_type = "palette"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Source input texture", "In")
	add_input("palette", GNFamily.Type.TOP, false, "1D palette / ramp texture", "Palette")
	add_output("out", GNFamily.Type.TOP, "Palette-quantized texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("palette_size", 8, 2, 256, "Palette Size", "Number of colors in the palette"))
	add_parameter(GNParameter.create_bool("dither", false, "Dither", "Enable ordered Bayer dithering"))
	add_parameter(GNParameter.create_float("dither_strength", 0.5, 0.0, 1.0, 0.01, "Dither Strength", "Strength of the dithering noise"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("PaletteTOP", "'%s' — no valid input on port in" % id)
		return null

	var tex_pal: GNTextureData = _get_input_top(inputs, 1)

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/palette.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)

	if tex_pal != null:
		_material.set_shader_parameter("palette_tex", tex_pal.texture)

	_material.set_shader_parameter("palette_size", get_param_value("palette_size"))
	_material.set_shader_parameter("dither", get_param_value("dither"))
	_material.set_shader_parameter("dither_strength", get_param_value("dither_strength"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
