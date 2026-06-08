class_name RadialBlurTOP
extends GNTopBase
## Applies a zoom / radial blur emanating from a configurable center point.


func _init() -> void:
	node_type = "radial_blur"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Radial-blurred texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("strength", 0.1, 0.0, 1.0, 0.01, "Strength", "Blur strength"))
	add_parameter(GNParameter.create_int("samples", 16, 4, 64, "Samples", "Number of samples (higher = smoother)"))
	add_parameter(GNParameter.create_float("center_x", 0.5, 0.0, 1.0, 0.01, "Center X", "Horizontal center position"))
	add_parameter(GNParameter.create_float("center_y", 0.5, 0.0, 1.0, 0.01, "Center Y", "Vertical center position"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("RadialBlurTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/radial_blur.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("strength", get_param_value("strength"))
	_material.set_shader_parameter("samples", get_param_value("samples"))
	_material.set_shader_parameter("center_x", get_param_value("center_x"))
	_material.set_shader_parameter("center_y", get_param_value("center_y"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
