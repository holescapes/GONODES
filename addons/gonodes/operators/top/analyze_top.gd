class_name AnalyzeTOP
extends GNTopBase
## Computes per-pixel statistics (min, max, average, sum) over a configurable
## neighbourhood kernel.  Useful for adaptive effects and data inspection.


func _init() -> void:
	node_type = "analyze"
	node_description = "Per-pixel min/max/average/sum statistics over a neighbourhood kernel."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture to analyze")
	add_output("out", GNFamily.Type.TOP, "Analyzed texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Min", "Max", "Average", "Sum"]), 0, "", "Statistical operation"))
	add_parameter(GNParameter.create_int("kernel_size", 8, 1, 64, "Kernel Size", "Neighbourhood radius in pixels"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("AnalyzeTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/analyze.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("mode", get_param_value("mode"))
	_material.set_shader_parameter("kernel_size", get_param_value("kernel_size"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
