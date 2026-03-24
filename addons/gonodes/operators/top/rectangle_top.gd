class_name RectangleTOP
extends GNTopBase
## Generates a rectangle or rounded rectangle shape using SDF rendering.
## Source generator — no input required.

var _shader: Shader = null


func _init() -> void:
	node_type = "rectangle"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Generated rectangle texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "", "Output texture resolution in pixels"))
	add_parameter(GNParameter.create_color("fill_color", Color.WHITE, "", "Rectangle fill color"))
	add_parameter(GNParameter.create_color("bg_color", Color.BLACK, "", "Background color"))
	add_parameter(GNParameter.create_vector2("center", Vector2(0.5, 0.5), "", "Rectangle center in UV space"))
	add_parameter(GNParameter.create_vector2("size", Vector2(0.6, 0.4), "", "Rectangle width and height"))
	add_parameter(GNParameter.create_float("corner_radius", 0.0, 0.0, 0.5, 0.01, "", "Rounded corner radius"))
	add_parameter(GNParameter.create_float("border_width", 0.0, 0.0, 0.5, 0.01, "", "Border only mode (0 = filled)"))
	add_parameter(GNParameter.create_float("softness", 0.005, 0.0, 0.1, 0.001, "", "Edge antialiasing"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var res: Vector2i = get_param_value("resolution")
	_init_shader_viewport("res://addons/gonodes/shaders/top/rectangle.gdshader", false, false, res)
	var fill: Color = get_param_value("fill_color")
	var bg: Color = get_param_value("bg_color")
	var center_val: Vector2 = get_param_value("center")
	var size_val: Vector2 = get_param_value("size")
	var corner: float = get_param_value("corner_radius")
	var border: float = get_param_value("border_width")
	var soft: float = get_param_value("softness")

	if _viewport.size != res:
		_viewport.size = res

	_material.set_shader_parameter("fill_color", fill)
	_material.set_shader_parameter("bg_color", bg)
	_material.set_shader_parameter("center", center_val)
	_material.set_shader_parameter("rect_size", size_val)
	_material.set_shader_parameter("corner_radius", corner)
	_material.set_shader_parameter("border_width", border)
	_material.set_shader_parameter("softness", soft)

	_cached_tex_data.resolution = res
	return _cached_tex_data

