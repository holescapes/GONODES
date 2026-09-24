class_name ColorSpaceTOP
extends GNTopBase
## Converts between color spaces with mathematically correct transfer functions.
## Supports sRGB, Linear, ACEScg, Rec.709, and Rec.2020.


func _init() -> void:
	node_type = "color_space"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Color-space converted texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("conversion",
		PackedStringArray([
			"sRGB → Linear",
			"Linear → sRGB",
			"sRGB → ACEScg",
			"ACEScg → sRGB",
			"Rec.709 → Rec.2020",
			"Rec.2020 → Rec.709",
		]), 0,
		"Conversion", "Color space conversion to apply"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("ColorSpaceTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/color_space.gdshader", true, true, res)

	_ensure_viewport_size(res)

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("conversion", get_param_value("conversion"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
