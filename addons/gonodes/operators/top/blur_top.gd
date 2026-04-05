class_name BlurTOP
extends GNTopBase
## Applies a Gaussian blur to the input texture.
## Uses a two-pass separable blur (horizontal then vertical) for efficiency.

var _shader: Shader = null
var _viewport_h: SubViewport = null  # Horizontal pass
var _viewport_v: SubViewport = null  # Vertical pass
var _canvas_h: ColorRect = null
var _canvas_v: TextureRect = null
var _material_h: ShaderMaterial = null
var _material_v: ShaderMaterial = null


func _init() -> void:
	node_type = "blur"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture to blur")
	add_output("out", GNFamily.Type.TOP, "Blurred texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("size", 5.0, 0.0, 100.0, 0.1, "Blur Size", "Blur radius in pixels"))
	add_parameter(GNParameter.create_int("quality", 4, 1, 16, "", "Samples within the blur radius (higher = smoother)"))
	add_parameter(GNParameter.create_enum("method",
		PackedStringArray(["Gaussian", "Box", "Triangle", "Sinc", "Hanning", "Blackman", "Bump"]), 0, "", "Blur filter type"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_in == null:
		GNLogger.warn("BlurTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_setup_viewport(res)

	var blur_size: float = get_param_value("size")
	var quality_val: int = get_param_value("quality")
	var method_val: int = get_param_value("method")

	# Match viewport sizes to input
	if _viewport_h.size != res:
		_viewport_h.size = res
		_viewport_v.size = res

	# Horizontal pass: reads source texture
	_material_h.set_shader_parameter("source_tex", tex_in.texture)
	_material_h.set_shader_parameter("direction", Vector2(1.0, 0.0))
	_material_h.set_shader_parameter("blur_size", blur_size)
	_material_h.set_shader_parameter("quality", quality_val)
	_material_h.set_shader_parameter("method", method_val)

	# Vertical pass: reads horizontal pass output
	var h_tex: ViewportTexture = _viewport_h.get_texture()
	_canvas_v.texture = h_tex                       # TextureRect needs a texture to draw
	_material_v.set_shader_parameter("source_tex", h_tex)
	_material_v.set_shader_parameter("direction", Vector2(0.0, 1.0))
	_material_v.set_shader_parameter("blur_size", blur_size)
	_material_v.set_shader_parameter("quality", quality_val)
	_material_v.set_shader_parameter("method", method_val)

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _setup_viewport(size: Vector2i = Vector2i(512, 512)) -> void:
	if _viewport_h != null:
		return

	_shader = load("res://addons/gonodes/shaders/top/blur.gdshader") as Shader

	# Horizontal pass viewport
	_viewport_h = _create_viewport("VP_H_%s" % id, size)

	_material_h = ShaderMaterial.new()
	_material_h.shader = _shader

	_canvas_h = ColorRect.new()
	_canvas_h.name = "Canvas_H"
	_canvas_h.material = _material_h
	_viewport_h.add_child(_canvas_h)
	_canvas_h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Vertical pass viewport
	_viewport_v = _create_viewport("VP_V_%s" % id, size)

	_material_v = ShaderMaterial.new()
	_material_v.shader = _shader

	_canvas_v = TextureRect.new()
	_canvas_v.name = "Canvas_V"
	_canvas_v.stretch_mode = TextureRect.STRETCH_SCALE
	_canvas_v.material = _material_v
	_viewport_v.add_child(_canvas_v)
	_canvas_v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Output from the vertical pass
	_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _viewport_v.get_texture()
	_cached_tex_data.viewport = _viewport_v
	_cached_tex_data.resolution = _viewport_v.size
