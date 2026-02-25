class_name LookupTOP
extends GNNode
## Remaps the colors of a source texture using a second texture as a lookup table.
## Luminance of the source indexes into the lookup ramp texture.

var _shader: Shader = null
var _viewport: SubViewport = null
var _canvas: ColorRect = null
var _material: ShaderMaterial = null
var _cached_tex_data: GNTextureData = null


func _init() -> void:
	node_type = "lookup"
	family = GNFamily.Type.TOP
	node_description = "Remap colors via a lookup table / ramp texture."


func _init_ports() -> void:
	add_input("source", GNFamily.Type.TOP, false, "Image to remap")
	add_input("ramp", GNFamily.Type.TOP, false, "Color lookup table / ramp")
	add_output("out", GNFamily.Type.TOP, "Remapped texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("index_by",
		PackedStringArray(["Luminance", "Red", "Green", "Blue"]), 0, "", "Which channel indexes the ramp"))


func _cook(inputs: Array[GNData]) -> GNData:
	var source: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	var ramp_tex: GNTextureData = inputs[1] as GNTextureData if inputs.size() > 1 and inputs[1] is GNTextureData else null

	if source == null:
		GNLogger.warn("LookupTOP", "'%s' — no valid source input" % id)
		return null

	_ensure_viewport()

	var index_mode: int = get_param_value("index_by")
	var res: Vector2i = source.resolution

	if _viewport.size != res:
		_viewport.size = res
		_canvas.size = Vector2(res)

	_material.set_shader_parameter("source_tex", source.texture)
	if ramp_tex != null:
		_material.set_shader_parameter("ramp_tex", ramp_tex.texture)
	_material.set_shader_parameter("index_channel", index_mode)

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _ensure_viewport() -> void:
	if _viewport != null:
		return

	_shader = load("res://addons/gonodes/shaders/lookup.gdshader") as Shader

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
	_canvas.size = Vector2(512, 512)
	_canvas.material = _material
	_viewport.add_child(_canvas)

	_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _viewport.get_texture()
	_cached_tex_data.viewport = _viewport
	_cached_tex_data.resolution = _viewport.size
	GNLogger.debug("LookupTOP", "'%s' viewport created" % id)
