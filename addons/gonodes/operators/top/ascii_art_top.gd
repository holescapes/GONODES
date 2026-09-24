class_name ASCIIArtTOP
extends GNTopBase
## Renders input as ASCII character art using brightness-to-character mapping.


func _init() -> void:
	node_type = "ascii_art"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "ASCII art texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("cell_size", 8.0, 4.0, 32.0, 1.0,
		"Cell Size", "Character cell size in pixels"))
	add_parameter(GNParameter.create_color("text_color", Color.WHITE,
		"Text Color", "Character foreground color"))
	add_parameter(GNParameter.create_color("bg_color", Color.BLACK,
		"Background", "Background fill color"))
	add_parameter(GNParameter.create_bool("color_mode", false,
		"Color Mode", "Tint characters with source image color"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("ASCIIArtTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/ascii_art.gdshader", true, true, res)

	_ensure_viewport_size(res)

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("cell_size", get_param_value("cell_size"))
	_material.set_shader_parameter("text_color", get_param_value("text_color"))
	_material.set_shader_parameter("bg_color", get_param_value("bg_color"))
	_material.set_shader_parameter("color_mode", get_param_value("color_mode"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
