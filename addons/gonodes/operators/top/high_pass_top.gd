class_name HighPassTOP
extends GNTopBase
## @deprecated Use FilterTOP (mode = High Pass) instead.
## Extracts high-frequency detail by subtracting a blurred version from the original.


func _init() -> void:
	node_type = "high_pass"
	deprecated = true
	deprecation_message = "Use FilterTOP (mode = High Pass) instead."
	deprecated_replacement = "FilterTOP"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "High-pass filtered texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("radius", 5.0, 1.0, 50.0, 0.5,
		"Radius", "Blur radius for the low-pass subtraction"))
	add_parameter(GNParameter.create_float("strength", 1.0, 0.0, 5.0, 0.1,
		"Strength", "High-pass intensity multiplier"))
	add_parameter(GNParameter.create_float("offset", 0.5, 0.0, 1.0, 0.01,
		"Offset", "Mid-gray offset (0.5 = neutral gray background)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("HighPassTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/high_pass.gdshader", true, true, res)

	_ensure_viewport_size(res)

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("radius", get_param_value("radius"))
	_material.set_shader_parameter("strength", get_param_value("strength"))
	_material.set_shader_parameter("offset", get_param_value("offset"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
