class_name LensDistortTOP
extends GNTopBase
## Barrel / pincushion / fisheye lens distortion with optional chromatic aberration.


func _init() -> void:
	node_type = "lens_distort"
	node_description = "Barrel, pincushion, and fisheye lens distortion with chromatic aberration."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Distorted texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("k1", 0.2, -2.0, 2.0, 0.01, "K1",
		"Radial distortion (positive = barrel, negative = pincushion)"))
	add_parameter(GNParameter.create_float("k2", 0.0, -1.0, 1.0, 0.01, "K2",
		"Higher-order radial distortion"))
	add_parameter(GNParameter.create_float("chromatic_aberration", 0.0, 0.0, 5.0, 0.01,
		"Chromatic Ab.", "RGB channel separation for colour fringing"))
	add_parameter(GNParameter.create_color("bg_color", Color(0, 0, 0, 0), "Background",
		"Fill colour for areas outside the distortion"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("LensDistortTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/lens_distort.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	var bg: Color = get_param_value("bg_color")

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("k1", get_param_value("k1"))
	_material.set_shader_parameter("k2", get_param_value("k2"))
	_material.set_shader_parameter("chromatic_aberration", get_param_value("chromatic_aberration"))
	_material.set_shader_parameter("bg_color", Vector4(bg.r, bg.g, bg.b, bg.a))

	_cached_tex_data.resolution = res
	return _cached_tex_data
