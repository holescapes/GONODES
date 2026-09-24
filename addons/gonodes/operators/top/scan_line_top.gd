class_name ScanLineTOP
extends GNTopBase
## CRT / VHS scan line effect with configurable spacing, jitter, and curvature.


func _init() -> void:
	node_type = "scan_line"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Scan-lined texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("line_spacing", 4.0, 1.0, 20.0, 0.5,
		"Line Spacing", "Distance between scan lines in pixels"))
	add_parameter(GNParameter.create_float("line_brightness", 0.5, 0.0, 1.0, 0.01,
		"Line Brightness", "Brightness of the dark lines (1 = invisible)"))
	add_parameter(GNParameter.create_float("jitter", 0.0, 0.0, 10.0, 0.1,
		"Jitter", "Horizontal jitter per scan line in pixels"))
	add_parameter(GNParameter.create_float("curvature", 0.0, 0.0, 0.5, 0.01,
		"Curvature", "CRT screen curvature amount"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("ScanLineTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/scan_line.gdshader", true, true, res)

	_ensure_viewport_size(res)

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("line_spacing", get_param_value("line_spacing"))
	_material.set_shader_parameter("line_brightness", get_param_value("line_brightness"))
	_material.set_shader_parameter("jitter", get_param_value("jitter"))
	_material.set_shader_parameter("curvature", get_param_value("curvature"))
	_material.set_shader_parameter("time_val", elapsed_time)

	_cached_tex_data.resolution = res
	return _cached_tex_data
