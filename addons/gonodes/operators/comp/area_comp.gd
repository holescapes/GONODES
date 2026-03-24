class_name AreaCOMP
extends GNCompBase
## Wraps an Area3D for force fields, gravity zones, and attract/repel regions.
##
## Area3D detects when physics bodies enter or leave and can override gravity
## and damping in that region.  Perfect for creating gravity wells, wind fields,
## zero-gravity zones, or attract/repel forces for generative art.
##
## Architecture:
##   AreaCOMP → MergeCOMP → RenderTOP
##   (optional SOP input for custom collision shape)

var _area: Area3D = null
var _collision_shape: CollisionShape3D = null
## Optional visual mesh to show the area bounds.
var _mesh_instance: MeshInstance3D = null
var _fallback_material: StandardMaterial3D = null


func _init() -> void:
	node_type = "area"


func _init_ports() -> void:
	add_input("geo_in", GNFamily.Type.SOP, false, "SOP shape input (optional — uses built-in shape if empty)", "Geometry")
	add_output("out", GNFamily.Type.COMP, "Area component")


func _init_parameters() -> void:
	# ── Transform ────────────────────────────────────────────────────────
	add_parameter(GNParameter.create_float("tx", 0.0, null, null, 0.01, "Translate X", "X position"))
	add_parameter(GNParameter.create_float("ty", 0.0, null, null, 0.01, "Translate Y", "Y position"))
	add_parameter(GNParameter.create_float("tz", 0.0, null, null, 0.01, "Translate Z", "Z position"))
	add_parameter(GNParameter.create_float("rx", 0.0, -360.0, 360.0, 0.1, "Rotate X", "Rotation X"))
	add_parameter(GNParameter.create_float("ry", 0.0, -360.0, 360.0, 0.1, "Rotate Y", "Rotation Y"))
	add_parameter(GNParameter.create_float("rz", 0.0, -360.0, 360.0, 0.1, "Rotate Z", "Rotation Z"))
	add_parameter(GNParameter.create_float("sx", 1.0, 0.001, 100.0, 0.01, "Scale X", "Scale X"))
	add_parameter(GNParameter.create_float("sy", 1.0, 0.001, 100.0, 0.01, "Scale Y", "Scale Y"))
	add_parameter(GNParameter.create_float("sz", 1.0, 0.001, 100.0, 0.01, "Scale Z", "Scale Z"))

	# ── Area Shape (used when no SOP input) ──────────────────────────────
	add_parameter(GNParameter.create_enum("shape",
		PackedStringArray(["Box", "Sphere"]), 1,
		"Shape", "Built-in collision shape (when no SOP connected)"))
	add_parameter(GNParameter.create_float("shape_radius", 5.0, 0.1, 100.0, 0.1,
		"Radius", "Sphere radius / box half-extent"))

	# ── Gravity Override ─────────────────────────────────────────────────
	add_parameter(GNParameter.create_bool("gravity_override", true,
		"Override Gravity", "Replace default gravity inside this area"))
	add_parameter(GNParameter.create_enum("gravity_space",
		PackedStringArray(["Directional", "Point"]), 0,
		"Gravity Space", "Directional (like world gravity) or point (attract to center)"))
	add_parameter(GNParameter.create_float("gravity_strength", 9.8, -50.0, 50.0, 0.1,
		"Gravity Strength", "Gravity magnitude (negative = repel)"))
	add_parameter(GNParameter.create_float("gravity_dir_x", 0.0, -1.0, 1.0, 0.01,
		"Gravity Dir X", "Directional gravity X component"))
	add_parameter(GNParameter.create_float("gravity_dir_y", -1.0, -1.0, 1.0, 0.01,
		"Gravity Dir Y", "Directional gravity Y component"))
	add_parameter(GNParameter.create_float("gravity_dir_z", 0.0, -1.0, 1.0, 0.01,
		"Gravity Dir Z", "Directional gravity Z component"))

	# ── Damping Override ─────────────────────────────────────────────────
	add_parameter(GNParameter.create_bool("linear_damp_override", false,
		"Override Linear Damp", "Override linear damping inside this area"))
	add_parameter(GNParameter.create_float("linear_damp", 0.1, 0.0, 100.0, 0.01,
		"Linear Damp", "Linear damping value"))
	add_parameter(GNParameter.create_bool("angular_damp_override", false,
		"Override Angular Damp", "Override angular damping inside this area"))
	add_parameter(GNParameter.create_float("angular_damp", 0.1, 0.0, 100.0, 0.01,
		"Angular Damp", "Angular damping value"))

	# ── Priority ─────────────────────────────────────────────────────────
	add_parameter(GNParameter.create_int("priority", 0, -100, 100,
		"Priority", "Area priority (higher overrides lower when overlapping)"))

	# ── Visual ───────────────────────────────────────────────────────────
	add_parameter(GNParameter.create_bool("show_shape", false,
		"Show Shape", "Display a translucent wireframe of the area bounds"))
	add_parameter(GNParameter.create_color("shape_color", Color(0.2, 0.6, 1.0, 0.2),
		"Shape Color", "Visual debug color for the area shape"))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo_in: GNGeoData = inputs[0] as GNGeoData if inputs.size() > 0 and inputs[0] is GNGeoData else null

	_ensure_area()

	# ── Transform ────────────────────────────────────────────────────────
	_area.position = Vector3(
		get_param_value("tx"), get_param_value("ty"), get_param_value("tz"))
	_area.rotation_degrees = Vector3(
		get_param_value("rx"), get_param_value("ry"), get_param_value("rz"))
	_area.scale = Vector3(
		get_param_value("sx"), get_param_value("sy"), get_param_value("sz"))

	# ── Collision shape ──────────────────────────────────────────────────
	if geo_in != null and geo_in.has_geometry():
		# Use SOP mesh as collision shape
		var shape := ConvexPolygonShape3D.new()
		shape.points = geo_in.mesh.get_faces()
		_collision_shape.shape = shape
	else:
		# Use built-in primitive shape
		var shape_type: int = get_param_value("shape")
		var radius: float = get_param_value("shape_radius")
		match shape_type:
			0:  # Box
				var box := BoxShape3D.new()
				box.size = Vector3(radius * 2.0, radius * 2.0, radius * 2.0)
				_collision_shape.shape = box
			1:  # Sphere
				var sphere := SphereShape3D.new()
				sphere.radius = radius
				_collision_shape.shape = sphere

	# ── Gravity ──────────────────────────────────────────────────────────
	if get_param_value("gravity_override"):
		_area.gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE
		var grav_space: int = get_param_value("gravity_space")
		if grav_space == 1:  # Point
			_area.gravity_point = true
		else:
			_area.gravity_point = false
			_area.gravity_direction = Vector3(
				get_param_value("gravity_dir_x"),
				get_param_value("gravity_dir_y"),
				get_param_value("gravity_dir_z")).normalized()
		_area.gravity = get_param_value("gravity_strength")
	else:
		_area.gravity_space_override = Area3D.SPACE_OVERRIDE_DISABLED

	# ── Damping ──────────────────────────────────────────────────────────
	if get_param_value("linear_damp_override"):
		_area.linear_damp_space_override = Area3D.SPACE_OVERRIDE_REPLACE
		_area.linear_damp = get_param_value("linear_damp")
	else:
		_area.linear_damp_space_override = Area3D.SPACE_OVERRIDE_DISABLED

	if get_param_value("angular_damp_override"):
		_area.angular_damp_space_override = Area3D.SPACE_OVERRIDE_REPLACE
		_area.angular_damp = get_param_value("angular_damp")
	else:
		_area.angular_damp_space_override = Area3D.SPACE_OVERRIDE_DISABLED

	_area.priority = get_param_value("priority")

	# ── Visual debug shape ───────────────────────────────────────────────
	_update_debug_visual()

	return null


