class_name LevelTOP
extends GNNode
## Applies brightness, contrast, gamma, invert, and opacity adjustments to a texture.
## Uses a SubViewport with a levels shader.
## SubViewport is a child of this Node — freed automatically on removal.

var _shader: Shader = null
var _viewport: SubViewport = null
var _canvas: TextureRect = null
var _material: ShaderMaterial = null
var _cached_tex_data: GNTextureData = null


func _init() -> void:
	node_type = "level"
	family = GNFamily.Type.TOP
	node_description = "Brightness, contrast, gamma, invert, and opacity adjustments."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Adjusted texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("brightness", 1.0, 0.0, 4.0, 0.01, "", "Brightness multiplier"))
	add_parameter(GNParameter.create_float("contrast", 1.0, 0.0, 4.0, 0.01, "", "Contrast amount"))
	add_parameter(GNParameter.create_float("gamma", 1.0, 0.01, 4.0, 0.01, "", "Gamma correction curve"))
	add_parameter(GNParameter.create_bool("invert", false, "", "Invert all colors"))
	add_parameter(GNParameter.create_float("opacity", 1.0, 0.0, 1.0, 0.01, "", "Output opacity"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null

	if tex_in == null:
		GNLogger.warn("LevelTOP", "'%s' — no valid input on port 0" % id)
		return null

	_ensure_viewport()

	var brightness_val: float = get_param_value("brightness")
	var contrast_val: float = get_param_value("contrast")
	var gamma_val: float = get_param_value("gamma")
	var invert_val: bool = get_param_value("invert")
	var opacity_val: float = get_param_value("opacity")

	# Match viewport to input resolution
	var res: Vector2i = tex_in.resolution
	if _viewport.size != res:
		_viewport.size = res

	# Feed input texture — this is a GPU reference (zero-copy)
	_canvas.texture = tex_in.texture

	# Set shader uniforms
	_material.set_shader_parameter("brightness", brightness_val)
	_material.set_shader_parameter("contrast", contrast_val)
	_material.set_shader_parameter("gamma", gamma_val)
	_material.set_shader_parameter("invert", invert_val)
	_material.set_shader_parameter("opacity", opacity_val)

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _ensure_viewport() -> void:
	if _viewport != null:
		return

	_shader = load("res://addons/gonodes/shaders/levels.gdshader") as Shader

	# Create SubViewport as child
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

	# TextureRect displays the input texture through the levels shader
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
	GNLogger.debug("LevelTOP", "'%s' viewport created: %s" % [id, str(_viewport.size)])
