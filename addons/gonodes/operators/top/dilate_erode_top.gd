class_name DilateErodeTOP
extends GNTopBase
## Morphological dilation (expand bright areas) and erosion (shrink bright areas).
## Uses a circular footprint for smooth results.


func _init() -> void:
	node_type = "dilate_erode"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Dilated/eroded texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Dilate", "Erode"]), 0, "", "Dilate expands bright areas, Erode shrinks them"))
	add_parameter(GNParameter.create_int("radius", 2, 1, 16, "Radius",
		"Morphological kernel radius in pixels"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("DilateErodeTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/dilate_erode.gdshader", true, true, res)

	_ensure_viewport_size(res)

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("mode", get_param_value("mode"))
	_material.set_shader_parameter("radius", get_param_value("radius"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
