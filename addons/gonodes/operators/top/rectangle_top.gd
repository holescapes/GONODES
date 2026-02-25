class_name RectangleTOP
extends GNNode
## Generates a rectangle or rounded rectangle shape using SDF rendering.
## Source generator — no input required.

var _shader: Shader = null
var _viewport: SubViewport = null
var _canvas: ColorRect = null
var _material: ShaderMaterial = null
var _cached_tex_data: GNTextureData = null


func _init() -> void:
	node_type = "rectangle"
	family = GNFamily.Type.TOP
	node_description = "SDF rounded rectangle with fill/border/softness."


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
	_ensure_viewport()

	var res: Vector2i = get_param_value("resolution")
	var fill: Color = get_param_value("fill_color")
	var bg: Color = get_param_value("bg_color")
	var center_val: Vector2 = get_param_value("center")
	var size_val: Vector2 = get_param_value("size")
	var corner: float = get_param_value("corner_radius")
	var border: float = get_param_value("border_width")
	var soft: float = get_param_value("softness")

	if _viewport.size != res:
		_viewport.size = res
		_canvas.size = Vector2(res)

	_material.set_shader_parameter("fill_color", fill)
	_material.set_shader_parameter("bg_color", bg)
	_material.set_shader_parameter("center", center_val)
	_material.set_shader_parameter("rect_size", size_val)
	_material.set_shader_parameter("corner_radius", corner)
	_material.set_shader_parameter("border_width", border)
	_material.set_shader_parameter("softness", soft)

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _ensure_viewport() -> void:
	if _viewport != null:
		return

	_shader = load("res://addons/gonodes/shaders/rectangle.gdshader") as Shader

	_viewport = SubViewport.new()
	_viewport.name = "VP_%s" % id
	_viewport.size = Vector2i(512, 512)
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.disable_3d = true
	_viewport.gui_disable_input = true
	add_child(_viewport)

	_material = ShaderMaterial.new()
	_material.shader = _shader

	_canvas = ColorRect.new()
	_canvas.name = "Canvas"
	_canvas.size = Vector2(512, 512)
	_canvas.material = _material
	_viewport.add_child(_canvas)

	_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _viewport.get_texture()
	_cached_tex_data.viewport = _viewport
	_cached_tex_data.resolution = _viewport.size
	GNLogger.debug("RectangleTOP", "'%s' viewport created" % id)
