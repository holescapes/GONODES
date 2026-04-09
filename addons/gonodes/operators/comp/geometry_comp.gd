class_name GeometryCOMP
extends GNCompBase
## Places SOP geometry into a 3D scene as a MeshInstance3D.
##
## Inputs:
##   0 — SOP geometry (required)
##   1 — MAT material (optional — overrides the default material)
##
## When a MAT is connected, its Material is used directly.
## When no MAT is connected, a basic StandardMaterial3D is used.
##
## Uses Godot's native scene graph: MeshInstance3D, Material.

var _mesh_instance: MeshInstance3D = null
## Default material — only used when no MAT input is connected.
var _default_material: StandardMaterial3D = null


func _init() -> void:
	node_type = "geo"


func _init_ports() -> void:
	add_input("geo_in", GNFamily.Type.SOP, false, "SOP geometry input", "Geometry")
	add_input("mat_in", GNFamily.Type.MAT, false, "Material input (optional)", "Material")
	add_output("out", GNFamily.Type.COMP, "Geometry component")


func _init_parameters() -> void:
	# Transform
	add_parameter(GNParameter.create_float("tx", 0.0, null, null, 0.01, "Translate X", "Object X position"))
	add_parameter(GNParameter.create_float("ty", 0.0, null, null, 0.01, "Translate Y", "Object Y position"))
	add_parameter(GNParameter.create_float("tz", 0.0, null, null, 0.01, "Translate Z", "Object Z position"))
	add_parameter(GNParameter.create_float("rx", 0.0, null, null, 0.1, "Rotate X", "Rotation around X (degrees)"))
	add_parameter(GNParameter.create_float("ry", 0.0, null, null, 0.1, "Rotate Y", "Rotation around Y (degrees)"))
	add_parameter(GNParameter.create_float("rz", 0.0, null, null, 0.1, "Rotate Z", "Rotation around Z (degrees)"))
	add_parameter(GNParameter.create_float("sx", 1.0, null, null, 0.01, "Scale X", "Scale along X"))
	add_parameter(GNParameter.create_float("sy", 1.0, null, null, 0.01, "Scale Y", "Scale along Y"))
	add_parameter(GNParameter.create_float("sz", 1.0, null, null, 0.01, "Scale Z", "Scale along Z"))
	add_parameter(GNParameter.create_bool("visible", true, "Visible", "Show or hide the mesh"))
	# Shadow casting
	add_parameter(GNParameter.create_enum("cast_shadow",
		PackedStringArray(["Off", "On", "Double-Sided", "Shadows Only"]), 1,
		"Cast Shadow", "How this object participates in shadow casting"))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo_in: GNGeoData = inputs[0] as GNGeoData if inputs.size() > 0 and inputs[0] is GNGeoData else null
	var mat_in: GNMaterialData = inputs[1] as GNMaterialData if inputs.size() > 1 and inputs[1] is GNMaterialData else null

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
		# MAT input connected — use it directly
		_mesh_instance.material_override = mat_in.material
	else:
		# No MAT input — use a basic default material
		if _default_material == null:
			_default_material = StandardMaterial3D.new()
		_mesh_instance.material_override = _default_material

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


func render_for_viewer(viewer) -> void:
	if cached_output is GNGeoData and _mesh_instance != null:
		var geo: GNGeoData = cached_output as GNGeoData
		if geo.mesh != null:
			GNSopBase._ensure_viewer_scene()
			var vp: SubViewport = viewer.get_3d_viewport()
			GNSopBase._reparent_viewer_nodes(vp)
			GNSopBase._viewer_mesh_instance.mesh = geo.mesh
			GNSopBase._viewer_mesh_instance.material_override = _mesh_instance.material_override
			GNViewerRenderHelpers.apply_orbit_camera(
				GNSopBase._viewer_camera, 45.0, -30.0, 3.0)
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			viewer.set_info_bar("%d verts" % geo.vertex_count)
			return
	super.render_for_viewer(viewer)


## Destroys the scene node and resets geometry state so the
## next cook recreates the MeshInstance3D from scratch.
func destroy_scene_node() -> void:
	super.destroy_scene_node()
	_mesh_instance = null
	_default_material = null


## Returns the MeshInstance3D for this geometry component.
## Called by RenderTOP to place it into the 3D SubViewport.
func get_mesh_instance() -> MeshInstance3D:
	return _mesh_instance


