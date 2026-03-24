class_name AntiAliasTOP
extends GNTopBase
## Applies simplified FXAA anti-aliasing to an input texture.


func _init() -> void:
	node_type = "anti_alias"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Anti-aliased texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("strength", 1.0, 0.0, 2.0, 0.1, "Strength", "AA blend strength"))
	add_parameter(GNParameter.create_float("edge_threshold", 0.125, 0.0, 1.0, 0.01, "Edge Threshold", "Minimum contrast to trigger AA"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_in == null:
		GNLogger.warn("AntiAliasTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/anti_alias.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("strength", get_param_value("strength"))
	_material.set_shader_parameter("edge_threshold", get_param_value("edge_threshold"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
