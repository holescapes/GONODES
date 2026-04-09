class_name DeformTOP
extends GNTopBase
## Deform/displace a texture using a second texture as a displacement map.
##
## The deform texture's RG channels control horizontal/vertical displacement.
## Three modes: Displace (raw UV shift), Refract (luminance-weighted), and
## Warp (polar displacement).
##
## TouchDesigner equivalent: Deform TOP.

const SHADER_PATH := "res://addons/gonodes/shaders/top/deform_top.gdshader"


func _init() -> void:
	node_type = "deform"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Source texture")
	add_input("deform", GNFamily.Type.TOP, false, "Displacement map (RG = UV offset)")
	add_output("out", GNFamily.Type.TOP, "Deformed texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("strength", 0.1, 0.0, 1.0, 0.001,
		"Strength", "Displacement strength"))
	add_parameter(GNParameter.create_enum("mode", ["Displace", "Refract", "Warp"],
		0, "Mode", "Deformation algorithm"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	var deform_in: GNTextureData = inputs[1] as GNTextureData if inputs.size() > 1 and inputs[1] is GNTextureData else null
	if tex_in == null or tex_in.texture == null:
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport(SHADER_PATH, true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("deform_tex", deform_in.texture if deform_in != null else null)
	_material.set_shader_parameter("strength", get_param_value("strength"))
	_material.set_shader_parameter("mode", get_param_value("mode"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
