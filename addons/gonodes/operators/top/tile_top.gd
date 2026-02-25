class_name TileTOP
extends GNNode
## Tiles/repeats an input texture with configurable repeat count and mirroring.

var _shader: Shader = null
var _viewport: SubViewport = null
var _canvas: TextureRect = null
var _material: ShaderMaterial = null
var _cached_tex_data: GNTextureData = null


func _init() -> void:
	node_type = "tile"
	family = GNFamily.Type.TOP
	node_description = "Tile/repeat a texture with optional mirroring."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture to tile")
	add_output("out", GNFamily.Type.TOP, "Tiled texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2("repeat", Vector2(2.0, 2.0), "", "Repeat count per axis"))
	add_parameter(GNParameter.create_vector2("offset", Vector2.ZERO, "", "UV offset"))
	add_parameter(GNParameter.create_bool("mirror_x", false, "", "Mirror on horizontal repeats"))
	add_parameter(GNParameter.create_bool("mirror_y", false, "", "Mirror on vertical repeats"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_in == null:
		GNLogger.warn("TileTOP", "'%s' — no valid input" % id)
		return null

	_ensure_viewport()

	var rep: Vector2 = get_param_value("repeat")
	var off: Vector2 = get_param_value("offset")
	var mx: bool = get_param_value("mirror_x")
	var my: bool = get_param_value("mirror_y")
	var res: Vector2i = tex_in.resolution

	if _viewport.size != res:
		_viewport.size = res

	_canvas.texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("repeat_count", rep)
	_material.set_shader_parameter("tile_offset", off)
	_material.set_shader_parameter("mirror_x", mx)
	_material.set_shader_parameter("mirror_y", my)

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _ensure_viewport() -> void:
	if _viewport != null:
		return

	_shader = load("res://addons/gonodes/shaders/tile.gdshader") as Shader

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
	GNLogger.debug("TileTOP", "'%s' viewport created" % id)
