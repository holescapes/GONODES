class_name PosterizeTOP
extends GNTopBase
## Reduces color levels to create a posterization effect.


func _init() -> void:
	node_type = "posterize"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Posterized texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("levels", 4, 2, 256, "Levels", "Number of color levels"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("PosterizeTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/posterize.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("levels", get_param_value("levels"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
