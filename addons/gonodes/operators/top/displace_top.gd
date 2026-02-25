class_name DisplaceTOP
extends GNTopBase
## Displaces the UV coordinates of a source texture using a displacement map.

var _shader: Shader = null
var _viewport: SubViewport = null
var _canvas: ColorRect = null
var _material: ShaderMaterial = null
var _cached_tex_data: GNTextureData = null


func _init() -> void:
	node_type = "displace"
	node_description = "Distort one texture using another as a displacement map."


func _init_ports() -> void:
	add_input("source", GNFamily.Type.TOP, false, "Texture to distort")
	add_input("displace", GNFamily.Type.TOP, false, "Displacement map")
	add_output("out", GNFamily.Type.TOP, "Displaced texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("weight", 0.1, 0.0, 2.0, 0.01, "", "Displacement strength"))
	add_parameter(GNParameter.create_enum("method",
		PackedStringArray(["RG as XY", "Luminance", "RGB as XYZ"]), 0, "", "How to read the displacement map"))
	add_parameter(GNParameter.create_vector2("scale", Vector2(1.0, 1.0), "", "Per-axis displacement scale"))


func _cook(inputs: Array[GNData]) -> GNData:
	var source: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	var disp: GNTextureData = inputs[1] as GNTextureData if inputs.size() > 1 and inputs[1] is GNTextureData else null

	if source == null:
		GNLogger.warn("DisplaceTOP", "'%s' — no valid source input" % id)
		return null

	_ensure_viewport()

	var weight_val: float = get_param_value("weight")
	var method_idx: int = get_param_value("method")
	var scale_val: Vector2 = get_param_value("scale")
	var res: Vector2i = source.resolution

	if _viewport.size != res:
		_viewport.size = res

	_material.set_shader_parameter("source_tex", source.texture)
	if disp != null:
		_material.set_shader_parameter("displace_tex", disp.texture)
	_material.set_shader_parameter("displace_weight", weight_val)
	_material.set_shader_parameter("displace_method", method_idx)
	_material.set_shader_parameter("displace_scale", scale_val)

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _ensure_viewport() -> void:
	if _viewport != null:
		return

	_shader = load("res://addons/gonodes/shaders/displace.gdshader") as Shader

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
	_canvas.material = _material
	_viewport.add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _viewport.get_texture()
	_cached_tex_data.viewport = _viewport
	_cached_tex_data.resolution = _viewport.size
	GNLogger.debug("DisplaceTOP", "'%s' viewport created" % id)
