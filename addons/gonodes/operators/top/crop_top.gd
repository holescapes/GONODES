class_name CropTOP
extends GNTopBase
## Crops a sub-region of the input texture.

var _shader: Shader = null


func _init() -> void:
	node_type = "crop"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture to crop", "In")
	add_output("out", GNFamily.Type.TOP, "Cropped texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "Output Resolution", "Output texture resolution"))
	add_parameter(GNParameter.create_vector2("left_top", Vector2(0.0, 0.0), "Left Top", "Top-left UV corner of crop region"))
	add_parameter(GNParameter.create_vector2("right_bottom", Vector2(1.0, 1.0), "Right Bottom", "Bottom-right UV corner of crop region"))
	add_parameter(GNParameter.create_enum("edge_mode",
		PackedStringArray(["Clamp", "Repeat", "Mirror", "Zero"]), 0, "Edge Mode",
		"How to handle UVs outside source bounds"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("CropTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = get_param_value("resolution")
	_init_shader_viewport("res://addons/gonodes/shaders/top/crop.gdshader", true, true, res)

	var lt: Vector2 = get_param_value("left_top")
	var rb: Vector2 = get_param_value("right_bottom")

	_ensure_viewport_size(res)

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("crop_left_top", lt)
	_material.set_shader_parameter("crop_right_bottom", rb)
	_material.set_shader_parameter("edge_mode", get_param_value("edge_mode"))

	_cached_tex_data.resolution = res

	return _cached_tex_data

