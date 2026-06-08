class_name RemapTOP
extends GNTopBase
## Per-pixel value remapping via a UV displacement map (texture B's RG channels
## as new UV coords) or via a 1D LUT (luminance → gradient lookup).


func _init() -> void:
	node_type = "remap"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Source texture", "In")
	add_input("map", GNFamily.Type.TOP, false, "UV map or LUT texture", "Map")
	add_output("out", GNFamily.Type.TOP, "Remapped texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["UV Remap", "Value Remap (LUT)"]), 0, "",
		"Remap method — UV displaces coordinates, Value uses luminance as LUT index"))
	add_parameter(GNParameter.create_float("strength", 1.0, 0.0, 2.0, 0.01, "Effect strength",
		"Remap strength / blend amount"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("RemapTOP", "'%s' — no valid input on port 0" % id)
		return null

	var tex_map: GNTextureData = _get_input_top(inputs, 1)

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/remap.gdshader", true, false, res)

	if _viewport.size != res:
		_viewport.size = res

	_material.set_shader_parameter("source_tex", tex_in.texture)
	if tex_map != null:
		_material.set_shader_parameter("map_tex", tex_map.texture)
	_material.set_shader_parameter("remap_mode", get_param_value("mode"))
	_material.set_shader_parameter("strength", get_param_value("strength"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
