class_name EdgeTOP
extends GNTopBase
## Applies Sobel edge detection to an input texture.

var _shader: Shader = null


func _init() -> void:
	node_type = "edge"
	node_description = "Sobel edge detection with configurable strength."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Edge-detected texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("strength", 1.0, 0.0, 10.0, 0.1, "", "Edge strength multiplier"))
	add_parameter(GNParameter.create_bool("grayscale", true, "Grayscale Output", "Output grayscale or colored edges"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_in == null:
		GNLogger.warn("EdgeTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/edge.gdshader", true, true, res)

	var strength_val: float = get_param_value("strength")
	var gray: bool = get_param_value("grayscale")

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("strength", strength_val)
	_material.set_shader_parameter("grayscale_input", gray)

	_cached_tex_data.resolution = res
	return _cached_tex_data

