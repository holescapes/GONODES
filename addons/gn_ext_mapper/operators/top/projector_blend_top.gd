class_name ProjectorBlendTOP
extends GNTopBase
## Multi-projector overlap blending with gamma-corrected luminance curves.
## Mimics TD's ProjectorBlend — composites two projector feeds with
## perceptually correct brightness in the overlap zone, black level
## compensation, and per-projector color correction for white-point matching.


func _init() -> void:
	node_type = "projector_blend"
	node_description = "Multi-projector luminance blending with overlap correction and color matching."


func _init_ports() -> void:
	add_input("proj_a", GNFamily.Type.TOP, false, "Projector A (left/top)", "Proj A")
	add_input("proj_b", GNFamily.Type.TOP, false, "Projector B (right/bottom)", "Proj B")
	add_output("out", GNFamily.Type.TOP, "Blended composite", "Out")


func _init_parameters() -> void:
	# Overlap geometry
	add_parameter(GNParameter.create_float("overlap_start", 0.4, 0.0, 1.0, 0.001, "Overlap Start",
		"Normalized position where overlap begins (projector A starts fading)"))
	add_parameter(GNParameter.create_float("overlap_end", 0.6, 0.0, 1.0, 0.001, "Overlap End",
		"Normalized position where overlap ends (projector B finishes fading in)"))
	add_parameter(GNParameter.create_enum("blend_axis",
		PackedStringArray(["Horizontal", "Vertical"]), 0, "Blend Axis",
		"Axis along which projectors overlap"))
	# Blend curve
	add_parameter(GNParameter.create_float("blend_gamma", 2.2, 0.1, 5.0, 0.01, "Blend Gamma",
		"Gamma correction for perceptually linear luminance blend"))
	add_parameter(GNParameter.create_float("blend_exponent", 1.0, 0.1, 4.0, 0.01, "Blend Exponent",
		"Power curve shape (1=linear, 2=ease-in/out)"))
	# Per-projector color correction
	add_parameter(GNParameter.create_color("color_a", Color(1.0, 1.0, 1.0), "Color A",
		"Projector A color tint for white-point matching"))
	add_parameter(GNParameter.create_color("color_b", Color(1.0, 1.0, 1.0), "Color B",
		"Projector B color tint for white-point matching"))
	add_parameter(GNParameter.create_float("brightness_a", 1.0, 0.0, 2.0, 0.01, "Brightness A",
		"Projector A brightness multiplier"))
	add_parameter(GNParameter.create_float("brightness_b", 1.0, 0.0, 2.0, 0.01, "Brightness B",
		"Projector B brightness multiplier"))
	# Black level
	add_parameter(GNParameter.create_float("black_level", 0.0, 0.0, 0.1, 0.001, "Black Level",
		"Physical projector black level for overlap compensation"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_a: GNTextureData = _get_input_top(inputs, 0)
	var tex_b: GNTextureData = _get_input_top(inputs, 1)

	if tex_a == null:
		GNLogger.warn("ProjectorBlendTOP", "'%s' — no valid input on port proj_a" % id)
		return null

	var res: Vector2i = tex_a.resolution
	_init_shader_viewport("res://addons/gn_ext_mapper/shaders/projector_blend.gdshader", true, false, res)

	if _viewport.size != res:
		_viewport.size = res

	_material.set_shader_parameter("proj_a", tex_a.texture)
	if tex_b != null:
		_material.set_shader_parameter("proj_b", tex_b.texture)

	# Overlap geometry
	_material.set_shader_parameter("overlap_start", get_param_value("overlap_start"))
	_material.set_shader_parameter("overlap_end", get_param_value("overlap_end"))
	_material.set_shader_parameter("blend_axis", get_param_value("blend_axis"))
	# Blend curve
	_material.set_shader_parameter("blend_gamma", get_param_value("blend_gamma"))
	_material.set_shader_parameter("blend_exponent", get_param_value("blend_exponent"))
	# Color correction
	var ca: Color = get_param_value("color_a")
	var cb: Color = get_param_value("color_b")
	_material.set_shader_parameter("color_a", Vector3(ca.r, ca.g, ca.b))
	_material.set_shader_parameter("color_b", Vector3(cb.r, cb.g, cb.b))
	_material.set_shader_parameter("brightness_a", get_param_value("brightness_a"))
	_material.set_shader_parameter("brightness_b", get_param_value("brightness_b"))
	# Black level
	_material.set_shader_parameter("black_level", get_param_value("black_level"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
