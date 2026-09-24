class_name LensFlareTOP
extends GNTopBase
## Procedural lens flare — ghosts, anamorphic streaks, and halo ring.
##
## Generates flare elements from bright areas in the input image.
## All parameters are artist-tuneable.  No external textures needed —
## everything is computed procedurally in the shader.


func _init() -> void:
	node_type = "lens_flare"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Source texture (bright areas trigger flares)", "In")
	add_output("out", GNFamily.Type.TOP, "Input + lens flare overlay", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("threshold", 0.8, 0.0, 2.0, 0.01,
		"Threshold", "Brightness threshold — only pixels above this contribute to flares"))
	add_parameter(GNParameter.create_float("ghost_intensity", 0.6, 0.0, 2.0, 0.01,
		"Ghost Intensity", "Brightness of ghost copies"))
	add_parameter(GNParameter.create_int("ghost_count", 4, 1, 8,
		"Ghost Count", "Number of ghost reflections"))
	add_parameter(GNParameter.create_float("ghost_spacing", 0.3, 0.1, 1.0, 0.01,
		"Ghost Spacing", "Distance between ghost copies"))
	add_parameter(GNParameter.create_float("halo_intensity", 0.4, 0.0, 2.0, 0.01,
		"Halo Intensity", "Brightness of the halo ring"))
	add_parameter(GNParameter.create_float("halo_radius", 0.5, 0.0, 1.0, 0.01,
		"Halo Radius", "Distance of halo ring from centre"))
	add_parameter(GNParameter.create_float("halo_width", 0.06, 0.01, 0.3, 0.01,
		"Halo Width", "Thickness of the halo ring"))
	add_parameter(GNParameter.create_float("streak_intensity", 0.3, 0.0, 2.0, 0.01,
		"Streak Intensity", "Anamorphic horizontal streak brightness"))
	add_parameter(GNParameter.create_float("streak_length", 0.15, 0.0, 0.5, 0.01,
		"Streak Length", "Horizontal streak spread"))
	add_parameter(GNParameter.create_color("tint", Color(1.0, 0.9, 0.7, 1.0),
		"Tint", "Colour tint applied to all flare elements"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/lens_flare.gdshader", true, false, res)
	_ensure_viewport_size(res)

	var tint_col: Color = get_param_value("tint")

	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("threshold", get_param_value("threshold"))
	_material.set_shader_parameter("ghost_intensity", get_param_value("ghost_intensity"))
	_material.set_shader_parameter("ghost_count", get_param_value("ghost_count"))
	_material.set_shader_parameter("ghost_spacing", get_param_value("ghost_spacing"))
	_material.set_shader_parameter("halo_intensity", get_param_value("halo_intensity"))
	_material.set_shader_parameter("halo_radius", get_param_value("halo_radius"))
	_material.set_shader_parameter("halo_width", get_param_value("halo_width"))
	_material.set_shader_parameter("streak_intensity", get_param_value("streak_intensity"))
	_material.set_shader_parameter("streak_length", get_param_value("streak_length"))
	_material.set_shader_parameter("tint", Vector3(tint_col.r, tint_col.g, tint_col.b))

	_cached_tex_data.resolution = res
	return _cached_tex_data
