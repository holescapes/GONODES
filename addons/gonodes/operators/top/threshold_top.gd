class_name ThresholdTOP
extends GNTopBase
## Converts an input texture to binary black/white based on luminance threshold.

var _shader: Shader = null


func _init() -> void:
	node_type = "threshold"
	node_description = "Binary black/white threshold with optional softness."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Thresholded texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("threshold", 0.5, 0.0, 1.0, 0.01, "", "Luminance cutoff value"))
	add_parameter(GNParameter.create_float("softness", 0.0, 0.0, 0.5, 0.01, "", "Soft transition width"))
	add_parameter(GNParameter.create_bool("use_alpha", false, "", "Threshold alpha channel instead of luminance"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_in == null:
		GNLogger.warn("ThresholdTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/threshold.gdshader", true, true, res)

	var thresh: float = get_param_value("threshold")
	var soft: float = get_param_value("softness")
	var alpha: bool = get_param_value("use_alpha")

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("threshold_val", thresh)
	_material.set_shader_parameter("softness", soft)
	_material.set_shader_parameter("use_alpha", alpha)

	_cached_tex_data.resolution = res
	return _cached_tex_data

