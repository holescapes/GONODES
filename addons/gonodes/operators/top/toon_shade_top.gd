class_name ToonShadeTOP
extends GNTopBase
## Cel shading effect — quantized color levels with Sobel edge outlines.


func _init() -> void:
	node_type = "toon_shade"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Cel-shaded texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("shade_levels", 4, 2, 16,
		"Shade Levels", "Number of quantized shading steps"))
	add_parameter(GNParameter.create_float("edge_strength", 1.5, 0.0, 5.0, 0.1,
		"Edge Strength", "Outline detection sensitivity"))
	add_parameter(GNParameter.create_float("edge_threshold", 0.1, 0.0, 1.0, 0.01,
		"Edge Threshold", "Minimum edge magnitude to draw outline"))
	add_parameter(GNParameter.create_color("edge_color", Color.BLACK,
		"Edge Color", "Outline color"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("ToonShadeTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/toon_shade.gdshader", true, true, res)

	_ensure_viewport_size(res)

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("shade_levels", get_param_value("shade_levels"))
	_material.set_shader_parameter("edge_strength", get_param_value("edge_strength"))
	_material.set_shader_parameter("edge_threshold", get_param_value("edge_threshold"))
	_material.set_shader_parameter("edge_color", get_param_value("edge_color"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
