class_name FilterTOP
extends GNTopBase
## Spatial frequency filter — Low Pass (blur), High Pass (detail extraction),
## or Band Pass (isolates a frequency range).  Mirrors FilterCHOP's design
## but operates on texture data in the spatial domain.


func _init() -> void:
	node_type = "filter"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Filtered texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Low Pass", "High Pass", "Band Pass"]), 0,
		"Mode", "Filter type"))
	add_parameter(GNParameter.create_float("radius", 5.0, 1.0, 50.0, 0.5,
		"Radius", "Filter radius in pixels (Low/High Pass kernel size, Band Pass inner radius)"))
	add_parameter(GNParameter.create_float("radius_outer", 15.0, 1.0, 80.0, 0.5,
		"Outer Radius", "Band Pass only — outer blur radius (must be > radius)"))
	add_parameter(GNParameter.create_float("strength", 1.0, 0.0, 5.0, 0.1,
		"Strength", "Filter intensity multiplier (High/Band Pass only)"))
	add_parameter(GNParameter.create_float("offset", 0.5, 0.0, 1.0, 0.01,
		"Offset", "Mid-gray shift for High/Band Pass (0.5 = neutral)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("FilterTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/filter.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	var mode_val: int = get_param_value("mode")
	var radius_val: float = get_param_value("radius")
	var radius_outer_val: float = get_param_value("radius_outer")

	# Enforce outer > inner for band pass
	if mode_val == 2 and radius_outer_val <= radius_val:
		radius_outer_val = radius_val + 1.0

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("mode", mode_val)
	_material.set_shader_parameter("radius", radius_val)
	_material.set_shader_parameter("radius_outer", radius_outer_val)
	_material.set_shader_parameter("strength", get_param_value("strength"))
	_material.set_shader_parameter("offset", get_param_value("offset"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
