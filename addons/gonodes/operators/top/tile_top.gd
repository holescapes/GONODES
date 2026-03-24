class_name TileTOP
extends GNTopBase
## Tiles/repeats an input texture with configurable repeat count and mirroring.

var _shader: Shader = null


func _init() -> void:
	node_type = "tile"


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

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/tile.gdshader", true, true, res)

	var rep: Vector2 = get_param_value("repeat")
	var off: Vector2 = get_param_value("offset")
	var mx: bool = get_param_value("mirror_x")
	var my: bool = get_param_value("mirror_y")

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("repeat_count", rep)
	_material.set_shader_parameter("tile_offset", off)
	_material.set_shader_parameter("mirror_x", mx)
	_material.set_shader_parameter("mirror_y", my)

	_cached_tex_data.resolution = res
	return _cached_tex_data

