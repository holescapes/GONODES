class_name RigidBodyCOMP
extends GNCompBase
## Wraps a RigidBody3D with CollisionShape3D for Jolt physics simulation.
##
## Takes a COMP input (typically GeometryCOMP) and adds physics behaviour.
## The upstream COMP provides the mesh and material — this node only owns
## physics properties (mass, friction, bounce, damping, axis locking, forces).
##
## Architecture:
##   SOP → GeometryCOMP → RigidBodyCOMP → MergeCOMP → RenderTOP
##              ↑                ↑ (optional)
##          PbrMAT           CHOP (forces)

var _rigid_body: RigidBody3D = null
var _collision_shape: CollisionShape3D = null
var _mesh_instance: MeshInstance3D = null
## Tracks which collision shape type is currently applied.
var _current_shape_type: int = -1
## Cached mesh reference to detect when upstream mesh changes.
var _last_mesh: Mesh = null


func _init() -> void:
	node_type = "rigid_body"


func _init_ports() -> void:
	add_input("comp_in", GNFamily.Type.COMP, false, "Geometry COMP input (mesh + material)", "Comp")
	add_input("force_in", GNFamily.Type.CHOP, false, "Force/impulse CHOP input (optional)", "Force")
	add_output("out", GNFamily.Type.COMP, "RigidBody component")


