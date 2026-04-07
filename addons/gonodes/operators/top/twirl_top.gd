class_name TwirlTOP
extends GNTopBase
## Spiral / swirl distortion centered on a point.


func _init() -> void:
	node_type = "twirl"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Twirled texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("strength", 3.0, -10.0, 10.0, 0.1,
		"Strength", "Twist amount in radians (negative = opposite direction)"))
	add_parameter(GNParameter.create_float("radius", 0.5, 0.01, 2.0, 0.01,
		"Radius", "Effect radius as fraction of image"))
	add_parameter(GNParameter.create_vector2("center", Vector2(0.5, 0.5),
		"Center", "Center of the twist"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("TwirlTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/twirl.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("strength", get_param_value("strength"))
	_material.set_shader_parameter("radius", get_param_value("radius"))
	_material.set_shader_parameter("center", get_param_value("center"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
