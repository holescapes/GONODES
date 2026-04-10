class_name ZCompositeTOP
extends GNTopBase
## Depth-based compositing — merges two render passes by comparing their
## depth buffers.  Outputs the pixel from whichever pass is closer (or
## farther) to the camera.
##
## Typical setup: two MultiBufferRenderTOPs, each providing a colour and
## depth output, wired into ZCompositeTOP's four inputs.


func _init() -> void:
	node_type = "z_composite"


func _init_ports() -> void:
	add_input("color_a", GNFamily.Type.TOP, false, "Colour texture A")
	add_input("depth_a", GNFamily.Type.TOP, false, "Depth texture A")
	add_input("color_b", GNFamily.Type.TOP, false, "Colour texture B")
	add_input("depth_b", GNFamily.Type.TOP, false, "Depth texture B")
	add_output("out", GNFamily.Type.TOP, "Z-composited result")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("compare",
		PackedStringArray(["Nearer", "Farther"]), 0,
		"Compare", "Which depth wins — Nearer keeps closer pixels"))
	add_parameter(GNParameter.create_float("bias", 0.0, -0.01, 0.01, 0.0001,
		"Depth Bias", "Small offset to resolve Z-fighting between equal depths"))


func _cook(inputs: Array[GNData]) -> GNData:
	var col_a: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	var dep_a: GNTextureData = inputs[1] as GNTextureData if inputs.size() > 1 and inputs[1] is GNTextureData else null
	var col_b: GNTextureData = inputs[2] as GNTextureData if inputs.size() > 2 and inputs[2] is GNTextureData else null
	var dep_b: GNTextureData = inputs[3] as GNTextureData if inputs.size() > 3 and inputs[3] is GNTextureData else null

	if col_a == null:
		return null

	var res: Vector2i = col_a.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/z_composite.gdshader", true, false, res)
	if _viewport.size != res:
		_viewport.size = res

	_material.set_shader_parameter("color_a", col_a.texture)
	_material.set_shader_parameter("depth_a", dep_a.texture if dep_a != null else col_a.texture)
	_material.set_shader_parameter("color_b", col_b.texture if col_b != null else null)
	_material.set_shader_parameter("depth_b", dep_b.texture if dep_b != null else null)
	_material.set_shader_parameter("compare_mode", get_param_value("compare"))
	_material.set_shader_parameter("bias", get_param_value("bias"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
