class_name MotionBlurTOP
extends GNTopBase
## Temporal motion blur driven by optical flow vectors.
##
## Takes a colour texture and a flow/motion-vector texture (e.g. from
## OpticalFlowTOP) and blurs along the per-pixel motion direction.
## Produces realistic motion streaks proportional to movement speed.


func _init() -> void:
	node_type = "motion_blur"


func _init_ports() -> void:
	add_input("color", GNFamily.Type.TOP, false, "Source colour texture", "Color")
	add_input("flow", GNFamily.Type.TOP, false, "Motion vector texture (RG channels)", "Flow")
	add_output("out", GNFamily.Type.TOP, "Motion-blurred texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("strength", 1.0, 0.0, 2.0, 0.01,
		"Strength", "Motion blur intensity multiplier"))
	add_parameter(GNParameter.create_enum("quality",
		PackedStringArray(["Low", "Medium", "High"]), 1,
		"Quality", "Sample count: Low=4, Medium=8, High=16"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_color: GNTextureData = _get_input_top(inputs, 0)
	var tex_flow: GNTextureData = _get_input_top(inputs, 1)

	if tex_color == null:
		return null

	var res: Vector2i = tex_color.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/motion_blur.gdshader", true, false, res)
	_ensure_viewport_size(res)

	var quality: int = get_param_value("quality")
	var samples: int = [4, 8, 16][quality]

	_material.set_shader_parameter("color_tex", tex_color.texture)
	_material.set_shader_parameter("flow_tex", tex_flow.texture if tex_flow != null else null)
	_material.set_shader_parameter("strength", get_param_value("strength"))
	_material.set_shader_parameter("num_samples", samples)

	_cached_tex_data.resolution = res
	return _cached_tex_data
