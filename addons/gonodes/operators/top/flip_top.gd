class_name FlipTOP
extends GNTopBase
## Flips/mirrors an input texture horizontally, vertically, or both.

var _shader: Shader = null


func _init() -> void:
	node_type = "flip"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Flipped texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("flip_x", false, "Flip Horizontal", "Mirror horizontally"))
	add_parameter(GNParameter.create_bool("flip_y", false, "Flip Vertical", "Mirror vertically"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("FlipTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/flip.gdshader", true, true, res)

	var fx: bool = get_param_value("flip_x")
	var fy: bool = get_param_value("flip_y")

	_ensure_viewport_size(res)

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("flip_x", fx)
	_material.set_shader_parameter("flip_y", fy)

	_cached_tex_data.resolution = res

	return _cached_tex_data

