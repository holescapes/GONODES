class_name SoftBodyCOMP
extends GNCompBase
## Wraps a SoftBody3D for deformable mesh physics (cloth, jelly, soft objects).
##
## Takes SOP geometry input and creates a soft body simulation.  Godot's SoftBody3D
## deforms the mesh vertices with spring-mass physics in real time.
##
## Architecture:
##   SOP → SoftBodyCOMP → MergeCOMP → RenderTOP

var _soft_body: SoftBody3D = null
var _fallback_material: StandardMaterial3D = null
## Tracks whether we've assigned the initial mesh (SoftBody3D can only set mesh once).
var _mesh_assigned: bool = false


func _init() -> void:
	node_type = "soft_body"
	node_description = "SoftBody3D — deformable physics mesh (cloth, jelly, soft objects)."


func _init_ports() -> void:
	add_input("geo_in", GNFamily.Type.SOP, false, "SOP geometry input (triangle mesh)")
	add_input("mat_in", GNFamily.Type.MAT, false, "Material input (optional)")
	add_output("out", GNFamily.Type.COMP, "SoftBody component")


func _init_parameters() -> void:
	# ── Transform ────────────────────────────────────────────────────────
	add_parameter(GNParameter.create_float("tx", 0.0, null, null, 0.01, "Translate X", "X position"))
	add_parameter(GNParameter.create_float("ty", 0.0, null, null, 0.01, "Translate Y", "Y position"))
	add_parameter(GNParameter.create_float("tz", 0.0, null, null, 0.01, "Translate Z", "Z position"))
	add_parameter(GNParameter.create_float("rx", 0.0, -360.0, 360.0, 0.1, "Rotate X", "Rotation X (degrees)"))
	add_parameter(GNParameter.create_float("ry", 0.0, -360.0, 360.0, 0.1, "Rotate Y", "Rotation Y (degrees)"))
	add_parameter(GNParameter.create_float("rz", 0.0, -360.0, 360.0, 0.1, "Rotate Z", "Rotation Z (degrees)"))
	add_parameter(GNParameter.create_float("sx", 1.0, 0.001, 100.0, 0.01, "Scale X", "Scale X"))
	add_parameter(GNParameter.create_float("sy", 1.0, 0.001, 100.0, 0.01, "Scale Y", "Scale Y"))
	add_parameter(GNParameter.create_float("sz", 1.0, 0.001, 100.0, 0.01, "Scale Z", "Scale Z"))

	# ── Soft Body Physics ────────────────────────────────────────────────
	add_parameter(GNParameter.create_int("simulation_precision", 5, 1, 40,
		"Sim Precision", "Simulation iterations per frame (higher = stiffer, slower)"))
	add_parameter(GNParameter.create_float("total_mass", 1.0, 0.01, 1000.0, 0.1,
		"Total Mass", "Total mass distributed across all vertices"))
	add_parameter(GNParameter.create_float("linear_stiffness", 0.5, 0.0, 1.0, 0.01,
		"Linear Stiffness", "Spring stiffness (0 = floppy, 1 = rigid)"))
	add_parameter(GNParameter.create_float("pressure_coefficient", 0.0, -100.0, 100.0, 0.1,
		"Pressure", "Internal pressure (positive = inflated, negative = vacuum)"))
	add_parameter(GNParameter.create_float("damping_coefficient", 0.01, 0.0, 1.0, 0.001,
		"Damping", "Velocity damping (energy loss per step)"))
	add_parameter(GNParameter.create_float("drag_coefficient", 0.0, 0.0, 1.0, 0.01,
		"Drag", "Air drag coefficient"))

	# ── Collision ────────────────────────────────────────────────────────
	add_parameter(GNParameter.create_bool("ray_pickable", false,
		"Ray Pickable", "Can be selected by ray picking"))

	# ── Visual ───────────────────────────────────────────────────────────
	add_parameter(GNParameter.create_color("albedo_color", Color.WHITE,
		"Albedo Color", "Surface base colour (fallback PBR)"))
	add_parameter(GNParameter.create_float("metallic", 0.0, 0.0, 1.0, 0.01,
		"Metallic", "Metallic factor"))
	add_parameter(GNParameter.create_float("roughness", 0.5, 0.0, 1.0, 0.01,
		"Roughness", "Surface roughness"))
	add_parameter(GNParameter.create_bool("visible", true,
		"Visible", "Show or hide the mesh"))
	add_parameter(GNParameter.create_enum("cast_shadow",
		PackedStringArray(["Off", "On", "Double-Sided", "Shadows Only"]), 1,
		"Cast Shadow", "Shadow casting mode"))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo_in: GNGeoData = inputs[0] as GNGeoData if inputs.size() > 0 and inputs[0] is GNGeoData else null
	var mat_in: GNMaterialData = inputs[1] as GNMaterialData if inputs.size() > 1 and inputs[1] is GNMaterialData else null

	_ensure_body()

	# ── Mesh (set once — SoftBody3D doesn't support live mesh swapping) ──
	if not _mesh_assigned and geo_in != null and geo_in.has_geometry():
		_soft_body.mesh = geo_in.mesh
		_mesh_assigned = true

	# ── Transform ────────────────────────────────────────────────────────
	_soft_body.position = Vector3(
		get_param_value("tx"), get_param_value("ty"), get_param_value("tz"))
	_soft_body.rotation_degrees = Vector3(
		get_param_value("rx"), get_param_value("ry"), get_param_value("rz"))
	_soft_body.scale = Vector3(
		get_param_value("sx"), get_param_value("sy"), get_param_value("sz"))

	# ── Soft body physics ────────────────────────────────────────────────
	_soft_body.simulation_precision = get_param_value("simulation_precision")
	_soft_body.total_mass = get_param_value("total_mass")
	_soft_body.linear_stiffness = get_param_value("linear_stiffness")
	_soft_body.pressure_coefficient = get_param_value("pressure_coefficient")
	_soft_body.damping_coefficient = get_param_value("damping_coefficient")
	_soft_body.drag_coefficient = get_param_value("drag_coefficient")
	_soft_body.ray_pickable = get_param_value("ray_pickable")

	# ── Material ─────────────────────────────────────────────────────────
	if mat_in != null and mat_in.material != null:
		_soft_body.material_override = mat_in.material
	else:
		if _fallback_material == null:
			_fallback_material = StandardMaterial3D.new()
		_soft_body.material_override = _fallback_material
		_fallback_material.albedo_color = get_param_value("albedo_color")
		_fallback_material.metallic = get_param_value("metallic")
		_fallback_material.roughness = get_param_value("roughness")

	_soft_body.visible = get_param_value("visible")

	# Shadow casting
	var shadow_mode: int = get_param_value("cast_shadow")
	match shadow_mode:
		0: _soft_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		1: _soft_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		2: _soft_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		3: _soft_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

	return null


func _ensure_body() -> void:
	if _soft_body != null:
		return

	_soft_body = SoftBody3D.new()
	_soft_body.name = id + "_soft"
	_scene_node = _soft_body


## Returns the SoftBody3D node.
func get_soft_body() -> SoftBody3D:
	return _soft_body
