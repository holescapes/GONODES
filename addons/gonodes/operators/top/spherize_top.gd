class_name SpherizeTOP
extends GNTopBase
## Bulge / pinch distortion — positive strength bulges, negative pinches.


func _init() -> void:
	node_type = "spherize"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Spherized texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("strength", 0.5, -2.0, 2.0, 0.01,
		"Strength", "Bulge (positive) or pinch (negative) amount"))
	add_parameter(GNParameter.create_float("radius", 0.5, 0.01, 2.0, 0.01,
		"Radius", "Effect radius as fraction of image"))
	add_parameter(GNParameter.create_vector2("center", Vector2(0.5, 0.5),
		"Center", "Center of the distortion"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("SpherizeTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/spherize.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("strength", get_param_value("strength"))
	_material.set_shader_parameter("radius", get_param_value("radius"))
	_material.set_shader_parameter("center", get_param_value("center"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
