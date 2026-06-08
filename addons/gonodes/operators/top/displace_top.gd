class_name DisplaceTOP
extends GNTopBase
## Displaces the UV coordinates of a source texture using a displacement map.

var _shader: Shader = null


func _init() -> void:
	node_type = "displace"


func _init_ports() -> void:
	add_input("source", GNFamily.Type.TOP, false, "Texture to distort", "Source")
	add_input("displace", GNFamily.Type.TOP, false, "Displacement map", "Displace")
	add_output("out", GNFamily.Type.TOP, "Displaced texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("weight", 0.1, 0.0, 2.0, 0.01, "Weight", "Displacement strength"))
	add_parameter(GNParameter.create_enum("method",
		PackedStringArray(["RG as XY", "Luminance", "RGB as XYZ"]), 0, "", "How to read the displacement map"))
	add_parameter(GNParameter.create_vector2("scale", Vector2(1.0, 1.0), "Scale", "Per-axis displacement scale"))


func _cook(inputs: Array[GNData]) -> GNData:
	var source: GNTextureData = _get_input_top(inputs, 0)
	var disp: GNTextureData = _get_input_top(inputs, 1)

	if source == null:
		GNLogger.warn("DisplaceTOP", "'%s' — no valid source input" % id)
		return null

	var res: Vector2i = source.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/displace.gdshader", true, false, res)

	var weight_val: float = get_param_value("weight")
	var method_idx: int = get_param_value("method")
	var scale_val: Vector2 = get_param_value("scale")

	if _viewport.size != res:
		_viewport.size = res

	_material.set_shader_parameter("source_tex", source.texture)
	if disp != null:
		_material.set_shader_parameter("displace_tex", disp.texture)
	_material.set_shader_parameter("displace_weight", weight_val)
	_material.set_shader_parameter("displace_method", method_idx)
	_material.set_shader_parameter("displace_scale", scale_val)

	_cached_tex_data.resolution = res
	return _cached_tex_data

