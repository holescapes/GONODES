class_name NormalMapMAT
extends GNMatBase
## Diagnostic material for visualizing tangent-space normal maps.
## Applies the normal map to a simple lit or unlit surface so you can
## inspect bump detail in the viewport. Accepts a TOP input for the
## normal texture and an optional albedo TOP.

var _material: StandardMaterial3D = null


func _init() -> void:
	node_type = "normal_map"


func _init_ports() -> void:
	add_input("normal_tex", GNFamily.Type.TOP, false, "Normal map texture", "Normal Texture")
	add_input("albedo_tex", GNFamily.Type.TOP, false, "Optional base color texture", "Albedo Texture")
	add_output("out", GNFamily.Type.MAT, "Normal map material output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("normal_scale", 1.0, -4.0, 4.0, 0.05,
		"Normal Scale", "Normal map strength / intensity"))
	add_parameter(GNParameter.create_color("albedo_color", Color(0.7, 0.7, 0.7), "Albedo Color",
		"Base color when no albedo texture is connected"))
	add_parameter(GNParameter.create_float("roughness", 0.5, 0.0, 1.0, 0.01,
		"Roughness", "Surface roughness"))
	add_parameter(GNParameter.create_bool("unlit", false, "Unlit",
		"Render unlit to see raw normal-map colors"))
	add_parameter(GNParameter.create_enum("cull_mode",
		PackedStringArray(["Back", "Front", "Disabled"]), 0,
		"Cull Mode", "Face culling"))


func _cook(inputs: Array[GNData]) -> GNData:
	var normal_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	var albedo_in: GNTextureData = inputs[1] as GNTextureData if inputs.size() > 1 and inputs[1] is GNTextureData else null

	if _material == null:
		_material = StandardMaterial3D.new()

	# Albedo
	_material.albedo_color = get_param_value("albedo_color")
	_material.albedo_texture = albedo_in.texture if albedo_in != null else null

	# Normal
	if normal_in != null and normal_in.texture != null:
		_material.normal_enabled = true
		_material.normal_texture = normal_in.texture
		_material.normal_scale = get_param_value("normal_scale")
	else:
		_material.normal_enabled = false
		_material.normal_texture = null

	_material.roughness = get_param_value("roughness")

	# Unlit mode
	var unlit: bool = get_param_value("unlit")
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unlit else BaseMaterial3D.SHADING_MODE_PER_PIXEL

	# Cull mode
	match get_param_value("cull_mode"):
		0: _material.cull_mode = BaseMaterial3D.CULL_BACK
		1: _material.cull_mode = BaseMaterial3D.CULL_FRONT
		2: _material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var out := _prepare_output()
	out.material = _material
	out.material_label = "NormalMap\nscale:%.2f" % get_param_value("normal_scale")
	out.valid = true
	out.timestamp = current_frame
	return out
