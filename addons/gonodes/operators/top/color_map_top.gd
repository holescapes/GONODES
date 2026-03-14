class_name ColorMapTOP
extends GNTopBase
## Remaps grayscale input through a color gradient (lookup texture).
## Uses a gradient TOP or ramp as the mapping source.


func _init() -> void:
	node_type = "color_map"
	node_description = "Remap grayscale values through a color gradient / ramp texture."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture (grayscale recommended)")
	add_input("gradient", GNFamily.Type.TOP, false, "Gradient / ramp texture for color mapping")
	add_output("out", GNFamily.Type.TOP, "Color-mapped texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("luma_mode",
		PackedStringArray(["Luminance", "Red", "Green", "Blue"]), 0, "Luma Mode",
		"Which channel or luminance formula to use as the lookup index"))
	add_parameter(GNParameter.create_float("intensity", 1.0, 0.0, 1.0, 0.01, "",
		"Blend between original (0) and mapped (1) colors"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("ColorMapTOP", "'%s' — no valid input" % id)
		return null

	var tex_grad: GNTextureData = _get_input_top(inputs, 1)

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/color_map.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)

	if tex_grad != null:
		_material.set_shader_parameter("gradient_tex", tex_grad.texture)

	_material.set_shader_parameter("luma_mode", get_param_value("luma_mode"))
	_material.set_shader_parameter("intensity", get_param_value("intensity"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
