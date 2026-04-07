class_name ReorderTOP
extends GNTopBase
## Reorder or shuffle the channels of a texture.
##
## Maps RGBA output channels from any combination of input RGBA channels.
## Useful for swizzling, extracting single channels, or converting
## data packed in unusual channel layouts.
##
## TouchDesigner equivalent: Reorder TOP.

const SHADER_PATH := "res://addons/gonodes/shaders/top/reorder_top.gdshader"


func _init() -> void:
	node_type = "reorder"
	deprecated = true
	deprecation_message = "Use ChannelMixTOP instead — it supports channel remapping plus per-channel gain."
	deprecated_replacement = "ChannelMixTOP"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Source texture")
	add_output("out", GNFamily.Type.TOP, "Swizzled texture")


func _init_parameters() -> void:
	var channels := ["Red", "Green", "Blue", "Alpha", "One", "Zero", "Luminance"]
	add_parameter(GNParameter.create_enum("output_r", channels, 0,
		"Output R", "Source for output red channel"))
	add_parameter(GNParameter.create_enum("output_g", channels, 1,
		"Output G", "Source for output green channel"))
	add_parameter(GNParameter.create_enum("output_b", channels, 2,
		"Output B", "Source for output blue channel"))
	add_parameter(GNParameter.create_enum("output_a", channels, 3,
		"Output A", "Source for output alpha channel"))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(1024, 1024),
		"Resolution", "Output resolution"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_in == null or tex_in.texture == null:
		return null

	var res: Vector2i = get_param_value("resolution")
	_init_shader_viewport(SHADER_PATH, true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("output_r", get_param_value("output_r"))
	_material.set_shader_parameter("output_g", get_param_value("output_g"))
	_material.set_shader_parameter("output_b", get_param_value("output_b"))
	_material.set_shader_parameter("output_a", get_param_value("output_a"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
