class_name FacetSOP
extends GNSopBase
## Makes points unique per face (faceted look) or consolidates shared vertices.
## Unique = no vertex sharing (flat shading), Consolidate = merge nearby verts.


func _init() -> void:
	node_type = "facet"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Faceted geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Unique Points (Flat)", "Consolidate (Merge Close)"]),
		0, "", "Faceting mode"))
	add_parameter(GNParameter.create_float("distance", 0.001, 0.0, 1.0, 0.0001,
		"Merge Distance", "Distance threshold for consolidation"))
	add_parameter(GNParameter.create_bool("recompute_normals", true, "",
		"Recompute normals after operation"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = _require_input_geo(inputs)
	if in_geo == null:
		return null

	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var mode: int = get_param_value("mode")
	var merge_dist: float = get_param_value("distance")
	var recompute: bool = get_param_value("recompute_normals")

	var new_mesh := ArrayMesh.new()

	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)

		if prim != Mesh.PRIMITIVE_TRIANGLES or arrays[Mesh.ARRAY_VERTEX] == null:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		if mode == 0:
			_make_unique(arrays, new_mesh, recompute)
		else:
			_consolidate(arrays, new_mesh, merge_dist, recompute)

	_cached_geo.set_mesh(new_mesh)
	return _cached_geo


func _make_unique(arrays: Array, out_mesh: ArrayMesh, recompute: bool) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()

	if indices.is_empty():
		indices.resize(verts.size())
		for i in range(verts.size()):
			indices[i] = i

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for tri in range(indices.size() / 3):
		var i0: int = indices[tri * 3]
		var i1: int = indices[tri * 3 + 1]
		var i2: int = indices[tri * 3 + 2]

		for vi in [i0, i1, i2]:
			if vi < uvs.size():
				st.set_uv(uvs[vi])
			st.add_vertex(verts[vi])

	if recompute:
		st.generate_normals()
	st.generate_tangents()
	st.commit(out_mesh)


func _consolidate(arrays: Array, out_mesh: ArrayMesh, dist: float,
		recompute: bool) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()

	if indices.is_empty():
		indices.resize(verts.size())
		for i in range(verts.size()):
			indices[i] = i

	# Build merge map: for each vertex, find first vertex within dist
	var dist_sq: float = dist * dist
	var merge_map := PackedInt32Array()
	merge_map.resize(verts.size())
	for i in range(verts.size()):
		merge_map[i] = i

	# Simple O(n^2) — acceptable for typical SOP meshes
	for i in range(verts.size()):
		if merge_map[i] != i:
			continue
		for j in range(i + 1, verts.size()):
			if merge_map[j] != j:
				continue
			if verts[i].distance_squared_to(verts[j]) <= dist_sq:
				merge_map[j] = i

	# Build compacted vertex list
	var unique_map: Dictionary = {}  # old index -> new index
	var new_verts := PackedVector3Array()
	var new_uvs := PackedVector2Array()

	for i in range(verts.size()):
		var canonical: int = merge_map[i]
		if not unique_map.has(canonical):
			unique_map[canonical] = new_verts.size()
			new_verts.append(verts[canonical])
			if canonical < uvs.size():
				new_uvs.append(uvs[canonical])

	# Remap indices
	var new_indices := PackedInt32Array()
	new_indices.resize(indices.size())
	for i in range(indices.size()):
		new_indices[i] = unique_map[merge_map[indices[i]]]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(new_verts.size()):
		if i < new_uvs.size():
			st.set_uv(new_uvs[i])
		st.add_vertex(new_verts[i])
	for idx in new_indices:
		st.add_index(idx)

	if recompute:
		st.generate_normals()
	st.generate_tangents()
	st.commit(out_mesh)