func _init_parameters() -> void:
	# ── Transform (initial) ──────────────────────────────────────────────
	add_parameter(GNParameter.create_float("tx", 0.0, null, null, 0.01, "Translate X", "Initial X position"))
	add_parameter(GNParameter.create_float("ty", 0.0, null, null, 0.01, "Translate Y", "Initial Y position"))
	add_parameter(GNParameter.create_float("tz", 0.0, null, null, 0.01, "Translate Z", "Initial Z position"))
	add_parameter(GNParameter.create_float("rx", 0.0, -360.0, 360.0, 0.1, "Rotate X", "Initial rotation X (degrees)"))
	add_parameter(GNParameter.create_float("ry", 0.0, -360.0, 360.0, 0.1, "Rotate Y", "Initial rotation Y (degrees)"))
	add_parameter(GNParameter.create_float("rz", 0.0, -360.0, 360.0, 0.1, "Rotate Z", "Initial rotation Z (degrees)"))
	add_parameter(GNParameter.create_float("sx", 1.0, 0.001, 100.0, 0.01, "Scale X", "Scale X"))
	add_parameter(GNParameter.create_float("sy", 1.0, 0.001, 100.0, 0.01, "Scale Y", "Scale Y"))
	add_parameter(GNParameter.create_float("sz", 1.0, 0.001, 100.0, 0.01, "Scale Z", "Scale Z"))

	# ── Physics Mode ─────────────────────────────────────────────────────
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Dynamic", "Kinematic", "Static"]), 0,
		"Mode", "Physics body mode"))

	# ── Physics Properties ───────────────────────────────────────────────
	add_parameter(GNParameter.create_float("mass", 1.0, 0.001, 1000.0, 0.1,
		"Mass", "Body mass in kg"))
	add_parameter(GNParameter.create_float("gravity_scale", 1.0, -10.0, 10.0, 0.1,
		"Gravity Scale", "Gravity multiplier (0 = weightless, negative = floats up)"))
	add_parameter(GNParameter.create_float("friction", 1.0, 0.0, 2.0, 0.01,
		"Friction", "Surface friction coefficient"))
	add_parameter(GNParameter.create_float("bounce", 0.0, 0.0, 1.0, 0.01,
		"Bounce", "Restitution / bounciness"))
	add_parameter(GNParameter.create_float("linear_damp", 0.0, 0.0, 100.0, 0.1,
		"Linear Damp", "Linear velocity damping"))
	add_parameter(GNParameter.create_float("angular_damp", 0.0, 0.0, 100.0, 0.1,
		"Angular Damp", "Angular velocity damping"))

	# ── Initial Velocity ─────────────────────────────────────────────────
	add_parameter(GNParameter.create_float("init_vel_x", 0.0, null, null, 0.1,
		"Init Vel X", "Initial linear velocity X"))
	add_parameter(GNParameter.create_float("init_vel_y", 0.0, null, null, 0.1,
		"Init Vel Y", "Initial linear velocity Y"))
	add_parameter(GNParameter.create_float("init_vel_z", 0.0, null, null, 0.1,
		"Init Vel Z", "Initial linear velocity Z"))

	# ── Axis Locking ─────────────────────────────────────────────────────
	add_parameter(GNParameter.create_bool("lock_rot_x", false,
		"Lock Rot X", "Lock rotation around X axis"))
	add_parameter(GNParameter.create_bool("lock_rot_y", false,
		"Lock Rot Y", "Lock rotation around Y axis"))
	add_parameter(GNParameter.create_bool("lock_rot_z", false,
		"Lock Rot Z", "Lock rotation around Z axis"))

	# ── Collision Shape ──────────────────────────────────────────────────
	add_parameter(GNParameter.create_enum("collision_shape",
		PackedStringArray(["Convex Hull", "Box", "Sphere", "Capsule", "Trimesh"]), 0,
		"Collision Shape", "Collision shape type (Convex Hull auto-generated from mesh)"))

	# ── Continuous Collision Detection ───────────────────────────────────
	add_parameter(GNParameter.create_bool("ccd", false,
		"CCD", "Continuous collision detection (prevents tunnelling for fast objects)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var force_in: GNChannelData = inputs[1] as GNChannelData if inputs.size() > 1 and inputs[1] is GNChannelData else null

	_ensure_body()

	# ── Resolve upstream COMP (mesh + material) ──────────────────────────
	var upstream_mesh: MeshInstance3D = _resolve_upstream_mesh()

	# ── Physics mode ─────────────────────────────────────────────────────
	var mode_idx: int = get_param_value("mode")
	match mode_idx:
		0:  # Dynamic
			_rigid_body.freeze = false
		1:  # Kinematic
			_rigid_body.freeze = true
			_rigid_body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		2:  # Static
			_rigid_body.freeze = true
			_rigid_body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC

	# ── Physics properties ───────────────────────────────────────────────
	_rigid_body.mass = get_param_value("mass")
	_rigid_body.gravity_scale = get_param_value("gravity_scale")

	# Physics material
	if _rigid_body.physics_material_override == null:
		_rigid_body.physics_material_override = PhysicsMaterial.new()
	_rigid_body.physics_material_override.friction = get_param_value("friction")
	_rigid_body.physics_material_override.bounce = get_param_value("bounce")

	_rigid_body.linear_damp = get_param_value("linear_damp")
	_rigid_body.angular_damp = get_param_value("angular_damp")
	_rigid_body.continuous_cd = get_param_value("ccd")

	# ── Axis locking ─────────────────────────────────────────────────────
	_rigid_body.axis_lock_angular_x = get_param_value("lock_rot_x")
	_rigid_body.axis_lock_angular_y = get_param_value("lock_rot_y")
	_rigid_body.axis_lock_angular_z = get_param_value("lock_rot_z")

	# ── Transform (applied only when not simulating dynamic) ─────────────
	if mode_idx != 0:  # Kinematic or Static — user controls transform
		_rigid_body.position = Vector3(
			get_param_value("tx"), get_param_value("ty"), get_param_value("tz"))
		_rigid_body.rotation_degrees = Vector3(
			get_param_value("rx"), get_param_value("ry"), get_param_value("rz"))
	_rigid_body.scale = Vector3(
		get_param_value("sx"), get_param_value("sy"), get_param_value("sz"))

	# ── Mesh + collision shape from upstream COMP ────────────────────────
	if upstream_mesh != null and upstream_mesh.mesh != null:
		_mesh_instance.mesh = upstream_mesh.mesh
		_mesh_instance.material_override = upstream_mesh.material_override
		_mesh_instance.visible = upstream_mesh.visible
		_mesh_instance.cast_shadow = upstream_mesh.cast_shadow
		_update_collision_shape(upstream_mesh.mesh)
	else:
		_mesh_instance.mesh = null

	# ── CHOP force input (requires physics space — skip until adopted) ───
	if force_in != null and mode_idx == 0 and _rigid_body.is_inside_tree():
		_apply_forces(force_in)

	return null


## Lazily creates the RigidBody3D hierarchy: body → collision_shape + mesh_instance.
func _ensure_body() -> void:
	if _rigid_body != null:
		return

	_rigid_body = RigidBody3D.new()
	_rigid_body.name = id + "_rigid"
	_rigid_body.can_sleep = false  # Keep body awake so gravity always acts
	_scene_node = _rigid_body

	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "CollisionShape"
	_rigid_body.add_child(_collision_shape)

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "MeshVis"
	_rigid_body.add_child(_mesh_instance)

	# Apply initial velocity (only once on creation)
	_rigid_body.linear_velocity = Vector3(
		get_param_value("init_vel_x"),
		get_param_value("init_vel_y"),
		get_param_value("init_vel_z"))

	# Set initial transform
	_rigid_body.position = Vector3(
		get_param_value("tx"), get_param_value("ty"), get_param_value("tz"))
	_rigid_body.rotation_degrees = Vector3(
		get_param_value("rx"), get_param_value("ry"), get_param_value("rz"))


## Generates or updates the collision shape from the mesh.
func _update_collision_shape(mesh: Mesh) -> void:
	var shape_idx: int = get_param_value("collision_shape")
	if shape_idx == _current_shape_type and mesh == _last_mesh:
		return  # No change needed

	_current_shape_type = shape_idx
	_last_mesh = mesh

	match shape_idx:
		0:  # Convex Hull
			var shape := ConvexPolygonShape3D.new()
			shape.points = mesh.get_faces()
			_collision_shape.shape = shape
		1:  # Box
			var aabb: AABB = mesh.get_aabb()
			var box := BoxShape3D.new()
			box.size = aabb.size
			_collision_shape.shape = box
			_collision_shape.position = aabb.get_center()
		2:  # Sphere
			var aabb2: AABB = mesh.get_aabb()
			var sphere := SphereShape3D.new()
			sphere.radius = aabb2.get_longest_axis_size() * 0.5
			_collision_shape.shape = sphere
			_collision_shape.position = aabb2.get_center()
		3:  # Capsule
			var aabb3: AABB = mesh.get_aabb()
			var capsule := CapsuleShape3D.new()
			capsule.height = aabb3.size.y
			capsule.radius = maxf(aabb3.size.x, aabb3.size.z) * 0.5
			_collision_shape.shape = capsule
			_collision_shape.position = aabb3.get_center()
		4:  # Trimesh (concave — for complex static-like geometry)
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(mesh.get_faces())
			_collision_shape.shape = shape


## Applies force/impulse channels from CHOP input.
## Recognized channels: force_x/y/z, impulse_x/y/z, torque_x/y/z.
func _apply_forces(chop_data: GNChannelData) -> void:
	var fx: float = chop_data.get_value("force_x") if chop_data.channels.has("force_x") else 0.0
	var fy: float = chop_data.get_value("force_y") if chop_data.channels.has("force_y") else 0.0
	var fz: float = chop_data.get_value("force_z") if chop_data.channels.has("force_z") else 0.0
	if fx != 0.0 or fy != 0.0 or fz != 0.0:
		_rigid_body.apply_central_force(Vector3(fx, fy, fz))

	var ix: float = chop_data.get_value("impulse_x") if chop_data.channels.has("impulse_x") else 0.0
	var iy: float = chop_data.get_value("impulse_y") if chop_data.channels.has("impulse_y") else 0.0
	var iz: float = chop_data.get_value("impulse_z") if chop_data.channels.has("impulse_z") else 0.0
	if ix != 0.0 or iy != 0.0 or iz != 0.0:
		_rigid_body.apply_central_impulse(Vector3(ix, iy, iz))

	var tqx: float = chop_data.get_value("torque_x") if chop_data.channels.has("torque_x") else 0.0
	var tqy: float = chop_data.get_value("torque_y") if chop_data.channels.has("torque_y") else 0.0
	var tqz: float = chop_data.get_value("torque_z") if chop_data.channels.has("torque_z") else 0.0
	if tqx != 0.0 or tqy != 0.0 or tqz != 0.0:
		_rigid_body.apply_torque(Vector3(tqx, tqy, tqz))


## Destroys the scene node and resets all internal physics state so the
## next cook recreates the RigidBody3D from scratch.
func destroy_scene_node() -> void:
	super.destroy_scene_node()
	_rigid_body = null
	_collision_shape = null
	_mesh_instance = null
	_current_shape_type = -1
	_last_mesh = null


## Returns the RigidBody3D node.
func get_rigid_body() -> RigidBody3D:
	return _rigid_body


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
## GeometryCOMP provides direct typed access; for other COMPs, walks children.
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
