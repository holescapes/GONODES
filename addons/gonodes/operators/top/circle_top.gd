class_name CircleTOP
extends GNTopBase
## Generates a circle or ring shape using SDF rendering.
## Source generator — no input required.

var _shader: Shader = null


func _init() -> void:
	node_type = "circle"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Generated circle texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "Resolution", "Output texture resolution in pixels"))
	add_parameter(GNParameter.create_color("fill_color", Color.WHITE, "Fill Color", "Circle fill color"))
	add_parameter(GNParameter.create_color("bg_color", Color.BLACK, "Bg Color", "Background color"))
	add_parameter(GNParameter.create_vector2("center", Vector2(0.5, 0.5), "Center", "Circle center in UV space"))
	add_parameter(GNParameter.create_float("radius", 0.4, 0.0, 1.0, 0.01, "Radius", "Circle radius"))
	add_parameter(GNParameter.create_float("border_width", 0.0, 0.0, 0.5, 0.01, "Border Width", "Ring border width (0 = filled)"))
	add_parameter(GNParameter.create_float("softness", 0.005, 0.0, 0.1, 0.001, "Softness", "Edge antialiasing"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var res: Vector2i = get_param_value("resolution")
	_init_shader_viewport("res://addons/gonodes/shaders/top/circle.gdshader", false, false, res)
	var fill: Color = get_param_value("fill_color")
	var bg: Color = get_param_value("bg_color")
	var center_val: Vector2 = get_param_value("center")
	var radius_val: float = get_param_value("radius")
	var border: float = get_param_value("border_width")
	var soft: float = get_param_value("softness")

	if _viewport.size != res:
		_viewport.size = res

	_material.set_shader_parameter("fill_color", fill)
	_material.set_shader_parameter("bg_color", bg)
	_material.set_shader_parameter("center", center_val)
	_material.set_shader_parameter("radius", radius_val)
	_material.set_shader_parameter("border_width", border)
	_material.set_shader_parameter("softness", soft)

	_cached_tex_data.resolution = res
	return _cached_tex_data

