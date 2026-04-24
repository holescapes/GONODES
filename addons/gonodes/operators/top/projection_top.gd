class_name ProjectionTOP
extends GNTopBase
## UV projection mapping — planar, cylindrical, or spherical projection
## with offset, scale, and rotation controls.


func _init() -> void:
	node_type = "projection"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Re-projected texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Planar", "Cylindrical", "Spherical"]), 0, "",
		"Projection type"))
	add_parameter(GNParameter.create_vector2("uv_offset", Vector2.ZERO, "UV Offset",
		"UV translation"))
	add_parameter(GNParameter.create_vector2("uv_scale", Vector2(1.0, 1.0), "UV Scale",
		"UV scale multiplier"))
	add_parameter(GNParameter.create_float("rotation", 0.0, null, null, 0.01, "The rotation value",
		"UV rotation in radians"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("ProjectionTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/projection.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("projection_mode", get_param_value("mode"))
	_material.set_shader_parameter("uv_offset", get_param_value("uv_offset"))
	_material.set_shader_parameter("uv_scale", get_param_value("uv_scale"))
	_material.set_shader_parameter("rotation", get_param_value("rotation"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
