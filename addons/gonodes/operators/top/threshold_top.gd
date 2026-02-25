class_name ThresholdTOP
extends GNNode
## Converts an input texture to binary black/white based on luminance threshold.

var _shader: Shader = null
var _viewport: SubViewport = null
var _canvas: TextureRect = null
var _material: ShaderMaterial = null
var _cached_tex_data: GNTextureData = null


func _init() -> void:
	node_type = "threshold"
	family = GNFamily.Type.TOP
	node_description = "Binary black/white threshold with optional softness."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Thresholded texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("threshold", 0.5, 0.0, 1.0, 0.01, "", "Luminance cutoff value"))
	add_parameter(GNParameter.create_float("softness", 0.0, 0.0, 0.5, 0.01, "", "Soft transition width"))
	add_parameter(GNParameter.create_bool("use_alpha", false, "", "Threshold alpha channel instead of luminance"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_in == null:
		GNLogger.warn("ThresholdTOP", "'%s' — no valid input" % id)
		return null

	_ensure_viewport()

	var thresh: float = get_param_value("threshold")
	var soft: float = get_param_value("softness")
	var alpha: bool = get_param_value("use_alpha")
	var res: Vector2i = tex_in.resolution

	if _viewport.size != res:
		_viewport.size = res

	_canvas.texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("threshold_val", thresh)
	_material.set_shader_parameter("softness", soft)
	_material.set_shader_parameter("use_alpha", alpha)

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _ensure_viewport() -> void:
	if _viewport != null:
		return

	_shader = load("res://addons/gonodes/shaders/threshold.gdshader") as Shader

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
	_canvas.stretch_mode = TextureRect.STRETCH_SCALE
	_canvas.material = _material
	_viewport.add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _viewport.get_texture()
	_cached_tex_data.viewport = _viewport
	_cached_tex_data.resolution = _viewport.size
	GNLogger.debug("ThresholdTOP", "'%s' viewport created" % id)
