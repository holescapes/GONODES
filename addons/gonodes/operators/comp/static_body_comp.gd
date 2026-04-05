class_name StaticBodyCOMP
extends GNCompBase
## Wraps a StaticBody3D with CollisionShape3D for immovable physics colliders.
##
## Creates ground planes, walls, obstacles, and other fixed collision surfaces.
## Takes a COMP input (typically GeometryCOMP) for mesh and material.
##
## Architecture:
##   SOP → GeometryCOMP → StaticBodyCOMP → MergeCOMP → RenderTOP
##              ↑
##          PbrMAT

var _static_body: StaticBody3D = null
var _collision_shape: CollisionShape3D = null
var _mesh_instance: MeshInstance3D = null
var _current_shape_type: int = -1
var _last_mesh: Mesh = null


func _init() -> void:
	node_type = "static_body"


func _init_ports() -> void:
	add_input("comp_in", GNFamily.Type.COMP, false, "Geometry COMP input (mesh + material)", "Comp")
	add_output("out", GNFamily.Type.COMP, "StaticBody component")


func _init_parameters() -> void:
	# ── Transform ────────────────────────────────────────────────────────
	add_parameter(GNParameter.create_float("tx", 0.0, null, null, 0.01, "Translate X", "X position"))
	add_parameter(GNParameter.create_float("ty", 0.0, null, null, 0.01, "Translate Y", "Y position"))
	add_parameter(GNParameter.create_float("tz", 0.0, null, null, 0.01, "Translate Z", "Z position"))
	add_parameter(GNParameter.create_float("rx", 0.0, null, null, 0.1, "Rotate X", "Rotation X (degrees)"))
	add_parameter(GNParameter.create_float("ry", 0.0, null, null, 0.1, "Rotate Y", "Rotation Y (degrees)"))
	add_parameter(GNParameter.create_float("rz", 0.0, null, null, 0.1, "Rotate Z", "Rotation Z (degrees)"))
	add_parameter(GNParameter.create_float("sx", 1.0, null, null, 0.01, "Scale X", "Scale X"))
	add_parameter(GNParameter.create_float("sy", 1.0, null, null, 0.01, "Scale Y", "Scale Y"))
	add_parameter(GNParameter.create_float("sz", 1.0, null, null, 0.01, "Scale Z", "Scale Z"))

	# ── Physics Properties ───────────────────────────────────────────────
	add_parameter(GNParameter.create_float("friction", 1.0, 0.0, 2.0, 0.01,
		"Friction", "Surface friction coefficient"))
	add_parameter(GNParameter.create_float("bounce", 0.0, 0.0, 1.0, 0.01,
		"Bounce", "Restitution / bounciness"))

	# ── Collision Shape ──────────────────────────────────────────────────
	add_parameter(GNParameter.create_enum("collision_shape",
		PackedStringArray(["Convex Hull", "Box", "Sphere", "Capsule", "Trimesh"]), 4,
		"Collision Shape", "Collision shape type (Trimesh default for static geometry)"))


func _cook(_inputs: Array[GNData]) -> GNData:
	_ensure_body()

	# ── Resolve upstream COMP (mesh + material) ──────────────────────────
	var upstream_mesh: MeshInstance3D = _resolve_upstream_mesh()

	# ── Physics material ─────────────────────────────────────────────────
	if _static_body.physics_material_override == null:
		_static_body.physics_material_override = PhysicsMaterial.new()
	_static_body.physics_material_override.friction = get_param_value("friction")
	_static_body.physics_material_override.bounce = get_param_value("bounce")

	# ── Transform ────────────────────────────────────────────────────────
	_static_body.position = Vector3(
		get_param_value("tx"), get_param_value("ty"), get_param_value("tz"))
	_static_body.rotation_degrees = Vector3(
		get_param_value("rx"), get_param_value("ry"), get_param_value("rz"))
	_static_body.scale = Vector3(
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

	return null


func _ensure_body() -> void:
	if _static_body != null:
		return

	_static_body = StaticBody3D.new()
	_static_body.name = id + "_static"
	_scene_node = _static_body

	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "CollisionShape"
	_static_body.add_child(_collision_shape)

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "MeshVis"
	_static_body.add_child(_mesh_instance)


func _update_collision_shape(mesh: Mesh) -> void:
	var shape_idx: int = get_param_value("collision_shape")
	if shape_idx == _current_shape_type and mesh == _last_mesh:
		return

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
		4:  # Trimesh
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(mesh.get_faces())
			_collision_shape.shape = shape


## Destroys the scene node and resets all internal state so the
## next cook recreates the StaticBody3D from scratch.
func destroy_scene_node() -> void:
	super.destroy_scene_node()
	_static_body = null
	_collision_shape = null
	_mesh_instance = null
	_current_shape_type = -1
	_last_mesh = null


## Returns the StaticBody3D node.
func get_static_body() -> StaticBody3D:
	return _static_body


func display_in_viewer(viewer) -> void:
	if _mesh_instance != null and _mesh_instance.mesh != null and _mesh_instance.mesh is ArrayMesh:
		var geo := GNGeoData.new()
		geo.mesh = _mesh_instance.mesh as ArrayMesh
		geo.vertex_count = geo.mesh.get_surface_count()
		var mat: Material = _mesh_instance.material_override
		if mat != null:
			viewer.show_3d_mesh_with_material(geo, mat)
		else:
			viewer.show_3d_mesh(geo)
		viewer.set_info_overlay("StaticBody  Friction: %.2f  Bounce: %.2f" % [
			get_param_value("friction"), get_param_value("bounce")])
		return
	viewer.show_info("StaticBody\nFriction: %.2f  Bounce: %.2f" % [
		get_param_value("friction"), get_param_value("bounce")], "StaticBodyCOMP")



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
