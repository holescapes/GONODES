class_name PbrMAT
extends GNMatBase
## Standard PBR material operator — wraps Godot's StandardMaterial3D.
##
## Exposes the most common physically-based rendering properties as parameters.
## Accepts optional TOP inputs for albedo, normal, roughness/metallic textures.
## Outputs a GNMaterialData containing a configured StandardMaterial3D.

var _material: StandardMaterial3D = null


func _init() -> void:
	node_type = "pbr"


func _init_ports() -> void:
	add_input("albedo_tex", GNFamily.Type.TOP, false, "Albedo texture (optional)", "Albedo Texture")
	add_input("normal_tex", GNFamily.Type.TOP, false, "Normal map texture (optional)", "Normal Texture")
	add_input("orm_tex", GNFamily.Type.TOP, false, "ORM texture — Occlusion/Roughness/Metallic (optional)", "Orm Texture")
	add_output("out", GNFamily.Type.MAT, "PBR material output", "Out")


func _init_parameters() -> void:
	# Albedo
	add_parameter(GNParameter.create_color("albedo_color", Color.WHITE, "Albedo Color", "Base surface color"))

	# PBR
	add_parameter(GNParameter.create_float("metallic", 0.0, 0.0, 1.0, 0.01, "Metallic", "Metallic factor (0 = dielectric, 1 = metal)"))
	add_parameter(GNParameter.create_float("roughness", 0.5, 0.0, 1.0, 0.01, "Roughness", "Surface roughness (0 = mirror, 1 = matte)"))
	add_parameter(GNParameter.create_float("specular", 0.5, 0.0, 1.0, 0.01, "Specular", "Specular reflectance (dielectric only)"))

	# Emission
	add_parameter(GNParameter.create_bool("emission_enabled", false, "Emission", "Enable emissive lighting"))
	add_parameter(GNParameter.create_color("emission_color", Color.BLACK, "Emission Color", "Emission color"))
	add_parameter(GNParameter.create_float("emission_energy", 1.0, 0.0, 16.0, 0.1, "Emission Energy", "Emission brightness multiplier"))

	# Normal map
	add_parameter(GNParameter.create_float("normal_scale", 1.0, -2.0, 2.0, 0.05, "Normal Scale", "Normal map intensity"))

	# Transparency
	add_parameter(GNParameter.create_enum("transparency",
		PackedStringArray(["Disabled", "Alpha", "Alpha Scissor", "Alpha Hash"]),
		0, "Transparency", "Transparency mode"))
	add_parameter(GNParameter.create_float("alpha_scissor_threshold", 0.5, 0.0, 1.0, 0.01,
		"Alpha Scissor", "Alpha cutoff threshold (Alpha Scissor mode)"))

	# Culling
	add_parameter(GNParameter.create_enum("cull_mode",
		PackedStringArray(["Back", "Front", "Disabled"]),
		0, "Cull Mode", "Face culling mode"))

	# UV
	add_parameter(GNParameter.create_bool("uv1_triplanar", false, "Triplanar UV", "Use triplanar mapping for UV1"))


func _cook(inputs: Array[GNData]) -> GNData:
	var albedo_tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	var normal_tex_in: GNTextureData = inputs[1] as GNTextureData if inputs.size() > 1 and inputs[1] is GNTextureData else null
	var orm_tex_in: GNTextureData = inputs[2] as GNTextureData if inputs.size() > 2 and inputs[2] is GNTextureData else null

	# Lazy init the material
	if _material == null:
		_material = StandardMaterial3D.new()

	# --- Albedo ---
	_material.albedo_color = get_param_value("albedo_color")
	if albedo_tex_in != null and albedo_tex_in.texture != null:
		_material.albedo_texture = albedo_tex_in.texture
	else:
		_material.albedo_texture = null

	# --- PBR ---
	_material.metallic = get_param_value("metallic")
	_material.roughness = get_param_value("roughness")
	_material.metallic_specular = get_param_value("specular")

	# --- Emission ---
	_material.emission_enabled = get_param_value("emission_enabled")
	if _material.emission_enabled:
		_material.emission = get_param_value("emission_color")
		_material.emission_energy_multiplier = get_param_value("emission_energy")

	# --- Normal Map ---
	if normal_tex_in != null and normal_tex_in.texture != null:
		_material.normal_enabled = true
		_material.normal_texture = normal_tex_in.texture
		_material.normal_scale = get_param_value("normal_scale")
	else:
		_material.normal_enabled = false
		_material.normal_texture = null

	# --- ORM Texture ---
	if orm_tex_in != null and orm_tex_in.texture != null:
		_material.ao_enabled = true
		_material.ao_texture = orm_tex_in.texture
		_material.roughness_texture = orm_tex_in.texture
		_material.metallic_texture = orm_tex_in.texture
		_material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		_material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		_material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	else:
		_material.ao_enabled = false
		_material.ao_texture = null
		_material.roughness_texture = null
		_material.metallic_texture = null

	# --- Transparency ---
	var transparency_mode: int = get_param_value("transparency")
	match transparency_mode:
		0: _material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		1: _material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		2:
			_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			_material.alpha_scissor_threshold = get_param_value("alpha_scissor_threshold")
		3: _material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH

	# --- Culling ---
	var cull: int = get_param_value("cull_mode")
	match cull:
		0: _material.cull_mode = BaseMaterial3D.CULL_BACK
		1: _material.cull_mode = BaseMaterial3D.CULL_FRONT
		2: _material.cull_mode = BaseMaterial3D.CULL_DISABLED

	# --- UV ---
	_material.uv1_triplanar = get_param_value("uv1_triplanar")

	# Build output
	var out := _prepare_output()
	out.material = _material
	out.material_label = "PBR\n%s\nM:%.2f R:%.2f" % [
		get_param_value("albedo_color"), get_param_value("metallic"), get_param_value("roughness")]
	out.valid = true
	out.timestamp = current_frame
	return out
