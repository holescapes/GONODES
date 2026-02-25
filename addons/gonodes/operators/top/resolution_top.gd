class_name ResolutionTOP
extends GNNode
## Resizes an input texture to a target resolution using a SubViewport.

var _viewport: SubViewport = null
var _canvas: TextureRect = null
var _cached_tex_data: GNTextureData = null


func _init() -> void:
	node_type = "resolution"
	family = GNFamily.Type.TOP


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP)
	add_output("out", GNFamily.Type.TOP)


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(1920, 1080), "Output Resolution"))
	add_parameter(GNParameter.create_enum("filter",
		PackedStringArray(["Linear", "Nearest"]), 0))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_in == null:
		GNLogger.warn("ResolutionTOP", "'%s' — no valid input" % id)
		return null

	_ensure_viewport()

	var res: Vector2i = get_param_value("resolution")
	var filter_idx: int = get_param_value("filter")

	if _viewport.size != res:
		_viewport.size = res
		_canvas.size = Vector2(res)

	_canvas.texture = tex_in.texture
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if filter_idx == 0 else CanvasItem.TEXTURE_FILTER_NEAREST

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _ensure_viewport() -> void:
	if _viewport != null:
		return

	_viewport = SubViewport.new()
	_viewport.name = "VP_%s" % id
	_viewport.size = Vector2i(1920, 1080)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.disable_3d = true
	_viewport.gui_disable_input = true
	add_child(_viewport)

	_canvas = TextureRect.new()
	_canvas.name = "Canvas"
	_canvas.size = Vector2(1920, 1080)
	_canvas.stretch_mode = TextureRect.STRETCH_SCALE
	_viewport.add_child(_canvas)

	_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _viewport.get_texture()
	_cached_tex_data.viewport = _viewport
	_cached_tex_data.resolution = _viewport.size
	GNLogger.debug("ResolutionTOP", "'%s' viewport created" % id)
