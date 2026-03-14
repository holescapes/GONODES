class_name TriangleTOP
extends GNTopBase
## Draw 2D SDF primitives: triangle, line, pentagon.
## Useful for procedural shape generation and UI graphics.


func _init() -> void:
	node_type = "triangle"
	node_description = "Draw 2D SDF shapes: triangle, line, or pentagon with fill, border, and softness."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Rendered shape texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "",
		"Output texture resolution"))
	add_parameter(GNParameter.create_enum("shape",
		PackedStringArray(["Triangle", "Line", "Pentagon"]), 0, "",
		"Shape type to render"))
	add_parameter(GNParameter.create_float("size", 0.4, 0.01, 0.5, 0.01, "",
		"Shape radius (0..0.5 of UV space)"))
	add_parameter(GNParameter.create_color("fill_color", Color.WHITE, "Fill Color",
		"Shape interior colour"))
	add_parameter(GNParameter.create_color("bg_color", Color.BLACK, "Background",
		"Background colour"))
	add_parameter(GNParameter.create_float("border_width", 0.02, 0.0, 0.1, 0.001, "Border",
		"Border thickness (0 = no border)"))
	add_parameter(GNParameter.create_color("border_color", Color.WHITE, "Border Color",
		"Border / outline colour"))
	add_parameter(GNParameter.create_float("rotation", 0.0, null, null, 0.01, "",
		"Shape rotation in radians"))
	add_parameter(GNParameter.create_float("softness", 0.005, 0.0, 0.05, 0.001, "",
		"Edge anti-aliasing"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var res: Vector2i = get_param_value("resolution")
	_init_shader_viewport("res://addons/gonodes/shaders/top/triangle.gdshader", true, false, res)

	if _viewport.size != res:
		_viewport.size = res

	var fill: Color = get_param_value("fill_color")
	var bg: Color = get_param_value("bg_color")
	var bc: Color = get_param_value("border_color")

	_material.set_shader_parameter("shape_type", get_param_value("shape"))
	_material.set_shader_parameter("size", get_param_value("size"))
	_material.set_shader_parameter("fill_color", Vector4(fill.r, fill.g, fill.b, fill.a))
	_material.set_shader_parameter("bg_color", Vector4(bg.r, bg.g, bg.b, bg.a))
	_material.set_shader_parameter("border_width", get_param_value("border_width"))
	_material.set_shader_parameter("border_color", Vector4(bc.r, bc.g, bc.b, bc.a))
	_material.set_shader_parameter("rotation", get_param_value("rotation"))
	_material.set_shader_parameter("softness", get_param_value("softness"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
