class_name StaticBodyCOMP
extends GNCompBase
## Wraps a StaticBody3D with CollisionShape3D for immovable physics colliders.
##
## Creates ground planes, walls, obstacles, and other fixed collision surfaces.
## Takes SOP geometry input and auto-generates a collision shape from the mesh.
##
## Architecture:
##   SOP → StaticBodyCOMP → MergeCOMP → RenderTOP

var _static_body: StaticBody3D = null
var _collision_shape: CollisionShape3D = null
var _mesh_instance: MeshInstance3D = null
var _fallback_material: StandardMaterial3D = null
var _current_shape_type: int = -1
var _last_mesh: ArrayMesh = null


func _init() -> void:
	node_type = "static_body"
	node_description = "StaticBody3D — immovable collision surface (ground, walls)."


func _init_ports() -> void:
	add_input("geo_in", GNFamily.Type.SOP, false, "SOP geometry input")
	add_input("mat_in", GNFamily.Type.MAT, false, "Material input (optional)")
	add_output("out", GNFamily.Type.COMP, "StaticBody component")


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

	# ── Physics Properties ───────────────────────────────────────────────
	add_parameter(GNParameter.create_float("friction", 1.0, 0.0, 2.0, 0.01,
		"Friction", "Surface friction coefficient"))
	add_parameter(GNParameter.create_float("bounce", 0.0, 0.0, 1.0, 0.01,
		"Bounce", "Restitution / bounciness"))

	# ── Collision Shape ──────────────────────────────────────────────────
	add_parameter(GNParameter.create_enum("collision_shape",
		PackedStringArray(["Convex Hull", "Box", "Sphere", "Capsule", "Trimesh"]), 4,
		"Collision Shape", "Collision shape type (Trimesh default for static geometry)"))

	# ── Visual ───────────────────────────────────────────────────────────
	add_parameter(GNParameter.create_color("albedo_color", Color(0.4, 0.4, 0.45),
		"Albedo Color", "Surface base colour (fallback PBR)"))
	add_parameter(GNParameter.create_float("metallic", 0.0, 0.0, 1.0, 0.01,
		"Metallic", "Metallic factor"))
	add_parameter(GNParameter.create_float("roughness", 0.8, 0.0, 1.0, 0.01,
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

	# ── Mesh + collision shape ───────────────────────────────────────────
	if geo_in != null and geo_in.has_geometry():
		_mesh_instance.mesh = geo_in.mesh
		_update_collision_shape(geo_in.mesh)
	else:
		_mesh_instance.mesh = null

	# ── Material ─────────────────────────────────────────────────────────
	if mat_in != null and mat_in.material != null:
		_mesh_instance.material_override = mat_in.material
	else:
		if _fallback_material == null:
			_fallback_material = StandardMaterial3D.new()
		_mesh_instance.material_override = _fallback_material
		_fallback_material.albedo_color = get_param_value("albedo_color")
		_fallback_material.metallic = get_param_value("metallic")
		_fallback_material.roughness = get_param_value("roughness")

	_mesh_instance.visible = get_param_value("visible")

	# Shadow casting
	var shadow_mode: int = get_param_value("cast_shadow")
	match shadow_mode:
		0: _mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		1: _mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		2: _mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		3: _mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

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


func _update_collision_shape(mesh: ArrayMesh) -> void:
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


## Returns the StaticBody3D node.
func get_static_body() -> StaticBody3D:
	return _static_body
