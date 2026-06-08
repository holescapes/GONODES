class_name VignetteTOP
extends GNTopBase
## Darkens or tints image edges with adjustable falloff for a vignette effect.


func _init() -> void:
	node_type = "vignette"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Vignetted texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("intensity", 0.5, 0.0, 2.0, 0.01,
		"Intensity", "Vignette strength"))
	add_parameter(GNParameter.create_float("softness", 0.5, 0.01, 2.0, 0.01,
		"Softness", "Edge falloff width"))
	add_parameter(GNParameter.create_float("roundness", 1.0, 0.0, 1.0, 0.01,
		"Roundness", "Shape roundness (1 = circle, 0 = wide ellipse)"))
	add_parameter(GNParameter.create_color("color", Color.BLACK,
		"Color", "Vignette tint color"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("VignetteTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/vignette.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("intensity", get_param_value("intensity"))
	_material.set_shader_parameter("softness", get_param_value("softness"))
	_material.set_shader_parameter("roundness", get_param_value("roundness"))
	_material.set_shader_parameter("color", get_param_value("color"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
