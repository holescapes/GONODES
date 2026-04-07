class_name LumaBlurTOP
extends GNTopBase
## Luminance-weighted selective blur — bright or dark areas receive more blur
## while the rest stays sharp.  Great for glow-like effects with control.


func _init() -> void:
	node_type = "luma_blur"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Selectively blurred texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("blur_size", 4.0, 0.0, 50.0, 0.1, "Blur Size",
		"Maximum blur radius in pixels"))
	add_parameter(GNParameter.create_int("quality", 4, 1, 8, "Quality",
		"Samples per direction (higher = smoother)"))
	add_parameter(GNParameter.create_float("luma_threshold", 0.5, 0.0, 1.0, 0.01, "Threshold",
		"Luminance cutoff for blur selection"))
	add_parameter(GNParameter.create_bool("blur_bright", true, "Blur Bright",
		"On = blur bright areas, Off = blur dark areas"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("LumaBlurTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/luma_blur.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("blur_size", get_param_value("blur_size"))
	_material.set_shader_parameter("quality", get_param_value("quality"))
	_material.set_shader_parameter("luma_threshold", get_param_value("luma_threshold"))
	_material.set_shader_parameter("blur_bright", get_param_value("blur_bright"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
