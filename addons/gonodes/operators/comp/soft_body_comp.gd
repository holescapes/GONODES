class_name SoftBodyCOMP
extends GNCompBase
## Wraps a SoftBody3D for deformable mesh physics (cloth, jelly, soft objects).
##
## Takes a COMP input (typically GeometryCOMP) and creates a soft body simulation.
## The upstream COMP provides the mesh and material — this node only owns
## soft-body physics properties.
##
## Architecture:
##   SOP → GeometryCOMP → SoftBodyCOMP → MergeCOMP → RenderTOP
##              ↑
##          PBR_MAT
##
## Implementation note — tree-first strategy:
##   Jolt Physics errors on set_transform when a SoftBody3D has no physics
##   space.  Rather than creating intermediate wrappers or moving the body
##   between spaces, we let Godot's natural adoption chain handle the tree
##   entry.  On the first cook, SoftBodyCOMP creates the SoftBody3D and
##   pre-assigns the mesh, but does NOT set any transform or physics params
##   (the node is not yet in a tree).  MergeCOMP and RenderTOP then adopt
##   the node into the SubViewport during the same topological pass.  When
##   the SubViewport gets add_child(group_node), all descendants — including
##   this SoftBody3D — receive NOTIFICATION_ENTER_WORLD with the SubViewport's
##   World3D, so Jolt registers the body in the correct physics space.
##   On the next cook (deferred), the body is safely in the tree and we set
##   all transform, material, and physics properties.

var _soft_body: SoftBody3D = null
## Tracks whether we've assigned the initial mesh.
var _mesh_assigned: bool = false
## True once initial transform + physics params have been applied.
var _initial_config_done: bool = false


func _init() -> void:
	node_type = "soft_body"
	node_description = "SoftBody3D — deformable physics mesh (cloth, jelly, soft objects)."


func _init_ports() -> void:
	add_input("comp_in", GNFamily.Type.COMP, false, "Geometry COMP input (mesh + material)")
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


func _cook(_inputs: Array[GNData]) -> GNData:
	# ── Phase 1: create an EMPTY SoftBody3D ─────────────────────────────
	#    No mesh, no transform.  MergeCOMP / RenderTOP adopt this node into
	#    the SubViewport.  Jolt registers a body shell on ENTER_WORLD.
	if _soft_body == null:
		_soft_body = SoftBody3D.new()
		_soft_body.name = id + "_soft"
		_scene_node = _soft_body
		call_deferred("mark_dirty")
		return null

	# ── Phase 2: body must be inside the tree ────────────────────────────
	if not _soft_body.is_inside_tree():
		call_deferred("mark_dirty")
		return null

	# ── Phase 3 (one-shot): assign mesh + cycle physics space ───────────
	#    Jolt only creates a soft body during set_space / ENTER_WORLD when
	#    a mesh is present.  Phase 1 entered the tree empty.  Now:
	#    1) Assign mesh (may trigger non-fatal set_transform error)
	#    2) Cycle the physics space: remove → re-add.  This forces Jolt's
	#       set_space() to see the mesh and create the simulation body.
	#    3) Enable internal physics processing for simulation stepping.
	if not _mesh_assigned:
		var upstream_mesh: MeshInstance3D = _resolve_upstream_mesh()
		if upstream_mesh != null and upstream_mesh.mesh != null:
			# 1) Assign mesh (non-fatal Jolt error expected)
			_soft_body.mesh = upstream_mesh.mesh
			_soft_body.material_override = upstream_mesh.material_override
			_soft_body.visible = upstream_mesh.visible
			_soft_body.cast_shadow = upstream_mesh.cast_shadow

			# 2) Cycle physics space — forces Jolt to re-create body with mesh
			var soft_rid: RID = _soft_body.get_physics_rid()
			var vp: Viewport = _soft_body.get_viewport()
			if soft_rid.is_valid() and vp != null and vp.world_3d != null:
				var target_space: RID = vp.world_3d.space
				PhysicsServer3D.soft_body_set_space(soft_rid, RID())
				PhysicsServer3D.soft_body_set_space(soft_rid, target_space)

			# 3) Force-enable internal physics processing
			_soft_body.set_physics_process_internal(true)

			_mesh_assigned = true
			call_deferred("mark_dirty")
			return null
		else:
			call_deferred("mark_dirty")
			return null

	# ── Phase 4: per-frame updates ──────────────────────────────────────

	# Material / visibility (safe to update every frame — visual only)
	var upstream_mesh: MeshInstance3D = _resolve_upstream_mesh()
	if upstream_mesh != null:
		_soft_body.material_override = upstream_mesh.material_override
		_soft_body.visible = upstream_mesh.visible
		_soft_body.cast_shadow = upstream_mesh.cast_shadow

	# Initial transform + physics params (ONE-TIME only).
	# Setting position every frame would teleport the body back to its
	# start, fighting the physics simulation.  We set it once and then
	# let gravity / collisions handle the rest.
	if not _initial_config_done:
		_soft_body.position = Vector3(
			get_param_value("tx"), get_param_value("ty"), get_param_value("tz"))
		_soft_body.rotation_degrees = Vector3(
			get_param_value("rx"), get_param_value("ry"), get_param_value("rz"))
		_soft_body.scale = Vector3(
			get_param_value("sx"), get_param_value("sy"), get_param_value("sz"))

		_soft_body.simulation_precision = get_param_value("simulation_precision")
		_soft_body.total_mass = get_param_value("total_mass")
		_soft_body.linear_stiffness = get_param_value("linear_stiffness")
		_soft_body.pressure_coefficient = get_param_value("pressure_coefficient")
		_soft_body.damping_coefficient = get_param_value("damping_coefficient")
		_soft_body.drag_coefficient = get_param_value("drag_coefficient")
		_soft_body.ray_pickable = get_param_value("ray_pickable")

		_initial_config_done = true

	return null


## Resets state so the next cook recreates the SoftBody3D from scratch.
func destroy_scene_node() -> void:
	_soft_body = null
	_mesh_assigned = false
	_initial_config_done = false
	super.destroy_scene_node()  # removes from parent, frees, nulls _scene_node


## Returns the SoftBody3D node.
func get_soft_body() -> SoftBody3D:
	return _soft_body


## Walks the network to find the upstream COMP connected to the comp_in port.
func _resolve_upstream_comp() -> GNCompBase:
	var engine: GNCookEngine = get_parent() as GNCookEngine if get_parent() is GNCookEngine else null
	if engine == null or engine.network == null:
		return null
	var network: GNNetwork = engine.network
	for conn in network.get_input_connections(id):
		if conn.to_port != 0:
			continue
		var upstream: GNNode = network.nodes.get(conn.from_node, null)
		if upstream is GNCompBase:
			return upstream as GNCompBase
	return null


## Resolves the MeshInstance3D from the upstream COMP.
func _resolve_upstream_mesh() -> MeshInstance3D:
	var comp: GNCompBase = _resolve_upstream_comp()
	if comp == null:
		return null
	if comp is GeometryCOMP:
		return (comp as GeometryCOMP).get_mesh_instance()
	var sn: Node3D = comp.get_scene_node()
	if sn == null:
		return null
	if sn is MeshInstance3D:
		return sn as MeshInstance3D
	for child in sn.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D
	return null