func _ensure_area() -> void:
	if _area != null:
		return

	_area = Area3D.new()
	_area.name = id + "_area"
	_scene_node = _area

	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "CollisionShape"
	_area.add_child(_collision_shape)


func _update_debug_visual() -> void:
	var show: bool = get_param_value("show_shape")
	if not show:
		if _mesh_instance != null:
			_mesh_instance.visible = false
		return

	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "DebugVis"
		_area.add_child(_mesh_instance)
		_fallback_material = StandardMaterial3D.new()
		_fallback_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_fallback_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_fallback_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mesh_instance.material_override = _fallback_material

	var shape_color: Color = get_param_value("shape_color")
	_fallback_material.albedo_color = shape_color
	_mesh_instance.visible = true

	# Generate a visual mesh matching the collision shape
	var shape_type: int = get_param_value("shape")
	var radius: float = get_param_value("shape_radius")
	if _collision_shape.shape is SphereShape3D or shape_type == 1:
		var sphere_mesh := SphereMesh.new()
		sphere_mesh.radius = radius
		sphere_mesh.height = radius * 2.0
		sphere_mesh.radial_segments = 16
		sphere_mesh.rings = 8
		_mesh_instance.mesh = sphere_mesh
	else:
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(radius * 2.0, radius * 2.0, radius * 2.0)
		_mesh_instance.mesh = box_mesh


## Destroys the scene node and resets area state so the
## next cook recreates the Area3D from scratch.
func destroy_scene_node() -> void:
	super.destroy_scene_node()
	_area = null
	_collision_shape = null
	_mesh_instance = null
	_fallback_material = null


## Returns the Area3D node.
func get_area() -> Area3D:
	return _area
