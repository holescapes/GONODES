class_name KeyMixTOP
extends GNTopBase
## Blends two textures using a third texture as a matte/mask.
##
## The matte controls how much of B shows through A on a per-pixel basis.
## Essential compositing utility — more flexible than CompositeTOP's
## global opacity because the mix factor varies spatially.


func _init() -> void:
	node_type = "key_mix"


func _init_ports() -> void:
	add_input("A", GNFamily.Type.TOP, false, "Background texture", "A")
	add_input("B", GNFamily.Type.TOP, false, "Foreground texture", "B")
	add_input("matte", GNFamily.Type.TOP, false, "Matte / mask texture", "Matte")
	add_output("out", GNFamily.Type.TOP, "Blended result", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("matte_channel",
		PackedStringArray(["Luma", "Red", "Green", "Blue", "Alpha"]), 0,
		"Matte Channel", "Which channel of the matte texture to use as mix factor"))
	add_parameter(GNParameter.create_float("opacity", 1.0, 0.0, 1.0, 0.01,
		"Opacity", "Global mix strength"))
	add_parameter(GNParameter.create_bool("invert", false,
		"Invert Matte", "Flip the matte so white becomes transparent"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_a: GNTextureData = _get_input_top(inputs, 0)
	var tex_b: GNTextureData = _get_input_top(inputs, 1)
	var tex_matte: GNTextureData = _get_input_top(inputs, 2)

	if tex_a == null:
		return null

	var res: Vector2i = tex_a.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/key_mix.gdshader", true, false, res)
	if _viewport.size != res:
		_viewport.size = res

	_material.set_shader_parameter("texture_a", tex_a.texture)
	_material.set_shader_parameter("texture_b", tex_b.texture if tex_b != null else null)
	_material.set_shader_parameter("matte_tex", tex_matte.texture if tex_matte != null else null)
	_material.set_shader_parameter("matte_channel", get_param_value("matte_channel"))
	_material.set_shader_parameter("opacity", get_param_value("opacity"))
	_material.set_shader_parameter("invert_matte", get_param_value("invert"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
