class_name RampTOP
extends GNNode
## Generates a color gradient ramp (horizontal, vertical, radial, or circular).
## Source generator — no input required.

var _shader: Shader = null
var _viewport: SubViewport = null
var _canvas: ColorRect = null
var _material: ShaderMaterial = null
var _cached_tex_data: GNTextureData = null


func _init() -> void:
	node_type = "ramp"
	family = GNFamily.Type.TOP
	node_description = "Gradient ramp generator (horizontal, vertical, radial, circular)."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Generated gradient texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "", "Output texture resolution in pixels"))
	add_parameter(GNParameter.create_enum("type",
		PackedStringArray(["Horizontal", "Vertical", "Radial", "Circular"]), 0, "", "Gradient direction"))
	add_parameter(GNParameter.create_color("color_a", Color.BLACK, "", "Start color"))
	add_parameter(GNParameter.create_color("color_b", Color.WHITE, "", "End color"))
	add_parameter(GNParameter.create_vector2("center", Vector2(0.5, 0.5), "", "Center point for radial/circular"))
	add_parameter(GNParameter.create_float("phase", 0.0, null, null, 0.01, "", "Phase offset"))
	add_parameter(GNParameter.create_bool("repeat", false, "", "Repeat the gradient pattern"))


func _cook(_inputs: Array[GNData]) -> GNData:
	_ensure_viewport()

	var res: Vector2i = get_param_value("resolution")
	var type_idx: int = get_param_value("type")
	var col_a: Color = get_param_value("color_a")
	var col_b: Color = get_param_value("color_b")
	var center_val: Vector2 = get_param_value("center")
	var phase_val: float = get_param_value("phase")
	var repeat_val: bool = get_param_value("repeat")

	if _viewport.size != res:
		_viewport.size = res
		_canvas.size = Vector2(res)

	_material.set_shader_parameter("ramp_type", type_idx)
	_material.set_shader_parameter("color_a", col_a)
	_material.set_shader_parameter("color_b", col_b)
	_material.set_shader_parameter("center", center_val)
	_material.set_shader_parameter("phase", phase_val)
	_material.set_shader_parameter("repeat_enabled", repeat_val)

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _ensure_viewport() -> void:
	if _viewport != null:
		return

	_shader = load("res://addons/gonodes/shaders/ramp.gdshader") as Shader

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
	GNLogger.debug("RampTOP", "'%s' viewport created" % id)
