class_name DivideSOP
extends GNSopBase
## Triangulates or cleans mesh topology.
## Can triangulate non-triangle primitives and remove degenerate triangles.


func _init() -> void:
	node_type = "divide"
	node_description = "Triangulate or clean mesh topology."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Cleaned / triangulated geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Triangulate", "Convex Decompose"]), 0,
		"Mode", "Operation mode"))
	add_parameter(GNParameter.create_bool("remove_degenerate", true,
		"Remove Degenerate", "Remove zero-area triangles"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo := _require_input_geo(inputs)
	if in_geo == null:
		return null

	var out := _prepare_geo()
	var mode_idx: int = get_param_value("mode")
	var remove_degen: bool = get_param_value("remove_degenerate")

	var new_mesh := ArrayMesh.new()

	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)

		if arrays[Mesh.ARRAY_VERTEX] == null:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		match mode_idx:
			0:  # Triangulate
				_triangulate_surface(new_mesh, arrays, prim, remove_degen)
			1:  # Convex Decompose
				_convex_decompose_surface(new_mesh, arrays, prim, remove_degen)

	out.set_mesh(new_mesh)
	return out


func _triangulate_surface(mesh: ArrayMesh, arrays: Array,
		prim: Mesh.PrimitiveType, remove_degen: bool) -> void:
	if prim == Mesh.PRIMITIVE_TRIANGLES:
		if remove_degen:
			_remove_degenerate_triangles(arrays)
		mesh.add_surface_from_arrays(prim, arrays)
		return

	# Use SurfaceTool to triangulate non-triangle primitives
	var st := SurfaceTool.new()
	var tmp_mesh := ArrayMesh.new()
	tmp_mesh.add_surface_from_arrays(prim, arrays)
	st.create_from(tmp_mesh, 0)
	st.deindex()

	# Re-index as triangles
	var tri_st := SurfaceTool.new()
	tri_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var src_arrays: Array = st.commit_to_arrays()
	var verts: PackedVector3Array = src_arrays[Mesh.ARRAY_VERTEX]
	if verts == null or verts.size() == 0:
		mesh.add_surface_from_arrays(prim, arrays)
		return

	var has_normals: bool = src_arrays[Mesh.ARRAY_NORMAL] != null
	var normals: PackedVector3Array = src_arrays[Mesh.ARRAY_NORMAL] if has_normals else PackedVector3Array()
	var has_uvs: bool = src_arrays[Mesh.ARRAY_TEX_UV] != null
	var uvs: PackedVector2Array = src_arrays[Mesh.ARRAY_TEX_UV] if has_uvs else PackedVector2Array()

	match prim:
		Mesh.PRIMITIVE_TRIANGLE_STRIP:
			# Triangle strip: each new vertex forms a triangle with the previous two
			for i in range(2, verts.size()):
				var i0: int = i - 2
				var i1: int = i - 1
				var i2: int = i
				# Reverse winding for odd triangles
				if i % 2 == 1:
					var tmp: int = i0
					i0 = i1
					i1 = tmp
				_add_vertex_to_st(tri_st, verts, normals, uvs, i0, has_normals, has_uvs)
				_add_vertex_to_st(tri_st, verts, normals, uvs, i1, has_normals, has_uvs)
				_add_vertex_to_st(tri_st, verts, normals, uvs, i2, has_normals, has_uvs)
		_:
			# For any other primitive, fan-triangulate from first vertex
			for i in range(1, verts.size() - 1):
				_add_vertex_to_st(tri_st, verts, normals, uvs, 0, has_normals, has_uvs)
				_add_vertex_to_st(tri_st, verts, normals, uvs, i, has_normals, has_uvs)
				_add_vertex_to_st(tri_st, verts, normals, uvs, i + 1, has_normals, has_uvs)

	var result_arrays: Array = tri_st.commit_to_arrays()
	if remove_degen:
		_remove_degenerate_triangles(result_arrays)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, result_arrays)


func _convex_decompose_surface(mesh: ArrayMesh, arrays: Array,
		prim: Mesh.PrimitiveType, remove_degen: bool) -> void:
	# For convex decompose we first triangulate, then rely on the mesh arrays.
	# Godot doesn't expose a convex decomposition API on ArrayMesh, so we
	# perform a best-effort triangulation with degenerate removal.
	_triangulate_surface(mesh, arrays, prim, remove_degen)


func _add_vertex_to_st(st: SurfaceTool, verts: PackedVector3Array,
		normals: PackedVector3Array, uvs: PackedVector2Array,
		idx: int, has_normals: bool, has_uvs: bool) -> void:
	if has_normals and idx < normals.size():
		st.set_normal(normals[idx])
	if has_uvs and idx < uvs.size():
		st.set_uv(uvs[idx])
	st.add_vertex(verts[idx])


func _remove_degenerate_triangles(arrays: Array) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if verts == null or verts.size() < 3:
		return

	var has_normals: bool = arrays[Mesh.ARRAY_NORMAL] != null
	var has_uvs: bool = arrays[Mesh.ARRAY_TEX_UV] != null

	var indices: PackedInt32Array
	var has_indices: bool = arrays[Mesh.ARRAY_INDEX] != null
	if has_indices:
		indices = arrays[Mesh.ARRAY_INDEX]
	else:
		# Build implicit index list
		indices = PackedInt32Array()
		indices.resize(verts.size())
		for i in range(verts.size()):
			indices[i] = i

	var clean_indices := PackedInt32Array()
	var epsilon: float = 0.000001

	var i: int = 0
	while i + 2 < indices.size():
		var v0: Vector3 = verts[indices[i]]
		var v1: Vector3 = verts[indices[i + 1]]
		var v2: Vector3 = verts[indices[i + 2]]
		var cross: Vector3 = (v1 - v0).cross(v2 - v0)
		if cross.length_squared() > epsilon:
			clean_indices.append(indices[i])
			clean_indices.append(indices[i + 1])
			clean_indices.append(indices[i + 2])
		i += 3

	if has_indices:
		arrays[Mesh.ARRAY_INDEX] = clean_indices
	else:
		# Rebuild vertex arrays from clean indices
		var new_verts := PackedVector3Array()
		for idx in clean_indices:
			new_verts.append(verts[idx])
		arrays[Mesh.ARRAY_VERTEX] = new_verts

		if has_normals:
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var new_normals := PackedVector3Array()
			for idx in clean_indices:
				new_normals.append(normals[idx])
			arrays[Mesh.ARRAY_NORMAL] = new_normals

		if has_uvs:
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var new_uvs := PackedVector2Array()
			for idx in clean_indices:
				new_uvs.append(uvs[idx])
			arrays[Mesh.ARRAY_TEX_UV] = new_uvs
