class_name GradientMapTOP
extends GNTopBase
## Maps image luminance to a color gradient supplied as a second input.
## Connect a RampTOP or any horizontal gradient as the second input.


func _init() -> void:
	node_type = "gradient_map"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Source texture", "In")
	add_input("gradient", GNFamily.Type.TOP, false, "Gradient / ramp texture (horizontal)", "Gradient")
	add_output("out", GNFamily.Type.TOP, "Color-mapped texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("intensity", 1.0, 0.0, 1.0, 0.01,
		"Intensity", "Blend between original (0) and mapped (1)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("GradientMapTOP", "'%s' — no valid source input" % id)
		return null

	var grad_in: GNTextureData = _get_input_top(inputs, 1)

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/gradient_map.gdshader", true, false, res)

	if _viewport.size != res:
		_viewport.size = res

	_material.set_shader_parameter("source_tex", tex_in.texture)
	if grad_in != null:
		_material.set_shader_parameter("gradient_tex", grad_in.texture)
	_material.set_shader_parameter("intensity", get_param_value("intensity"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
