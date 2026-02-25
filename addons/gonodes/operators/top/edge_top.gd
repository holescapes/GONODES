class_name EdgeTOP
extends GNNode
## Applies Sobel edge detection to an input texture.

var _shader: Shader = null
var _viewport: SubViewport = null
var _canvas: TextureRect = null
var _material: ShaderMaterial = null
var _cached_tex_data: GNTextureData = null


func _init() -> void:
	node_type = "edge"
	family = GNFamily.Type.TOP


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP)
	add_output("out", GNFamily.Type.TOP)


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("strength", 1.0, 0.0, 10.0, 0.1))
	add_parameter(GNParameter.create_bool("grayscale", true, "Grayscale Output"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_in == null:
		GNLogger.warn("EdgeTOP", "'%s' — no valid input" % id)
		return null

	_ensure_viewport()

	var strength_val: float = get_param_value("strength")
	var gray: bool = get_param_value("grayscale")
	var res: Vector2i = tex_in.resolution

	if _viewport.size != res:
		_viewport.size = res
		_canvas.size = Vector2(res)

	_canvas.texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("strength", strength_val)
	_material.set_shader_parameter("grayscale_input", gray)

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _ensure_viewport() -> void:
	if _viewport != null:
		return

	_shader = load("res://addons/gonodes/shaders/edge.gdshader") as Shader

	_viewport = SubViewport.new()
	_viewport.name = "VP_%s" % id
	_viewport.size = Vector2i(512, 512)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.disable_3d = true
	_viewport.gui_disable_input = true
	add_child(_viewport)

	_material = ShaderMaterial.new()
	_material.shader = _shader

	_canvas = TextureRect.new()
	_canvas.name = "Canvas"
	_canvas.size = Vector2(512, 512)
	_canvas.stretch_mode = TextureRect.STRETCH_SCALE
	_canvas.material = _material
	_viewport.add_child(_canvas)

	_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _viewport.get_texture()
	_cached_tex_data.viewport = _viewport
	_cached_tex_data.resolution = _viewport.size
	GNLogger.debug("EdgeTOP", "'%s' viewport created" % id)
