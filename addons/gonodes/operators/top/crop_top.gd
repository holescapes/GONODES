class_name CropTOP
extends GNTopBase
## Crops a sub-region of the input texture.

var _shader: Shader = null


func _init() -> void:
	node_type = "crop"
	node_description = "Crop a UV sub-region from the input texture."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture to crop")
	add_output("out", GNFamily.Type.TOP, "Cropped texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "Output Resolution", "Output texture resolution"))
	add_parameter(GNParameter.create_vector2("left_top", Vector2(0.0, 0.0), "", "Top-left UV corner of crop region"))
	add_parameter(GNParameter.create_vector2("right_bottom", Vector2(1.0, 1.0), "", "Bottom-right UV corner of crop region"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_in == null:
		GNLogger.warn("CropTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = get_param_value("resolution")
	_init_shader_viewport("res://addons/gonodes/shaders/crop.gdshader", true, true, res)

	var lt: Vector2 = get_param_value("left_top")
	var rb: Vector2 = get_param_value("right_bottom")

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("crop_left_top", lt)
	_material.set_shader_parameter("crop_right_bottom", rb)

	_cached_tex_data.resolution = res
	return _cached_tex_data

