class_name BlurTOP
extends GNNode
## Applies a Gaussian blur to the input texture.
## Uses a two-pass separable blur (horizontal then vertical) for efficiency.

var _shader: Shader = null
var _viewport_h: SubViewport = null  # Horizontal pass
var _viewport_v: SubViewport = null  # Vertical pass
var _canvas_h: ColorRect = null
var _canvas_v: TextureRect = null
var _material_h: ShaderMaterial = null
var _material_v: ShaderMaterial = null
var _cached_tex_data: GNTextureData = null


func _init() -> void:
	node_type = "blur"
	family = GNFamily.Type.TOP


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP)
	add_output("out", GNFamily.Type.TOP)


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("size", 5.0, 0.0, 100.0, 0.1, "Blur Size"))
	add_parameter(GNParameter.create_int("quality", 4, 1, 8))
	add_parameter(GNParameter.create_enum("method",
		PackedStringArray(["Gaussian", "Box"]), 0))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_in == null:
		GNLogger.warn("BlurTOP", "'%s' — no valid input" % id)
		return null

	_ensure_viewport()

	var blur_size: float = get_param_value("size")
	var quality_val: int = get_param_value("quality")
	var res: Vector2i = tex_in.resolution

	# Match viewport sizes to input
	if _viewport_h.size != res:
		_viewport_h.size = res
		_viewport_v.size = res
		_canvas_h.size = Vector2(res)
		_canvas_v.size = Vector2(res)

	# Horizontal pass: reads source texture
	_material_h.set_shader_parameter("source_tex", tex_in.texture)
	_material_h.set_shader_parameter("direction", Vector2(1.0, 0.0))
	_material_h.set_shader_parameter("blur_size", blur_size)
	_material_h.set_shader_parameter("quality", quality_val)

	# Vertical pass: reads horizontal pass output
	_material_v.set_shader_parameter("source_tex", _viewport_h.get_texture())
	_material_v.set_shader_parameter("direction", Vector2(0.0, 1.0))
	_material_v.set_shader_parameter("blur_size", blur_size)
	_material_v.set_shader_parameter("quality", quality_val)

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _ensure_viewport() -> void:
	if _viewport_h != null:
		return

	_shader = load("res://addons/gonodes/shaders/blur.gdshader") as Shader

	# Horizontal pass viewport
	_viewport_h = SubViewport.new()
	_viewport_h.name = "VP_H_%s" % id
	_viewport_h.size = Vector2i(512, 512)
	_viewport_h.transparent_bg = true
	_viewport_h.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport_h.disable_3d = true
	_viewport_h.gui_disable_input = true
	add_child(_viewport_h)

	_material_h = ShaderMaterial.new()
	_material_h.shader = _shader

	_canvas_h = ColorRect.new()
	_canvas_h.name = "Canvas_H"
	_canvas_h.size = Vector2(512, 512)
	_canvas_h.material = _material_h
	_viewport_h.add_child(_canvas_h)

	# Vertical pass viewport
	_viewport_v = SubViewport.new()
	_viewport_v.name = "VP_V_%s" % id
	_viewport_v.size = Vector2i(512, 512)
	_viewport_v.transparent_bg = true
	_viewport_v.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport_v.disable_3d = true
	_viewport_v.gui_disable_input = true
	add_child(_viewport_v)

	_material_v = ShaderMaterial.new()
	_material_v.shader = _shader

	_canvas_v = TextureRect.new()
	_canvas_v.name = "Canvas_V"
	_canvas_v.size = Vector2(512, 512)
	_canvas_v.stretch_mode = TextureRect.STRETCH_SCALE
	_canvas_v.material = _material_v
	_viewport_v.add_child(_canvas_v)

	# Output from the vertical pass
	_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _viewport_v.get_texture()
	_cached_tex_data.viewport = _viewport_v
	_cached_tex_data.resolution = _viewport_v.size
	GNLogger.debug("BlurTOP", "'%s' viewports created (2-pass)" % id)
