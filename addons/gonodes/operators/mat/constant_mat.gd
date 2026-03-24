class_name ConstantMAT
extends GNMatBase
## Flat unlit (constant) material — no lighting applied.
##
## Outputs a StandardMaterial3D in SHADING_MODE_UNSHADED.
## Accepts an optional TOP input for an albedo texture override.
## Useful for debug views, UI elements, or stylized flat rendering.

var _material: StandardMaterial3D = null


func _init() -> void:
	node_type = "constant"


func _init_ports() -> void:
	add_input("color_tex", GNFamily.Type.TOP, false, "Color texture (optional)", "Color Texture")
	add_output("out", GNFamily.Type.MAT, "Constant material output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_color("color", Color.WHITE, "Color", "Flat surface color"))
	add_parameter(GNParameter.create_float("alpha", 1.0, 0.0, 1.0, 0.01, "Alpha", "Opacity"))
	add_parameter(GNParameter.create_enum("cull_mode",
		PackedStringArray(["Back", "Front", "Disabled"]),
		0, "Cull Mode", "Face culling"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null

	# Lazy-init
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var color: Color = get_param_value("color")
	var alpha_val: float = get_param_value("alpha")
	color.a = alpha_val
	_material.albedo_color = color

	# Transparency
	if alpha_val < 1.0:
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	else:
		_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED

	# Texture
	if tex_in != null and tex_in.texture != null:
		_material.albedo_texture = tex_in.texture
	else:
		_material.albedo_texture = null

	# Culling
	var cull: int = get_param_value("cull_mode")
	match cull:
		0: _material.cull_mode = BaseMaterial3D.CULL_BACK
		1: _material.cull_mode = BaseMaterial3D.CULL_FRONT
		2: _material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var out := _prepare_output()
	out.material = _material
	out.material_label = "Constant\n%s" % color
	out.valid = true
	out.timestamp = current_frame
	return out
