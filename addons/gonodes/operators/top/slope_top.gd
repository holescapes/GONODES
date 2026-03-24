class_name SlopeTOP
extends GNTopBase
## Computes the image gradient / derivative (horizontal, vertical, or magnitude).
## Useful for edge-aware effects and flow-field generation.


func _init() -> void:
	node_type = "slope"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Gradient texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("output",
		PackedStringArray(["Magnitude", "Horizontal (dx)", "Vertical (dy)"]), 0, "",
		"Which gradient component to output"))
	add_parameter(GNParameter.create_float("strength", 1.0, 0.1, 20.0, 0.1, "",
		"Gradient amplification"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("SlopeTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/slope.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("output_mode", get_param_value("output"))
	_material.set_shader_parameter("strength", get_param_value("strength"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
