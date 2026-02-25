class_name CrossTOP
extends GNNode
## Crossfades between two input textures. Simple linear interpolation.

var _shader: Shader = null
var _viewport: SubViewport = null
var _canvas: ColorRect = null
var _material: ShaderMaterial = null
var _cached_tex_data: GNTextureData = null


func _init() -> void:
	node_type = "cross"
	family = GNFamily.Type.TOP


func _init_ports() -> void:
	add_input("A", GNFamily.Type.TOP)
	add_input("B", GNFamily.Type.TOP)
	add_output("out", GNFamily.Type.TOP)


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("cross", 0.5, 0.0, 1.0, 0.01, "Cross Value"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_a: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	var tex_b: GNTextureData = inputs[1] as GNTextureData if inputs.size() > 1 and inputs[1] is GNTextureData else null

	if tex_a == null:
		GNLogger.warn("CrossTOP", "'%s' — no valid input on port A" % id)
		return null

	_ensure_viewport()

	var cross_val: float = get_param_value("cross")
	var res: Vector2i = tex_a.resolution

	if _viewport.size != res:
		_viewport.size = res
		_canvas.size = Vector2(res)

	_material.set_shader_parameter("texture_a", tex_a.texture)
	if tex_b != null:
		_material.set_shader_parameter("texture_b", tex_b.texture)
	_material.set_shader_parameter("cross_value", cross_val)

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _ensure_viewport() -> void:
	if _viewport != null:
		return

	_shader = load("res://addons/gonodes/shaders/cross.gdshader") as Shader

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

	_canvas = ColorRect.new()
	_canvas.name = "Canvas"
	_canvas.size = Vector2(512, 512)
	_canvas.material = _material
	_viewport.add_child(_canvas)

	_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _viewport.get_texture()
	_cached_tex_data.viewport = _viewport
	_cached_tex_data.resolution = _viewport.size
	GNLogger.debug("CrossTOP", "'%s' viewport created" % id)
