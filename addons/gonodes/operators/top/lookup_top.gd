class_name LookupTOP
extends GNTopBase
## Remaps the colors of a source texture using a second texture as a lookup table.
## Luminance of the source indexes into the lookup ramp texture.

var _shader: Shader = null


func _init() -> void:
	node_type = "lookup"


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

	var res: Vector2i = source.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/lookup.gdshader", true, false, res)

	var index_mode: int = get_param_value("index_by")

	if _viewport.size != res:
		_viewport.size = res

	_material.set_shader_parameter("source_tex", source.texture)
	if ramp_tex != null:
		_material.set_shader_parameter("lookup_tex", ramp_tex.texture)
	_material.set_shader_parameter("lookup_channel", index_mode)

	_cached_tex_data.resolution = res
	return _cached_tex_data

