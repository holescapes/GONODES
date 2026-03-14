class_name CornerPinTOP
extends GNTopBase
## 4-point perspective warp — position each corner of the input texture
## independently to create perspective distortion effects.


func _init() -> void:
	node_type = "corner_pin"
	node_description = "4-point perspective warp for projection mapping and keystone correction."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture to warp")
	add_output("out", GNFamily.Type.TOP, "Warped texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2("top_left", Vector2(0.0, 0.0), "Top Left",
		"Top-left corner UV position"))
	add_parameter(GNParameter.create_vector2("top_right", Vector2(1.0, 0.0), "Top Right",
		"Top-right corner UV position"))
	add_parameter(GNParameter.create_vector2("bottom_left", Vector2(0.0, 1.0), "Bottom Left",
		"Bottom-left corner UV position"))
	add_parameter(GNParameter.create_vector2("bottom_right", Vector2(1.0, 1.0), "Bottom Right",
		"Bottom-right corner UV position"))
	add_parameter(GNParameter.create_color("bg_color", Color(0, 0, 0, 0), "Background",
		"Fill colour for areas outside the warp"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("CornerPinTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/corner_pin.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	var bg: Color = get_param_value("bg_color")

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("top_left", get_param_value("top_left"))
	_material.set_shader_parameter("top_right", get_param_value("top_right"))
	_material.set_shader_parameter("bottom_left", get_param_value("bottom_left"))
	_material.set_shader_parameter("bottom_right", get_param_value("bottom_right"))
	_material.set_shader_parameter("bg_color", Vector4(bg.r, bg.g, bg.b, bg.a))

	_cached_tex_data.resolution = res
	return _cached_tex_data
