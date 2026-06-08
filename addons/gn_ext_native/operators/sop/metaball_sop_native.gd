class_name MetaballSOPNative
extends GNSopBase
## Native-accelerated metaball iso-surface generator — delegates to
## GNNativeMetaball (C++ marching cubes) when available, falls back to
## pure GDScript otherwise.

var _processor: RefCounted = null


func _init() -> void:
	node_type = "metaball_native"
	node_description = "Metaball implicit surface via marching cubes (native C++ accelerated)."
	if ClassDB.class_exists("GNNativeMetaball"):
		_processor = ClassDB.instantiate("GNNativeMetaball")


func _init_ports() -> void:
	add_input("points", GNFamily.Type.SOP, false, "Point cloud for ball centres (optional)", "Points")
	add_output("out", GNFamily.Type.SOP, "Metaball surface mesh", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("resolution", 30, 4, 128, "Resolution",
		"Voxel grid subdivisions per axis"))
	add_parameter(GNParameter.create_float("bounds_size", 6.0, 0.5, 100.0, 0.5,
		"Bounds Size", "Cubic grid extent (centered at origin)"))
	add_parameter(GNParameter.create_float("threshold", 1.0, 0.01, 10.0, 0.01,
		"Threshold", "Iso-surface threshold (field >= threshold = inside)"))
	add_parameter(GNParameter.create_float("default_radius", 1.0, 0.01, 50.0, 0.1,
		"Default Radius", "Ball radius when no 'pscale' attribute"))
	add_parameter(GNParameter.create_int("ball_count", 2, 0, 4, "Ball Count",
		"Number of built-in balls (no input connected)"))
	add_parameter(GNParameter.create_float("b0x", -0.8, -50.0, 50.0, 0.1, "Ball 0 X", ""))
	add_parameter(GNParameter.create_float("b0y", 0.0, -50.0, 50.0, 0.1, "Ball 0 Y", ""))
	add_parameter(GNParameter.create_float("b0z", 0.0, -50.0, 50.0, 0.1, "Ball 0 Z", ""))
	add_parameter(GNParameter.create_float("b0r", 1.5, 0.01, 50.0, 0.1, "Ball 0 Radius", ""))
	add_parameter(GNParameter.create_float("b1x", 0.8, -50.0, 50.0, 0.1, "Ball 1 X", ""))
	add_parameter(GNParameter.create_float("b1y", 0.0, -50.0, 50.0, 0.1, "Ball 1 Y", ""))
	add_parameter(GNParameter.create_float("b1z", 0.0, -50.0, 50.0, 0.1, "Ball 1 Z", ""))
	add_parameter(GNParameter.create_float("b1r", 1.5, 0.01, 50.0, 0.1, "Ball 1 Radius", ""))
	add_parameter(GNParameter.create_float("b2x", 0.0, -50.0, 50.0, 0.1, "Ball 2 X", ""))
	add_parameter(GNParameter.create_float("b2y", 1.0, -50.0, 50.0, 0.1, "Ball 2 Y", ""))
	add_parameter(GNParameter.create_float("b2z", 0.0, -50.0, 50.0, 0.1, "Ball 2 Z", ""))
	add_parameter(GNParameter.create_float("b2r", 1.0, 0.01, 50.0, 0.1, "Ball 2 Radius", ""))
	add_parameter(GNParameter.create_float("b3x", 0.0, -50.0, 50.0, 0.1, "Ball 3 X", ""))
	add_parameter(GNParameter.create_float("b3y", -1.0, -50.0, 50.0, 0.1, "Ball 3 Y", ""))
	add_parameter(GNParameter.create_float("b3z", 0.0, -50.0, 50.0, 0.1, "Ball 3 Z", ""))
	add_parameter(GNParameter.create_float("b3r", 1.0, 0.01, 50.0, 0.1, "Ball 3 Radius", ""))


func _cook(inputs: Array[GNData]) -> GNData:
	var pts_geo: GNGeoData = _get_input_sop(inputs, 0)

	# ── Collect balls ──
	var ball_positions := PackedVector3Array()
	var ball_radii := PackedFloat32Array()

	if pts_geo != null and pts_geo.has_geometry():
		var pscale := pts_geo.get_point_attrib("pscale")
		var default_r: float = get_param_value("default_radius")
		for s in range(pts_geo.mesh.get_surface_count()):
			var arrays: Array = pts_geo.mesh.surface_get_arrays(s)
			if arrays[Mesh.ARRAY_VERTEX] == null:
				continue
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vi in range(verts.size()):
				ball_positions.append(verts[vi])
				if vi < pscale.size():
					ball_radii.append(pscale[vi])
				else:
					ball_radii.append(default_r)
	else:
		var count: int = get_param_value("ball_count")
		for bi in range(mini(count, 4)):
			ball_positions.append(Vector3(
				get_param_value("b%dx" % bi),
				get_param_value("b%dy" % bi),
				get_param_value("b%dz" % bi)))
			ball_radii.append(get_param_value("b%dr" % bi))

	if ball_positions.is_empty():
		return null

	var res: int = get_param_value("resolution")
	var bounds: float = get_param_value("bounds_size")
	var threshold: float = get_param_value("threshold")

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()

	if _processor != null:
		var result: Dictionary = _processor.process(ball_positions, ball_radii,
			res, bounds, threshold)
		verts = result.get("positions", PackedVector3Array())
		normals = result.get("normals", PackedVector3Array())
	else:
		# Fallback handled by core MetaballSOP — this path should not be reached
		# if the extension is only loaded when GNNativeMetaball exists.
		return null

	if verts.is_empty():
		return null

	var out := _prepare_geo()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	out.set_mesh(mesh)
	return out
