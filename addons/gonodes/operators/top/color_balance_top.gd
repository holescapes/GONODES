class_name ColorBalanceTOP
extends GNTopBase
## Lift / Gamma / Gain color grading — standard broadcast color correction.


func _init() -> void:
	node_type = "color_balance"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Color-balanced texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_color("lift", Color.WHITE,
		"Lift", "Shadow color offset (multiply)"))
	add_parameter(GNParameter.create_color("gamma", Color.WHITE,
		"Gamma", "Midtone gamma curve (per channel)"))
	add_parameter(GNParameter.create_color("gain", Color.WHITE,
		"Gain", "Highlight gain multiplier"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("ColorBalanceTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/color_balance.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("lift", get_param_value("lift"))
	_material.set_shader_parameter("gamma", get_param_value("gamma"))
	_material.set_shader_parameter("gain", get_param_value("gain"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
