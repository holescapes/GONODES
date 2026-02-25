class_name TransformTOP
extends GNTopBase
## Applies 2D spatial transformations (translate, rotate, scale) to an input texture.

var _shader: Shader = null
var _viewport: SubViewport = null
var _canvas: TextureRect = null
var _material: ShaderMaterial = null
var _cached_tex_data: GNTextureData = null


func _init() -> void:
	node_type = "transform"
	node_description = "2D translate, rotate, and scale with extend modes."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Transformed texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2("translate", Vector2.ZERO, "", "UV translation"))
	add_parameter(GNParameter.create_float("rotate", 0.0, null, null, 0.01, "Rotate (rad)", "Rotation in radians"))
	add_parameter(GNParameter.create_vector2("scale", Vector2(1.0, 1.0), "", "UV scale"))
	add_parameter(GNParameter.create_vector2("pivot", Vector2(0.5, 0.5), "", "Transform pivot point in UV space"))
	add_parameter(GNParameter.create_enum("extend",
		PackedStringArray(["Clamp", "Repeat", "Mirror", "Zero"]), 0, "", "Edge extension mode"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_in == null:
		GNLogger.warn("TransformTOP", "'%s' — no valid input" % id)
		return null

	_ensure_viewport()

	var trans: Vector2 = get_param_value("translate")
	var rot: float = get_param_value("rotate")
	var scl: Vector2 = get_param_value("scale")
	var pvt: Vector2 = get_param_value("pivot")
	var ext: int = get_param_value("extend")
	var res: Vector2i = tex_in.resolution

	if _viewport.size != res:
		_viewport.size = res

	_canvas.texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("translate", trans)
	_material.set_shader_parameter("rotate_angle", rot)
	_material.set_shader_parameter("scale_amount", scl)
	_material.set_shader_parameter("pivot", pvt)
	_material.set_shader_parameter("extend_mode", ext)

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _ensure_viewport() -> void:
	if _viewport != null:
		return

	_shader = load("res://addons/gonodes/shaders/transform2d.gdshader") as Shader

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
	GNLogger.debug("TransformTOP", "'%s' viewport created" % id)
