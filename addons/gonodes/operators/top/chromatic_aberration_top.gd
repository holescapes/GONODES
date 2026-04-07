class_name ChromaticAberrationTOP
extends GNTopBase
## Splits RGB channels with a configurable offset for chromatic aberration.
## Supports radial (from center) and directional (fixed angle) modes.


func _init() -> void:
	node_type = "chromatic_aberration"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Aberrated texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("intensity", 0.005, 0.0, 0.1, 0.001,
		"Intensity", "Split amount (fraction of image width)"))
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Radial", "Directional"]), 0,
		"", "Radial = from center, Directional = fixed angle"))
	add_parameter(GNParameter.create_float("angle", 0.0, 0.0, 360.0, 1.0,
		"Angle", "Direction angle in degrees (Directional mode only)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("ChromaticAberrationTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/chromatic_aberration.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("intensity", get_param_value("intensity"))
	_material.set_shader_parameter("mode", get_param_value("mode"))
	_material.set_shader_parameter("angle", get_param_value("angle"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
