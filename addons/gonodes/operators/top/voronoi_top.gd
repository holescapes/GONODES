class_name VoronoiTOP
extends GNTopBase
## Generates Voronoi / Worley noise patterns with F1, F2, and F2-F1 modes.


func _init() -> void:
	node_type = "voronoi"


func update_time_dependency() -> void:
	time_dependent = float(get_param_value("speed")) > 0.0 \
			or param_expression_uses_time("speed")


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Voronoi pattern")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512),
		"Resolution", "Output resolution"))
	add_parameter(GNParameter.create_float("scale", 10.0, 1.0, 100.0, 0.5,
		"Scale", "Cell density"))
	add_parameter(GNParameter.create_float("jitter", 1.0, 0.0, 1.0, 0.01,
		"Jitter", "Cell point randomness (0 = grid, 1 = fully random)"))
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["F1 (nearest)", "F2 (second)", "F2 - F1 (cell edges)"]), 0,
		"", "Distance field mode"))
	add_parameter(GNParameter.create_float("speed", 0.0, 0.0, 5.0, 0.1,
		"Speed", "Animation speed (0 = static)"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var res: Vector2i = get_param_value("resolution")
	_init_shader_viewport("res://addons/gonodes/shaders/top/voronoi.gdshader", true, false, res)

	_ensure_viewport_size(res)

	_material.set_shader_parameter("scale", get_param_value("scale"))
	_material.set_shader_parameter("jitter", get_param_value("jitter"))
	_material.set_shader_parameter("mode", get_param_value("mode"))
	_material.set_shader_parameter("speed", get_param_value("speed"))
	_material.set_shader_parameter("time_val", elapsed_time)

	_cached_tex_data.resolution = res
	return _cached_tex_data
