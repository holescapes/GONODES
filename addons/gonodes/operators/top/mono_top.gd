class_name MonoTOP
extends GNTopBase
## Converts input to grayscale using configurable luma-weight methods.
## Rec.709 (HDTV), Rec.601 (SDTV), Average, or Desaturate.


func _init() -> void:
	node_type = "mono"
	node_description = "Grayscale conversion with Rec.709, Rec.601, Average, or Desaturate method."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Grayscale texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("method",
		PackedStringArray(["Rec.709", "Rec.601", "Average", "Desaturate"]), 0, "",
		"Luma weighting method"))
	add_parameter(GNParameter.create_float("mix", 1.0, 0.0, 1.0, 0.01, "Mix",
		"Blend between original color (0) and grayscale (1)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("MonoTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/mono.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("method", get_param_value("method"))
	_material.set_shader_parameter("mix_amount", get_param_value("mix"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
