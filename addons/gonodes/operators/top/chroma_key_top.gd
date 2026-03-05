class_name ChromaKeyTOP
extends GNTopBase
## Green-screen / chroma key and luma key with spill suppression.
## Removes a configurable key color from the input, leaving transparent pixels.


func _init() -> void:
	node_type = "chroma_key"
	node_description = "Green-screen / chroma key / luma key with spill suppression."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture to key")
	add_output("out", GNFamily.Type.TOP, "Keyed texture with transparent background")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("key_mode",
		PackedStringArray(["Chroma", "Luma"]), 0, "Key Mode", "Chroma (color-based) or Luma (brightness-based) keying"))
	add_parameter(GNParameter.create_color("key_color", Color(0.0, 1.0, 0.0), "Key Color", "Color to remove (default green)"))
	add_parameter(GNParameter.create_float("threshold", 0.4, 0.0, 1.0, 0.01, "", "Similarity threshold — lower = tighter key"))
	add_parameter(GNParameter.create_float("smoothness", 0.08, 0.0, 0.5, 0.01, "", "Edge softness ramp width"))
	add_parameter(GNParameter.create_float("spill_reduction", 0.5, 0.0, 1.0, 0.01, "Spill Reduction", "Suppress key color bleeding into edges"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("ChromaKeyTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/chroma_key.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	var kc: Color = get_param_value("key_color")

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("key_mode", get_param_value("key_mode"))
	_material.set_shader_parameter("key_color", Vector3(kc.r, kc.g, kc.b))
	_material.set_shader_parameter("threshold", get_param_value("threshold"))
	_material.set_shader_parameter("smoothness", get_param_value("smoothness"))
	_material.set_shader_parameter("spill_reduction", get_param_value("spill_reduction"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
