class_name CrossTOP
extends GNTopBase
## Crossfades between two input textures. Simple linear interpolation.

var _shader: Shader = null


func _init() -> void:
	node_type = "cross"


func _init_ports() -> void:
	add_input("A", GNFamily.Type.TOP, false, "First texture (cross=0)", "A")
	add_input("B", GNFamily.Type.TOP, false, "Second texture (cross=1)", "B")
	add_output("out", GNFamily.Type.TOP, "Crossfaded texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("cross", 0.5, 0.0, 1.0, 0.01, "Cross Value", "Crossfade (0 = A, 1 = B)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_a: GNTextureData = _get_input_top(inputs, 0)
	var tex_b: GNTextureData = _get_input_top(inputs, 1)

	if tex_a == null:
		GNLogger.debug("CrossTOP", "'%s' — no valid input on port A" % id)
		return null

	var res: Vector2i = tex_a.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/cross.gdshader", true, false, res)

	var cross_val: float = get_param_value("cross")

	_ensure_viewport_size(res)

	_material.set_shader_parameter("texture_a", tex_a.texture)
	if tex_b != null:
		_material.set_shader_parameter("texture_b", tex_b.texture)
	_material.set_shader_parameter("cross_value", cross_val)

	_cached_tex_data.resolution = res

	return _cached_tex_data

