class_name DepthOfFieldTOP
extends GNTopBase
## Standalone depth-of-field post-process.
##
## Takes any colour texture plus a depth map (e.g. from MultiBufferRenderTOP)
## and applies a variable-radius disc blur based on circle of confusion.
## Unlike RenderTOP's built-in DoF, this works on any TOP + depth pair —
## composited scenes, pre-rendered passes, or synthetic depth maps.


func _init() -> void:
	node_type = "depth_of_field"


func _init_ports() -> void:
	add_input("color", GNFamily.Type.TOP, false, "Colour texture", "Color")
	add_input("depth", GNFamily.Type.TOP, false, "Depth texture (0=near, 1=far)", "Depth")
	add_output("out", GNFamily.Type.TOP, "DoF-blurred texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("focal_distance", 0.5, 0.0, 1.0, 0.001,
		"Focal Distance", "Depth value in focus (0 = near, 1 = far)"))
	add_parameter(GNParameter.create_float("focal_range", 0.1, 0.001, 1.0, 0.001,
		"Focal Range", "Width of the in-focus band around focal distance"))
	add_parameter(GNParameter.create_float("max_blur", 8.0, 0.0, 20.0, 0.5,
		"Max Blur", "Maximum blur radius in pixels"))
	add_parameter(GNParameter.create_float("bokeh_brightness", 1.2, 1.0, 4.0, 0.1,
		"Bokeh Brightness", "Bright-spot emphasis for bokeh character"))
	add_parameter(GNParameter.create_enum("quality",
		PackedStringArray(["Low", "Medium", "High"]), 1,
		"Quality", "Sample count: Low=4, Medium=8, High=16"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_color: GNTextureData = _get_input_top(inputs, 0)
	var tex_depth: GNTextureData = _get_input_top(inputs, 1)

	if tex_color == null:
		return null

	var res: Vector2i = tex_color.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/depth_of_field.gdshader", true, false, res)
	_ensure_viewport_size(res)

	_material.set_shader_parameter("color_tex", tex_color.texture)
	_material.set_shader_parameter("depth_tex", tex_depth.texture if tex_depth != null else tex_color.texture)
	_material.set_shader_parameter("focal_distance", get_param_value("focal_distance"))
	_material.set_shader_parameter("focal_range", get_param_value("focal_range"))
	_material.set_shader_parameter("max_blur", get_param_value("max_blur"))
	_material.set_shader_parameter("bokeh_brightness", get_param_value("bokeh_brightness"))
	_material.set_shader_parameter("quality", get_param_value("quality"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
