class_name DeleteSOP
extends GNSopBase
## Deletes primitives (triangles) or points by index range, expression, or
## bounding box.  Supports keep/remove inversion.


func _init() -> void:
	node_type = "delete"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Pruned geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("entity",
		PackedStringArray(["Primitives (Faces)", "Points"]), 0, "",
		"What to delete"))
	add_parameter(GNParameter.create_enum("method",
		PackedStringArray(["By Range", "By Bounding Box", "Random %"]),
		0, "", "Deletion criterion"))
	add_parameter(GNParameter.create_int("start", 0, 0, 999999, "Start Index", "Start of range"))
	add_parameter(GNParameter.create_int("end", 10, 0, 999999, "End Index", "End of range (inclusive)"))
	add_parameter(GNParameter.create_float("bmin_x", -0.5, null, null, 0.01, "Box Min X", "The bmin x value"))
	add_parameter(GNParameter.create_float("bmin_y", -0.5, null, null, 0.01, "Box Min Y", "The bmin y value"))
	add_parameter(GNParameter.create_float("bmin_z", -0.5, null, null, 0.01, "Box Min Z", "The bmin z value"))
	add_parameter(GNParameter.create_float("bmax_x", 0.5, null, null, 0.01, "Box Max X", "The bmax x value"))
	add_parameter(GNParameter.create_float("bmax_y", 0.5, null, null, 0.01, "Box Max Y", "The bmax y value"))
	add_parameter(GNParameter.create_float("bmax_z", 0.5, null, null, 0.01, "Box Max Z", "The bmax z value"))
	add_parameter(GNParameter.create_float("percent", 50.0, 0.0, 100.0, 1.0, "Percent", "Random deletion percentage"))
	add_parameter(GNParameter.create_int("seed", 0, 0, 9999, "Seed", "Random seed"))
	add_parameter(GNParameter.create_bool("invert", false, "Invert", "Invert selection (keep instead of delete)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = _require_input_geo(inputs)
	if in_geo == null:
		return null

	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var entity: int = get_param_value("entity")
	var method: int = get_param_value("method")
	var invert: bool = get_param_value("invert")

	var new_mesh := ArrayMesh.new()

	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)

		if prim != Mesh.PRIMITIVE_TRIANGLES or arrays[Mesh.ARRAY_VERTEX] == null:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		if entity == 0:
			_delete_faces(arrays, new_mesh, method, invert)
		else:
			_delete_points(arrays, new_mesh, method, invert)

	_cached_geo.set_mesh(new_mesh)
	return _cached_geo


func _delete_faces(arrays: Array, out_mesh: ArrayMesh, method: int, invert: bool) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()

	if indices.is_empty():
		indices.resize(verts.size())
		for i in range(verts.size()):
			indices[i] = i

	var start_r: int = get_param_value("start")
	var end_r: int = get_param_value("end")
	var bmin := Vector3(get_param_value("bmin_x"), get_param_value("bmin_y"), get_param_value("bmin_z"))
	var bmax := Vector3(get_param_value("bmax_x"), get_param_value("bmax_y"), get_param_value("bmax_z"))
	var pct: float = get_param_value("percent") / 100.0
	var seed_val: int = get_param_value("seed")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var tri_count: int = indices.size() / 3
	for tri in range(tri_count):
		var i0: int = indices[tri * 3]
		var i1: int = indices[tri * 3 + 1]
		var i2: int = indices[tri * 3 + 2]
		var center: Vector3 = (verts[i0] + verts[i1] + verts[i2]) / 3.0

		var should_delete: bool = false
		match method:
			0:  # By Range
				should_delete = tri >= start_r and tri <= end_r
			1:  # By Bounding Box
				should_delete = _in_box(center, bmin, bmax)
			2:  # Random %
				should_delete = rng.randf() < pct

		if invert:
			should_delete = not should_delete

		if not should_delete:
			for vi in [i0, i1, i2]:
				if vi < normals.size():
					st.set_normal(normals[vi])
				if vi < uvs.size():
					st.set_uv(uvs[vi])
				st.add_vertex(verts[vi])

	st.generate_tangents()
	st.commit(out_mesh)


func _delete_points(arrays: Array, out_mesh: ArrayMesh, method: int, invert: bool) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bmin := Vector3(get_param_value("bmin_x"), get_param_value("bmin_y"), get_param_value("bmin_z"))
	var bmax := Vector3(get_param_value("bmax_x"), get_param_value("bmax_y"), get_param_value("bmax_z"))
	var start_r: int = get_param_value("start")
	var end_r: int = get_param_value("end")
	var pct: float = get_param_value("percent") / 100.0
	var seed_val: int = get_param_value("seed")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	# Mark vertices to keep
	var keep := PackedByteArray()
	keep.resize(verts.size())
	keep.fill(1)

	for i in range(verts.size()):
		var should_delete: bool = false
		match method:
			0:  should_delete = i >= start_r and i <= end_r
			1:  should_delete = _in_box(verts[i], bmin, bmax)
			2:  should_delete = rng.randf() < pct
		if invert:
			should_delete = not should_delete
		if should_delete:
			keep[i] = 0

	# Rebuild keeping only non-deleted verts (output as point cloud)
	var new_verts := PackedVector3Array()
	for i in range(verts.size()):
		if keep[i] == 1:
			new_verts.append(verts[i])

	var out_arrays: Array = []
	out_arrays.resize(Mesh.ARRAY_MAX)
	out_arrays[Mesh.ARRAY_VERTEX] = new_verts
	out_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, out_arrays)


func _in_box(p: Vector3, bmin: Vector3, bmax: Vector3) -> bool:
	return p.x >= bmin.x and p.x <= bmax.x and \
		   p.y >= bmin.y and p.y <= bmax.y and \
		   p.z >= bmin.z and p.z <= bmax.z
