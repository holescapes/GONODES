class_name ProjectionMaskTOP
extends GNTopBase
## Rectangular soft-edge mask for projection mapping.
## Crops/masks a region of the input with optional feathered edges and invert.


func _init() -> void:
	node_type = "projection_mask"
	node_description = "Rectangular mask with soft edges for masking projection regions."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Masked texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("left", 0.0, 0.0, 1.0, 0.001, "Left", "Mask left edge (0-1 normalized)"))
	add_parameter(GNParameter.create_float("right", 1.0, 0.0, 1.0, 0.001, "Right", "Mask right edge"))
	add_parameter(GNParameter.create_float("mask_top", 0.0, 0.0, 1.0, 0.001, "Top", "Mask top edge"))
	add_parameter(GNParameter.create_float("bottom", 1.0, 0.0, 1.0, 0.001, "Bottom", "Mask bottom edge"))
	add_parameter(GNParameter.create_float("feather", 0.02, 0.0, 0.2, 0.001, "Feather", "Soft edge width in UV space"))
	add_parameter(GNParameter.create_bool("invert", false, "Invert", "Invert the mask"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("ProjectionMaskTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gn_ext_mapper/shaders/projection_mask.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("input_tex", tex_in.texture)
	_material.set_shader_parameter("left", get_param_value("left"))
	_material.set_shader_parameter("right", get_param_value("right"))
	_material.set_shader_parameter("top", get_param_value("mask_top"))
	_material.set_shader_parameter("bottom", get_param_value("bottom"))
	_material.set_shader_parameter("feather", get_param_value("feather"))
	_material.set_shader_parameter("invert", 1.0 if get_param_value("invert") else 0.0)

	_cached_tex_data.resolution = res
	return _cached_tex_data
