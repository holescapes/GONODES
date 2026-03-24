class_name TransformTOP
extends GNTopBase
## Applies 2D spatial transformations (translate, rotate, scale) to an input texture.

var _shader: Shader = null


func _init() -> void:
	node_type = "transform"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Transformed texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2("translate", Vector2.ZERO, "", "UV translation"))
	add_parameter(GNParameter.create_float("rotate", 0.0, null, null, 0.01, "Rotate (rad)", "Rotation in radians"))
	add_parameter(GNParameter.create_vector2("scale", Vector2(1.0, 1.0), "", "UV scale"))
	add_parameter(GNParameter.create_vector2("pivot", Vector2(0.5, 0.5), "", "Transform pivot point in UV space"))
	add_parameter(GNParameter.create_enum("extend",
		PackedStringArray(["Clamp", "Repeat", "Mirror", "Zero"]), 0, "", "Edge extension mode"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_in == null:
		GNLogger.warn("TransformTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/transform2d.gdshader", true, true, res)

	var trans: Vector2 = get_param_value("translate")
	var rot: float = get_param_value("rotate")
	var scl: Vector2 = get_param_value("scale")
	var pvt: Vector2 = get_param_value("pivot")
	var ext: int = get_param_value("extend")

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("translate", trans)
	_material.set_shader_parameter("rotate_angle", rot)
	_material.set_shader_parameter("scale_amount", scl)
	_material.set_shader_parameter("pivot", pvt)
	_material.set_shader_parameter("extend_mode", ext)

	_cached_tex_data.resolution = res

	return _cached_tex_data

