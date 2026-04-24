class_name FitTOP
extends GNTopBase
## Aspect-aware resize: Fit, Fill, Stretch, or Native.
## Unlike ResolutionTOP's raw resize, FitTOP preserves aspect ratio.


func _init() -> void:
	node_type = "fit"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Resized texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("fit_mode",
		PackedStringArray(["Fit", "Fill", "Stretch", "Native"]), 0, "Fit Mode",
		"How to scale the source into the target resolution"))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "Output resolution",
		"Target output resolution"))
	add_parameter(GNParameter.create_color("border_color", Color.BLACK, "Border Color",
		"Letterbox / pillarbox fill color"))
	add_parameter(GNParameter.create_enum("filter",
		PackedStringArray(["Linear", "Nearest"]), 0, "Filter",
		"Texture filtering (Linear = smooth, Nearest = pixelated)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("FitTOP", "'%s' — no valid input" % id)
		return null

	var target_res: Vector2i = get_param_value("resolution")
	_init_shader_viewport("res://addons/gonodes/shaders/top/fit.gdshader", true, true, target_res)

	if _viewport.size != target_res:
		_viewport.size = target_res

	var bc: Color = get_param_value("border_color")
	var filter_idx: int = get_param_value("filter")

	(_canvas as TextureRect).texture = tex_in.texture
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if filter_idx == 0 else CanvasItem.TEXTURE_FILTER_NEAREST
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("fit_mode", get_param_value("fit_mode"))
	_material.set_shader_parameter("target_size", Vector2(target_res))
	_material.set_shader_parameter("border_color", Vector4(bc.r, bc.g, bc.b, bc.a))

	_cached_tex_data.resolution = target_res

	return _cached_tex_data
