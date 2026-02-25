class_name CropTOP
extends GNNode
## Crops a sub-region of the input texture.

var _shader: Shader = null
var _viewport: SubViewport = null
var _canvas: TextureRect = null
var _material: ShaderMaterial = null
var _cached_tex_data: GNTextureData = null


func _init() -> void:
	node_type = "crop"
	family = GNFamily.Type.TOP


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP)
	add_output("out", GNFamily.Type.TOP)


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "Output Resolution"))
	add_parameter(GNParameter.create_vector2("left_top", Vector2(0.0, 0.0)))
	add_parameter(GNParameter.create_vector2("right_bottom", Vector2(1.0, 1.0)))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_in == null:
		GNLogger.warn("CropTOP", "'%s' — no valid input" % id)
		return null

	_ensure_viewport()

	var res: Vector2i = get_param_value("resolution")
	var lt: Vector2 = get_param_value("left_top")
	var rb: Vector2 = get_param_value("right_bottom")

	if _viewport.size != res:
		_viewport.size = res
		_canvas.size = Vector2(res)

	_canvas.texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("crop_left_top", lt)
	_material.set_shader_parameter("crop_right_bottom", rb)

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _ensure_viewport() -> void:
	if _viewport != null:
		return

	_shader = load("res://addons/gonodes/shaders/crop.gdshader") as Shader

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
	GNLogger.debug("CropTOP", "'%s' viewport created" % id)
