class_name ProjectSOP
extends GNSopBase
## Projects source geometry vertices onto a target surface along an axis.
## Unlike RaySOP (which casts rays from surface normals), ProjectSOP
## uses orthographic projection along a specified world axis.


func _init() -> void:
	node_type = "project"


func _init_ports() -> void:
	add_input("source", GNFamily.Type.SOP, false, "Geometry to project", "Source")
	add_input("target", GNFamily.Type.SOP, false, "Target surface", "Target")
	add_output("out", GNFamily.Type.SOP, "Projected geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("axis",
		PackedStringArray(["X", "Y", "Z", "-X", "-Y", "-Z"]), 2,
		"Axis", "Projection axis direction"))
	add_parameter(GNParameter.create_float("offset", 0.0, -100.0, 100.0, 0.01,
		"Offset", "Normal offset after projection"))
	add_parameter(GNParameter.create_bool("recompute_normals", true, "Enable recompute normals",
		"Recompute normals after projection"))


func _cook(inputs: Array[GNData]) -> GNData:
	var src_geo := _get_input_sop(inputs, 0)
	if src_geo == null or not src_geo.has_geometry():
		return null

	var tgt_geo := _get_input_sop(inputs, 1)
	var axis_idx: int = get_param_value("axis")
	var offset: float = get_param_value("offset")
	var recompute: bool = get_param_value("recompute_normals")

	var proj_dir: Vector3
	match axis_idx:
		0: proj_dir = Vector3.RIGHT
		1: proj_dir = Vector3.UP
		2: proj_dir = Vector3.BACK
		3: proj_dir = Vector3.LEFT
		4: proj_dir = Vector3.DOWN
		_: proj_dir = Vector3.FORWARD

	# If no target, just flatten along axis
	if tgt_geo == null or not tgt_geo.has_geometry():
		return _flatten(src_geo, proj_dir, offset, recompute)

	# Build target triangles for ray intersection
	var tris: Array[PackedVector3Array] = _build_triangles(tgt_geo)

	var geo := _prepare_geo()
	var new_mesh := ArrayMesh.new()

	for s in range(src_geo.mesh.get_surface_count()):
		var arrays: Array = src_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = src_geo.mesh.surface_get_primitive_type(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if verts == null or verts.is_empty():
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		var new_verts := PackedVector3Array()
		new_verts.resize(verts.size())

		for i in range(verts.size()):
			var best_hit := _raycast_tris(verts[i], proj_dir, tris)
			if best_hit.x < INF:
				new_verts[i] = Vector3(best_hit.x, best_hit.y, best_hit.z) + proj_dir * (-offset)
			else:
				# Try opposite direction
				best_hit = _raycast_tris(verts[i], -proj_dir, tris)
				if best_hit.x < INF:
					new_verts[i] = Vector3(best_hit.x, best_hit.y, best_hit.z) + proj_dir * (-offset)
				else:
					new_verts[i] = verts[i]

		arrays[Mesh.ARRAY_VERTEX] = new_verts

		if recompute and prim == Mesh.PRIMITIVE_TRIANGLES:
			var st := SurfaceTool.new()
			st.begin(prim)
			for vi in range(new_verts.size()):
				st.add_vertex(new_verts[vi])
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			for idx in indices:
				st.add_index(idx)
			st.generate_normals()
			st.commit(new_mesh)
		else:
			new_mesh.add_surface_from_arrays(prim, arrays)

	geo.set_mesh(new_mesh)
	return geo


func _flatten(geo_in: GNGeoData, axis: Vector3, offset: float, recompute: bool) -> GNGeoData:
	var geo := _prepare_geo()
	var new_mesh := ArrayMesh.new()
	for s in range(geo_in.mesh.get_surface_count()):
		var arrays: Array = geo_in.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = geo_in.mesh.surface_get_primitive_type(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if verts != null and not verts.is_empty():
			var new_verts := PackedVector3Array()
			new_verts.resize(verts.size())
			for i in range(verts.size()):
				new_verts[i] = verts[i] - axis * verts[i].dot(axis) + axis * offset
			arrays[Mesh.ARRAY_VERTEX] = new_verts
		new_mesh.add_surface_from_arrays(prim, arrays)
	geo.set_mesh(new_mesh)
	return geo


func _build_triangles(geo_in: GNGeoData) -> Array[PackedVector3Array]:
	var tris: Array[PackedVector3Array] = []
	for s in range(geo_in.mesh.get_surface_count()):
		if geo_in.mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays: Array = geo_in.mesh.surface_get_arrays(s)
		var sv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var si: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if si.size() >= 3:
			for i in range(0, si.size() - 2, 3):
				tris.append(PackedVector3Array([sv[si[i]], sv[si[i + 1]], sv[si[i + 2]]]))
		elif sv.size() >= 3:
			for i in range(0, sv.size() - 2, 3):
				tris.append(PackedVector3Array([sv[i], sv[i + 1], sv[i + 2]]))
	return tris


func _raycast_tris(origin: Vector3, direction: Vector3, tris: Array[PackedVector3Array]) -> Vector3:
	var best_t: float = INF
	var best_pos := Vector3(INF, INF, INF)
	for tri in tris:
		var hit := _ray_tri_intersect(origin, direction, tri[0], tri[1], tri[2])
		if hit >= 0.0 and hit < best_t:
			best_t = hit
			best_pos = origin + direction * hit
	return best_pos


func _ray_tri_intersect(origin: Vector3, dir: Vector3, v0: Vector3, v1: Vector3, v2: Vector3) -> float:
	# Moller-Trumbore intersection
	var e1: Vector3 = v1 - v0
	var e2: Vector3 = v2 - v0
	var h: Vector3 = dir.cross(e2)
	var a: float = e1.dot(h)
	if absf(a) < 1e-8:
		return -1.0
	var f: float = 1.0 / a
	var s: Vector3 = origin - v0
	var u: float = f * s.dot(h)
	if u < 0.0 or u > 1.0:
		return -1.0
	var q: Vector3 = s.cross(e1)
	var v: float = f * dir.dot(q)
	if v < 0.0 or u + v > 1.0:
		return -1.0
	var t: float = f * e2.dot(q)
	if t > 1e-8:
		return t
	return -1.0
