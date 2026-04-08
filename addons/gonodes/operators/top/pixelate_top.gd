class_name PixelateTOP
extends GNTopBase
## Block mosaic / pixelation effect — snaps pixels to a grid.


func _init() -> void:
	node_type = "pixelate"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Pixelated texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("pixel_size", 8.0, 1.0, 256.0, 1.0,
		"Pixel Size", "Block size in pixels"))
	add_parameter(GNParameter.create_enum("shape",
		PackedStringArray(["Square", "Circle", "Diamond", "Hexagon"]), 0,
		"Shape", "Pixel block shape"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("PixelateTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/pixelate.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("pixel_size", get_param_value("pixel_size"))
	_material.set_shader_parameter("shape", get_param_value("shape"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
