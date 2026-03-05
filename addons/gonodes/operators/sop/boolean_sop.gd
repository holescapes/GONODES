class_name BooleanSOP
extends GNSopBase
## Boolean operations (Union, Intersection, Difference) on two meshes.
## Leverages Godot's built-in CSGMesh3D nodes for the boolean computation —
## creates temporary CSG nodes, performs the operation, and extracts the result.


func _init() -> void:
	node_type = "boolean"
	node_description = "Boolean union/intersect/subtract two meshes via CSG."


func _init_ports() -> void:
	add_input("a", GNFamily.Type.SOP, false, "Mesh A")
	add_input("b", GNFamily.Type.SOP, false, "Mesh B")
	add_output("out", GNFamily.Type.SOP, "Boolean result")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("operation",
		PackedStringArray(["Union", "Intersection", "Subtraction"]),
		0, "", "Boolean operation type"))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo_a: GNGeoData = _get_input_sop(inputs, 0)
	var geo_b: GNGeoData = _get_input_sop(inputs, 1)

	if geo_a == null or not geo_a.has_geometry():
		return null
	if geo_b == null or not geo_b.has_geometry():
		return geo_a

	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var op: int = get_param_value("operation")

	# Map to CSG operation enum
	var csg_op: CSGShape3D.Operation
	match op:
		0:  csg_op = CSGShape3D.OPERATION_UNION
		1:  csg_op = CSGShape3D.OPERATION_INTERSECTION
		_:  csg_op = CSGShape3D.OPERATION_SUBTRACTION

	# Create temporary CSG tree (not added to scene tree — use manual bake)
	var root := CSGCombiner3D.new()
	var csg_a := CSGMesh3D.new()
	var csg_b := CSGMesh3D.new()

	csg_a.mesh = geo_a.mesh
	csg_a.operation = CSGShape3D.OPERATION_UNION

	csg_b.mesh = geo_b.mesh
	csg_b.operation = csg_op

	root.add_child(csg_a)
	root.add_child(csg_b)

	# Force CSG to compute — needs to be in the scene tree briefly
	# We use a temporary Node3D in the scene
	var main_loop: MainLoop = Engine.get_main_loop()
	var scene_root: Node = null
	if main_loop is SceneTree:
		scene_root = (main_loop as SceneTree).get_root()

	if scene_root == null:
		GNLogger.warn("BooleanSOP", "'%s' — no scene tree available for CSG" % id)
		root.queue_free()
		return null

	scene_root.add_child(root)
	root.visible = false

	# Wait one frame for CSG to regenerate (forced via _update_shape)
	# Use direct method call if available
	var meshes: Array = root.get_meshes()

	scene_root.remove_child(root)
	root.queue_free()

	if meshes.size() >= 2:
		var result_mesh = meshes[1]
		if result_mesh is ArrayMesh:
			_cached_geo.set_mesh(result_mesh)
		elif result_mesh is Mesh:
			# Convert to ArrayMesh
			var am := ArrayMesh.new()
			for s in range(result_mesh.get_surface_count()):
				am.add_surface_from_arrays(
					Mesh.PRIMITIVE_TRIANGLES,
					result_mesh.surface_get_arrays(s))
			_cached_geo.set_mesh(am)
		return _cached_geo
	else:
		GNLogger.warn("BooleanSOP", "'%s' — CSG produced no output" % id)
		return null
