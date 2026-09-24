class_name MedianTOP
extends GNTopBase
## Median filter for noise removal and painterly effects.


func _init() -> void:
	node_type = "median"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Median-filtered texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("radius",
		PackedStringArray(["3x3", "5x5"]), 0,
		"Kernel", "Filter kernel size"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("MedianTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/median.gdshader", true, true, res)

	_ensure_viewport_size(res)

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("radius", get_param_value("radius"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
