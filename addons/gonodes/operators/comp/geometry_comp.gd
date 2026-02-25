class_name GeometryCOMP
extends GNCompBase
## Places SOP geometry into a 3D scene as a MeshInstance3D.
## Takes SOP input for the mesh and optional TOP input for the material texture.
## The actual MeshInstance3D is managed internally — the COMP outputs a reference
## that RenderTOP uses to populate its 3D SubViewport.
##
## Uses Godot's native scene graph: MeshInstance3D, StandardMaterial3D.

var _mesh_instance: MeshInstance3D = null
var _material: StandardMaterial3D = null


func _init() -> void:
	node_type = "geo"
	node_description = "Place SOP mesh into a 3D scene."


func _init_ports() -> void:
	add_input("geo_in", GNFamily.Type.SOP, false, "SOP geometry input")
	add_input("tex_in", GNFamily.Type.TOP, false, "Texture for material (optional)")
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


func _cook(inputs: Array[GNData]) -> GNData:
	var geo_in: GNGeoData = inputs[0] as GNGeoData if inputs.size() > 0 and inputs[0] is GNGeoData else null
	var tex_in: GNTextureData = inputs[1] as GNTextureData if inputs.size() > 1 and inputs[1] is GNTextureData else null

	# Create MeshInstance3D if needed (lazy init)
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = id + "_mesh"
		_scene_node = _mesh_instance  # Base class handles cleanup
		# Don't add_child — RenderTOP will adopt this into its SubViewport
	if _material == null:
		_material = StandardMaterial3D.new()
		_mesh_instance.material_override = _material

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

	# Update material
	_material.albedo_color = get_param_value("albedo_color")
	_material.metallic = get_param_value("metallic")
	_material.roughness = get_param_value("roughness")
	_material.emission_enabled = get_param_value("emission_energy") > 0.0
	if _material.emission_enabled:
		_material.emission = get_param_value("emission_color")
		_material.emission_energy_multiplier = get_param_value("emission_energy")

	# Apply texture from TOP input
	if tex_in != null and tex_in.texture != null:
		_material.albedo_texture = tex_in.texture
	else:
		_material.albedo_texture = null

	_mesh_instance.visible = get_param_value("visible")

	# Output COMP data (just pass the GNGeoData through so RenderTOP can get it,
	# but the real work is done by get_mesh_instance())
	return geo_in


## Returns the MeshInstance3D for this geometry component.
## Called by RenderTOP to place it into the 3D SubViewport.
func get_mesh_instance() -> MeshInstance3D:
	return _mesh_instance


