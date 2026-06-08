class_name PolarTOP
extends GNTopBase
## Converts between Cartesian and Polar coordinate spaces.


func _init() -> void:
	node_type = "polar"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Coordinate-transformed texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Cartesian to Polar", "Polar to Cartesian"]), 0,
		"", "Conversion direction"))
	add_parameter(GNParameter.create_vector2("center", Vector2(0.5, 0.5),
		"Center", "Center point for the transform"))
	add_parameter(GNParameter.create_float("rotation", 0.0, 0.0, 1.0, 0.01,
		"Rotation", "Rotates the seam position (0–1 = full turn)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("PolarTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/polar.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("mode", get_param_value("mode"))
	_material.set_shader_parameter("center", get_param_value("center"))
	_material.set_shader_parameter("rotation", get_param_value("rotation"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
