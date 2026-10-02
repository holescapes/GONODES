class_name PatternTOP
extends GNTopBase
## Procedural pattern generator: stripes, checkerboard, concentric circles,
## grids, and dots with configurable frequency, rotation, and colours.


func _init() -> void:
	node_type = "pattern"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Generated pattern texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "Output resolution",
		"Output texture resolution"))
	add_parameter(GNParameter.create_enum("type",
		PackedStringArray(["Stripes", "Checkerboard", "Concentric", "Grid", "Dots"]), 0,
		"Pattern", "Pattern type"))
	add_parameter(GNParameter.create_float("frequency", 8.0, 0.1, 100.0, 0.1, "Oscillation frequency in Hz",
		"Pattern repetition frequency"))
	add_parameter(GNParameter.create_float("duty_cycle", 0.5, 0.0, 1.0, 0.01, "Duty Cycle",
		"Width ratio of the pattern's primary shape"))
	add_parameter(GNParameter.create_color("color_a", Color.WHITE, "Color A",
		"Primary pattern colour"))
	add_parameter(GNParameter.create_color("color_b", Color.BLACK, "Color B",
		"Secondary / background colour"))
	add_parameter(GNParameter.create_float("rotation", 0.0, null, null, 1.0, "Rotation",
		"Pattern rotation in degrees"))
	add_parameter(GNParameter.create_float("softness", 0.02, 0.0, 0.2, 0.001, "The softness value",
		"Edge anti-aliasing / softness"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var res: Vector2i = get_param_value("resolution")
	_init_shader_viewport("res://addons/gonodes/shaders/top/pattern.gdshader", false, false, res)

	_ensure_viewport_size(res)

	var ca: Color = get_param_value("color_a")
	var cb: Color = get_param_value("color_b")

	_material.set_shader_parameter("pattern_type", get_param_value("type"))
	_material.set_shader_parameter("frequency", get_param_value("frequency"))
	_material.set_shader_parameter("duty_cycle", get_param_value("duty_cycle"))
	_material.set_shader_parameter("color_a", Vector4(ca.r, ca.g, ca.b, ca.a))
	_material.set_shader_parameter("color_b", Vector4(cb.r, cb.g, cb.b, cb.a))
	_material.set_shader_parameter("rotation", deg_to_rad(get_param_value("rotation")))
	_material.set_shader_parameter("softness", get_param_value("softness"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
