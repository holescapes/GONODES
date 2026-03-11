class_name FitTOP
extends GNTopBase
## Aspect-aware resize: Fit, Fill, Stretch, or Letterbox.
## Unlike ResolutionTOP's raw resize, FitTOP preserves aspect ratio.


func _init() -> void:
	node_type = "fit"
	node_description = "Aspect-aware resize: Fit, Fill, Stretch, or Letterbox with border color."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Resized texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("fit_mode",
		PackedStringArray(["Fit", "Fill", "Stretch", "Letterbox"]), 0, "Fit Mode",
		"How to scale the source into the target resolution"))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "",
		"Target output resolution"))
	add_parameter(GNParameter.create_color("border_color", Color.BLACK, "Border Color",
		"Letterbox / pillarbox fill color"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("FitTOP", "'%s' — no valid input" % id)
		return null

	var target_res: Vector2i = get_param_value("resolution")
	_init_shader_viewport("res://addons/gonodes/shaders/fit.gdshader", true, true, target_res)

	if _viewport.size != target_res:
		_viewport.size = target_res

	var bc: Color = get_param_value("border_color")

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("fit_mode", get_param_value("fit_mode"))
	_material.set_shader_parameter("source_size", Vector2(tex_in.resolution))
	_material.set_shader_parameter("target_size", Vector2(target_res))
	_material.set_shader_parameter("border_color", Vector4(bc.r, bc.g, bc.b, bc.a))

	_cached_tex_data.resolution = target_res

	# Invertible: aspect-aware resize is scale + translate (letterbox offset).
	if tex_in.panel_sources.size() > 0:
		_cached_tex_data.panel_sources.clear()
		var src := Vector2(tex_in.resolution)
		var dst := Vector2(target_res)
		var mode: int = get_param_value("fit_mode")
		var scale_f: float
		var offset := Vector2.ZERO
		match mode:
			0:  # Fit (scale to fit inside, may have borders)
				scale_f = minf(dst.x / src.x, dst.y / src.y)
				offset = (dst - src * scale_f) * 0.5
			1:  # Fill (scale to cover, may crop)
				scale_f = maxf(dst.x / src.x, dst.y / src.y)
				offset = (dst - src * scale_f) * 0.5
			2:  # Stretch (non-uniform scale, no offset)
				var inv_t := Transform2D.IDENTITY.scaled(Vector2(src.x / dst.x, src.y / dst.y))
				for ps in tex_in.panel_sources:
					var copy: GNPanelSource = ps.duplicate_source()
					copy.transform = copy.transform * inv_t
					_cached_tex_data.panel_sources.append(copy)
				return _cached_tex_data
			3:  # Letterbox (same as Fit)
				scale_f = minf(dst.x / src.x, dst.y / src.y)
				offset = (dst - src * scale_f) * 0.5
		# Inverse: undo offset then undo uniform scale
		var inv_t := Transform2D.IDENTITY
		inv_t = inv_t.translated(-offset)
		inv_t = inv_t.scaled(Vector2(1.0 / scale_f, 1.0 / scale_f))
		for ps in tex_in.panel_sources:
			var copy: GNPanelSource = ps.duplicate_source()
			copy.transform = copy.transform * inv_t
			_cached_tex_data.panel_sources.append(copy)

	return _cached_tex_data
