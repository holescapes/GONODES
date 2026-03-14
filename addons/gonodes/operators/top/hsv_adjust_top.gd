class_name HSVAdjustTOP
extends GNTopBase
## Adjusts hue, saturation, and value (brightness) of an input texture.
## Operates in HSV color space.

var _shader: Shader = null


func _init() -> void:
	node_type = "hsv_adjust"
	node_description = "Hue offset, saturation, and value (brightness) adjustment."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "HSV-adjusted texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("hue_offset", 0.0, -1.0, 1.0, 0.01, "", "Hue rotation (wraps around)"))
	add_parameter(GNParameter.create_float("saturation", 1.0, 0.0, 4.0, 0.01, "", "Saturation multiplier (0 = grayscale)"))
	add_parameter(GNParameter.create_float("value", 1.0, 0.0, 4.0, 0.01, "", "Value/brightness multiplier"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_in == null:
		GNLogger.warn("HSVAdjustTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/hsv_adjust.gdshader", true, true, res)

	var hue: float = get_param_value("hue_offset")
	var sat: float = get_param_value("saturation")
	var val: float = get_param_value("value")

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("hue_offset", hue)
	_material.set_shader_parameter("saturation_mult", sat)
	_material.set_shader_parameter("value_mult", val)

	_cached_tex_data.resolution = res
	return _cached_tex_data

