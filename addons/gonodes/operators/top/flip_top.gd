class_name FlipTOP
extends GNTopBase
## Flips/mirrors an input texture horizontally, vertically, or both.

var _shader: Shader = null


func _init() -> void:
	node_type = "flip"
	node_description = "Mirror texture horizontally and/or vertically."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Flipped texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("flip_x", false, "Flip Horizontal", "Mirror horizontally"))
	add_parameter(GNParameter.create_bool("flip_y", false, "Flip Vertical", "Mirror vertically"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_in == null:
		GNLogger.warn("FlipTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/flip.gdshader", true, true, res)

	var fx: bool = get_param_value("flip_x")
	var fy: bool = get_param_value("flip_y")

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("flip_x", fx)
	_material.set_shader_parameter("flip_y", fy)

	_cached_tex_data.resolution = res

	# Apply flip inverse to panel_sources (flip is self-inverse).
	if tex_in.panel_sources.size() > 0:
		_cached_tex_data.panel_sources.clear()
		var fres := Vector2(res)
		for ps in tex_in.panel_sources:
			var copy: GNPanelSource = ps.duplicate_source()
			# Flip transform: mirror around center
			if fx or fy:
				var sx: float = -1.0 if fx else 1.0
				var sy: float = -1.0 if fy else 1.0
				var center := fres * 0.5
				var inv_t := Transform2D.IDENTITY
				inv_t = inv_t.translated(-center)
				inv_t = inv_t.scaled(Vector2(sx, sy))
				inv_t = inv_t.translated(center)
				copy.transform = copy.transform * inv_t
			_cached_tex_data.panel_sources.append(copy)

	return _cached_tex_data

