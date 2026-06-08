class_name EdgeBlendTOP
extends GNTopBase
## Applies soft edge blending for multi-projector setups.
## Each edge (left, right, top, bottom) gets its own blend width and gamma curve.


func _init() -> void:
	node_type = "edge_blend"
	node_description = "Soft edge blending for seamless multi-projector overlap zones."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Edge-blended texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("blend_left", 0.0, 0.0, 0.5, 0.001, "Blend Left", "Left edge blend width (0-0.5)"))
	add_parameter(GNParameter.create_float("blend_right", 0.0, 0.0, 0.5, 0.001, "Blend Right", "Right edge blend width"))
	add_parameter(GNParameter.create_float("blend_top", 0.0, 0.0, 0.5, 0.001, "Blend Top", "Top edge blend width"))
	add_parameter(GNParameter.create_float("blend_bottom", 0.0, 0.0, 0.5, 0.001, "Blend Bottom", "Bottom edge blend width"))
	add_parameter(GNParameter.create_float("gamma", 2.2, 0.1, 5.0, 0.01, "Gamma", "Blend luminance gamma correction"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("EdgeBlendTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gn_ext_mapper/shaders/edge_blend.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("input_tex", tex_in.texture)
	_material.set_shader_parameter("blend_left", get_param_value("blend_left"))
	_material.set_shader_parameter("blend_right", get_param_value("blend_right"))
	_material.set_shader_parameter("blend_top", get_param_value("blend_top"))
	_material.set_shader_parameter("blend_bottom", get_param_value("blend_bottom"))
	_material.set_shader_parameter("gamma", get_param_value("gamma"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
