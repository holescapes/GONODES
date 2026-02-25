class_name ConstantTOP
extends GNTopBase
## Generates a solid color texture. No shader needed.

var _viewport: SubViewport = null
var _canvas: ColorRect = null
var _cached_tex_data: GNTextureData = null


func _init() -> void:
	node_type = "constant"
	node_description = "Solid color texture."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Solid color texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "", "Output texture resolution in pixels"))
	add_parameter(GNParameter.create_color("color", Color.BLACK, "", "Fill color"))
	add_parameter(GNParameter.create_float("alpha", 1.0, 0.0, 1.0, 0.01, "", "Alpha override"))


func _cook(_inputs: Array[GNData]) -> GNData:
	_ensure_viewport()

	var res: Vector2i = get_param_value("resolution")
	var col: Color = get_param_value("color")
	var alpha_val: float = get_param_value("alpha")

	if _viewport.size != res:
		_viewport.size = res

	col.a = alpha_val
	_canvas.color = col

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _ensure_viewport() -> void:
	if _viewport != null:
		return

	_viewport = SubViewport.new()
	_viewport.name = "VP_%s" % id
	_viewport.size = Vector2i(512, 512)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.disable_3d = true
	_viewport.gui_disable_input = true
	add_child(_viewport)

	_canvas = ColorRect.new()
	_canvas.name = "Canvas"
	_canvas.color = Color.BLACK
	_viewport.add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _viewport.get_texture()
	_cached_tex_data.viewport = _viewport
	_cached_tex_data.resolution = _viewport.size
	GNLogger.debug("ConstantTOP", "'%s' viewport created" % id)
