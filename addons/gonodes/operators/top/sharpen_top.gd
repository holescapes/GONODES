class_name SharpenTOP
extends GNTopBase
## Unsharp mask sharpening filter with configurable strength and radius.


func _init() -> void:
	node_type = "sharpen"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Sharpened texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("strength", 1.0, 0.0, 10.0, 0.1, "Effect strength",
		"Sharpening strength"))
	add_parameter(GNParameter.create_float("radius", 1.0, 0.1, 10.0, 0.1, "Radius in world units",
		"Sample radius in pixels"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("SharpenTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/sharpen.gdshader", true, true, res)

	_ensure_viewport_size(res)

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("strength", get_param_value("strength"))
	_material.set_shader_parameter("radius", get_param_value("radius"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
