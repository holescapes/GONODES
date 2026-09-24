class_name MirrorTOP
extends GNTopBase
## Mirrors the image along an axis at a configurable position and angle.
## Unlike FlipTOP (full reflection), this places a mirror seam at any point.


func _init() -> void:
	node_type = "mirror"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Mirrored texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("axis",
		PackedStringArray(["Vertical", "Horizontal", "Free Angle"]), 0,
		"Axis", "Mirror axis direction"))
	add_parameter(GNParameter.create_vector2("center", Vector2(0.5, 0.5),
		"Center", "Mirror line position (UV space)"))
	add_parameter(GNParameter.create_float("angle", 0.0, 0.0, 360.0, 1.0,
		"Angle", "Mirror angle in degrees (Free Angle mode only)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("MirrorTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/mirror.gdshader", true, true, res)

	_ensure_viewport_size(res)

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("mirror_axis", get_param_value("axis"))
	_material.set_shader_parameter("mirror_center", get_param_value("center"))
	_material.set_shader_parameter("mirror_angle", deg_to_rad(get_param_value("angle")))

	_cached_tex_data.resolution = res
	return _cached_tex_data
