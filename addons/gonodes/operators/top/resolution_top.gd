class_name ResolutionTOP
extends GNTopBase
## Resizes an input texture to a target resolution using a SubViewport.


func _init() -> void:
	node_type = "resolution"
	node_description = "Resize a texture to a different resolution."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture to resize")
	add_output("out", GNFamily.Type.TOP, "Resized texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(1920, 1080), "Output Resolution", "Target output resolution"))
	add_parameter(GNParameter.create_enum("filter",
		PackedStringArray(["Linear", "Nearest"]), 0, "", "Filtering mode (Linear = smooth, Nearest = pixelated)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_in == null:
		GNLogger.warn("ResolutionTOP", "'%s' — no valid input" % id)
		return null

	_setup_viewport()

	var res: Vector2i = get_param_value("resolution")
	var filter_idx: int = get_param_value("filter")

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if filter_idx == 0 else CanvasItem.TEXTURE_FILTER_NEAREST

	_cached_tex_data.resolution = res

	# Invertible: pure resolution scale. Inverse maps output pixels back to input pixels.
	if tex_in.panel_sources.size() > 0:
		_cached_tex_data.panel_sources.clear()
		var src_res := Vector2(tex_in.resolution)
		var dst_res := Vector2(res)
		var inv_t := Transform2D.IDENTITY.scaled(Vector2(src_res.x / dst_res.x, src_res.y / dst_res.y))
		for ps in tex_in.panel_sources:
			var copy: GNPanelSource = ps.duplicate_source()
			copy.transform = copy.transform * inv_t
			_cached_tex_data.panel_sources.append(copy)

	return _cached_tex_data


func _setup_viewport() -> void:
	if _viewport != null:
		return

	_ensure_viewport(get_param_value("resolution"))

	_canvas = TextureRect.new()
	_canvas.name = "Canvas"
	_canvas.stretch_mode = TextureRect.STRETCH_SCALE
	_viewport.add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
