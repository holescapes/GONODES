class_name GeometryCOMP
extends GNCompBase
## Places SOP geometry into a 3D scene as a MeshInstance3D.
##
## Inputs:
##   0 — SOP geometry (required)
##   1 — MAT material (optional — overrides built-in PBR parameters)
##   2 — TOP texture (optional — applied to albedo if using fallback PBR)
##
## When a MAT is connected, its Material is used directly and the built-in PBR
## parameters are ignored.  When no MAT is connected, a fallback StandardMaterial3D
## is built from the node's own parameters (albedo, metallic, roughness, etc.).
##
## Uses Godot's native scene graph: MeshInstance3D, Material.

var _mesh_instance: MeshInstance3D = null
## Fallback PBR material — only used when no MAT input is connected.
var _fallback_material: StandardMaterial3D = null


func _init() -> void:
	node_type = "geo"
	node_description = "Place SOP mesh into a 3D scene with material."


func _init_ports() -> void:
	add_input("geo_in", GNFamily.Type.SOP, false, "SOP geometry input", "Geometry")
	add_input("mat_in", GNFamily.Type.MAT, false, "Material input (optional — overrides built-in PBR)", "Material")
	add_input("tex_in", GNFamily.Type.TOP, false, "Albedo texture for fallback PBR (optional)", "Texture")
	add_output("out", GNFamily.Type.COMP, "Geometry component")


func _init_parameters() -> void:
	# Transform
	add_parameter(GNParameter.create_float("tx", 0.0, null, null, 0.01, "Translate X", "Object X position"))
	add_parameter(GNParameter.create_float("ty", 0.0, null, null, 0.01, "Translate Y", "Object Y position"))
	add_parameter(GNParameter.create_float("tz", 0.0, null, null, 0.01, "Translate Z", "Object Z position"))
	add_parameter(GNParameter.create_float("rx", 0.0, -360.0, 360.0, 0.1, "Rotate X", "Rotation around X (degrees)"))
	add_parameter(GNParameter.create_float("ry", 0.0, -360.0, 360.0, 0.1, "Rotate Y", "Rotation around Y (degrees)"))
	add_parameter(GNParameter.create_float("rz", 0.0, -360.0, 360.0, 0.1, "Rotate Z", "Rotation around Z (degrees)"))
	add_parameter(GNParameter.create_float("sx", 1.0, 0.001, 100.0, 0.01, "Scale X", "Scale along X"))
	add_parameter(GNParameter.create_float("sy", 1.0, 0.001, 100.0, 0.01, "Scale Y", "Scale along Y"))
	add_parameter(GNParameter.create_float("sz", 1.0, 0.001, 100.0, 0.01, "Scale Z", "Scale along Z"))

	# Material
	add_parameter(GNParameter.create_color("albedo_color", Color.WHITE, "Albedo Color", "Surface base colour"))
	add_parameter(GNParameter.create_float("metallic", 0.0, 0.0, 1.0, 0.01, "Metallic", "Metallic factor (0 = dielectric)"))
	add_parameter(GNParameter.create_float("roughness", 0.5, 0.0, 1.0, 0.01, "Roughness", "Surface roughness"))
	add_parameter(GNParameter.create_float("emission_energy", 0.0, 0.0, 16.0, 0.1, "Emission Energy", "Emission brightness (0 = off)"))
	add_parameter(GNParameter.create_color("emission_color", Color.BLACK, "Emission Color", "Emission colour"))
	add_parameter(GNParameter.create_bool("visible", true, "Visible", "Show or hide the mesh"))
	# Shadow casting
	add_parameter(GNParameter.create_enum("cast_shadow",
		PackedStringArray(["Off", "On", "Double-Sided", "Shadows Only"]), 1,
		"Cast Shadow", "How this object participates in shadow casting"))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo_in: GNGeoData = inputs[0] as GNGeoData if inputs.size() > 0 and inputs[0] is GNGeoData else null
	var mat_in: GNMaterialData = inputs[1] as GNMaterialData if inputs.size() > 1 and inputs[1] is GNMaterialData else null
	var tex_in: GNTextureData = inputs[2] as GNTextureData if inputs.size() > 2 and inputs[2] is GNTextureData else null

	# Create MeshInstance3D if needed (lazy init)
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = id + "_mesh"
		_scene_node = _mesh_instance  # Base class handles cleanup
		# Don't add_child — RenderTOP will adopt this into its SubViewport

	# Update mesh
	if geo_in != null and geo_in.has_geometry():
		_mesh_instance.mesh = geo_in.mesh
	else:
		_mesh_instance.mesh = null

	# Update transform
	_mesh_instance.position = Vector3(
		get_param_value("tx"), get_param_value("ty"), get_param_value("tz"))
	_mesh_instance.rotation_degrees = Vector3(
		get_param_value("rx"), get_param_value("ry"), get_param_value("rz"))
	_mesh_instance.scale = Vector3(
		get_param_value("sx"), get_param_value("sy"), get_param_value("sz"))

	# --- Material assignment ---
	if mat_in != null and mat_in.material != null:
		# MAT input connected — use it directly, bypass fallback PBR params
		_mesh_instance.material_override = mat_in.material
	else:
		# No MAT input — use fallback PBR material built from parameters
		if _fallback_material == null:
			_fallback_material = StandardMaterial3D.new()
		_mesh_instance.material_override = _fallback_material

		_fallback_material.albedo_color = get_param_value("albedo_color")
		_fallback_material.metallic = get_param_value("metallic")
		_fallback_material.roughness = get_param_value("roughness")
		_fallback_material.emission_enabled = get_param_value("emission_energy") > 0.0
		if _fallback_material.emission_enabled:
			_fallback_material.emission = get_param_value("emission_color")
			_fallback_material.emission_energy_multiplier = get_param_value("emission_energy")

		# Apply texture from TOP input (fallback PBR only)
		if tex_in != null and tex_in.texture != null:
			_fallback_material.albedo_texture = tex_in.texture
		else:
			_fallback_material.albedo_texture = null

	_mesh_instance.visible = get_param_value("visible")

	# Shadow casting
	var shadow_mode: int = get_param_value("cast_shadow")
	match shadow_mode:
		0: _mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		1: _mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		2: _mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		3: _mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

	# Output — pass the geo data through so downstream nodes can inspect it
	return geo_in


## Destroys the scene node and resets geometry state so the
## next cook recreates the MeshInstance3D from scratch.
func destroy_scene_node() -> void:
	super.destroy_scene_node()
	_mesh_instance = null
	_fallback_material = null


## Returns the MeshInstance3D for this geometry component.
## Called by RenderTOP to place it into the 3D SubViewport.
func get_mesh_instance() -> MeshInstance3D:
	return _mesh_instance


