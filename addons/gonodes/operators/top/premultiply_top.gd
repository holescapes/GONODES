class_name PremultiplyTOP
extends GNTopBase
## Premultiplies or unpremultiplies alpha on an input texture.


func _init() -> void:
	node_type = "premultiply"
	node_description = "Premultiply or unpremultiply alpha."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Processed texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Premultiply", "Unpremultiply"]), 0,
		"Mode", "Premultiply or unpremultiply alpha"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_in == null:
		GNLogger.warn("PremultiplyTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/premultiply.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("mode", get_param_value("mode"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
