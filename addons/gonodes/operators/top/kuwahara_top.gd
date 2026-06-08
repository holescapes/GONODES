class_name KuwaharaTOP
extends GNTopBase
## Kuwahara oil-painting filter — selects the lowest-variance quadrant
## around each pixel, producing a painterly / stylized look.


func _init() -> void:
	node_type = "kuwahara"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Painterly texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("radius", 4, 1, 12,
		"Radius", "Filter radius (larger = more abstract, slower)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("KuwaharaTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/kuwahara.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("radius", get_param_value("radius"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
