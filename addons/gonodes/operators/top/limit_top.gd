class_name LimitTOP
extends GNTopBase
## Clamp pixel values to a min/max range per channel or by luminance.
##
## Two modes:
##   Per-Channel — clamp R, G, B, A independently to their own min/max.
##   Luminance   — scale RGB so the pixel luminance (Rec.709) stays within
##                 [min, max], preserving colour ratios.

var _shader: Shader = null


func _init() -> void:
	node_type = "limit"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Clamped texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Per-Channel", "Luminance"]), 0, "Mode",
		"Clamp each RGBA channel independently, or scale by luminance"))
	add_parameter(GNParameter.create_float("min_r", 0.0, 0.0, 1.0, 0.01, "Min R", "Minimum red"))
	add_parameter(GNParameter.create_float("max_r", 1.0, 0.0, 1.0, 0.01, "Max R", "Maximum red"))
	add_parameter(GNParameter.create_float("min_g", 0.0, 0.0, 1.0, 0.01, "Min G", "Minimum green"))
	add_parameter(GNParameter.create_float("max_g", 1.0, 0.0, 1.0, 0.01, "Max G", "Maximum green"))
	add_parameter(GNParameter.create_float("min_b", 0.0, 0.0, 1.0, 0.01, "Min B", "Minimum blue"))
	add_parameter(GNParameter.create_float("max_b", 1.0, 0.0, 1.0, 0.01, "Max B", "Maximum blue"))
	add_parameter(GNParameter.create_float("min_a", 0.0, 0.0, 1.0, 0.01, "Min A", "Minimum alpha"))
	add_parameter(GNParameter.create_float("max_a", 1.0, 0.0, 1.0, 0.01, "Max A", "Maximum alpha"))
	add_parameter(GNParameter.create_float("min_luma", 0.0, 0.0, 1.0, 0.01, "Min Luma", "Minimum luminance"))
	add_parameter(GNParameter.create_float("max_luma", 1.0, 0.0, 1.0, 0.01, "Max Luma", "Maximum luminance"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("LimitTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/limit.gdshader", true, true, res)

	var mode_idx: int = get_param_value("mode")
	var is_per_channel: bool = (mode_idx == 0)

	_ensure_viewport_size(res)

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("clamp_rgb", is_per_channel)
	_material.set_shader_parameter("min_r", get_param_value("min_r"))
	_material.set_shader_parameter("max_r", get_param_value("max_r"))
	_material.set_shader_parameter("min_g", get_param_value("min_g"))
	_material.set_shader_parameter("max_g", get_param_value("max_g"))
	_material.set_shader_parameter("min_b", get_param_value("min_b"))
	_material.set_shader_parameter("max_b", get_param_value("max_b"))
	_material.set_shader_parameter("min_a", get_param_value("min_a"))
	_material.set_shader_parameter("max_a", get_param_value("max_a"))
	_material.set_shader_parameter("min_luma", get_param_value("min_luma"))
	_material.set_shader_parameter("max_luma", get_param_value("max_luma"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
