class_name BokehBlurTOP
extends GNTopBase
## Shaped blur (disc or hexagonal) for depth-of-field / bokeh look.


func _init() -> void:
	node_type = "bokeh_blur"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Bokeh-blurred texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("radius", 8.0, 0.0, 64.0, 0.5,
		"Radius", "Blur radius in pixels"))
	add_parameter(GNParameter.create_enum("shape",
		PackedStringArray(["Disc", "Hexagon"]), 0,
		"Shape", "Bokeh iris shape"))
	add_parameter(GNParameter.create_int("quality", 3, 1, 8,
		"Quality", "Sample rings (higher = smoother, slower)"))
	add_parameter(GNParameter.create_float("brightness", 1.0, 0.0, 5.0, 0.1,
		"Highlight Boost", "Extra brightness for highlight bokeh circles"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("BokehBlurTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/bokeh_blur.gdshader", true, true, res)

	_ensure_viewport_size(res)

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("radius_px", get_param_value("radius"))
	_material.set_shader_parameter("shape", get_param_value("shape"))
	_material.set_shader_parameter("quality", get_param_value("quality"))
	_material.set_shader_parameter("brightness", get_param_value("brightness"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
