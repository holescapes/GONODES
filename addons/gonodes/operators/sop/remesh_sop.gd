class_name RemeshSOP
extends GNSopBase
## Retopologize mesh to a more uniform triangle density.
##
## Uses edge-length-based subdivision: triangles whose edges exceed a
## target length are subdivided (midpoint split), and degenerate triangles
## are removed.  Multiple iterations converge toward uniform density.
##
## TouchDesigner equivalent: Remesh SOP.


func _init() -> void:
	node_type = "remesh"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Remeshed geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("target_edge", 0.1, 0.001, 100.0, 0.001,
		"Target Edge Length", "Desired edge length for the output mesh"))
	add_parameter(GNParameter.create_int("iterations", 3, 1, 10,
		"Iterations", "Number of subdivision passes"))
	add_parameter(GNParameter.create_bool("smooth", true,
		"Smooth", "Apply Laplacian smoothing after subdivision"))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo := _get_input_sop(inputs, 0)
	if in_geo == null or not in_geo.has_geometry():
		return null

	var target_edge: float = get_param_value("target_edge")
	var iterations: int = get_param_value("iterations")
	var do_smooth: bool = get_param_value("smooth")

	var out_geo := _prepare_geo()
	var new_mesh := ArrayMesh.new()

	for surf_idx in range(in_geo.mesh.get_surface_count()):
		var arrays := in_geo.mesh.surface_get_arrays(surf_idx)
		var prim := in_geo.mesh.surface_get_primitive_type(surf_idx)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()

		if verts.size() < 3:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		# Build explicit index list if none
		if indices.is_empty():
			for i in range(verts.size()):
				indices.append(i)

		# Iterative midpoint subdivision
		for _it in range(iterations):
			var result := _subdivide_pass(verts, indices, target_edge)
			verts = result[0]
			indices = result[1]

		# Optional Laplacian smoothing pass
		if do_smooth:
			verts = _smooth_pass(verts, indices, 0.3)

		# Recompute normals
		var normals := _compute_normals(verts, indices)

		var out_arrays: Array = []
		out_arrays.resize(Mesh.ARRAY_MAX)
		out_arrays[Mesh.ARRAY_VERTEX] = verts
		out_arrays[Mesh.ARRAY_NORMAL] = normals
		out_arrays[Mesh.ARRAY_INDEX] = indices
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out_arrays)

	out_geo.set_mesh(new_mesh)
	return out_geo


## Subdivides triangles with edges longer than target_edge.
func _subdivide_pass(verts: PackedVector3Array, indices: PackedInt32Array,
		target: float) -> Array:
	var new_verts := PackedVector3Array()
	new_verts.append_array(verts)
	var new_indices := PackedInt32Array()
	var midpoint_cache: Dictionary = {}  # "a_b" -> vertex index

	var tri_count := indices.size() / 3
	for t in range(tri_count):
		var i0 := indices[t * 3]
		var i1 := indices[t * 3 + 1]
		var i2 := indices[t * 3 + 2]
		var v0 := new_verts[i0]
		var v1 := new_verts[i1]
		var v2 := new_verts[i2]

		var e01 := v0.distance_to(v1)
		var e12 := v1.distance_to(v2)
		var e20 := v2.distance_to(v0)

		var split_01 := e01 > target
		var split_12 := e12 > target
		var split_20 := e20 > target

		if not split_01 and not split_12 and not split_20:
			# Triangle is fine — keep it
			new_indices.append_array([i0, i1, i2])
			continue

		# Get or create midpoints for edges that need splitting
		var m01 := _get_midpoint(new_verts, midpoint_cache, i0, i1) if split_01 else -1
		var m12 := _get_midpoint(new_verts, midpoint_cache, i1, i2) if split_12 else -1
		var m20 := _get_midpoint(new_verts, midpoint_cache, i2, i0) if split_20 else -1

		# Subdivide based on which edges were split
		if split_01 and split_12 and split_20:
			new_indices.append_array([i0, m01, m20])
			new_indices.append_array([m01, i1, m12])
			new_indices.append_array([m20, m12, i2])
			new_indices.append_array([m01, m12, m20])
		elif split_01 and split_12:
			new_indices.append_array([i0, m01, i2])
			new_indices.append_array([m01, i1, m12])
			new_indices.append_array([m01, m12, i2])
		elif split_12 and split_20:
			new_indices.append_array([i0, i1, m12])
			new_indices.append_array([i0, m12, m20])
			new_indices.append_array([m12, i2, m20])
		elif split_01 and split_20:
			new_indices.append_array([i0, m01, m20])
			new_indices.append_array([m01, i1, i2])
			new_indices.append_array([m01, i2, m20])
		elif split_01:
			new_indices.append_array([i0, m01, i2])
			new_indices.append_array([m01, i1, i2])
		elif split_12:
			new_indices.append_array([i0, i1, m12])
			new_indices.append_array([i0, m12, i2])
		elif split_20:
			new_indices.append_array([i0, i1, m20])
			new_indices.append_array([m20, i1, i2])

	return [new_verts, new_indices]


func _get_midpoint(verts: PackedVector3Array, cache: Dictionary,
		a: int, b: int) -> int:
	var key := "%d_%d" % [mini(a, b), maxi(a, b)]
	if cache.has(key):
		return cache[key]
	var mid_idx := verts.size()
	verts.append((verts[a] + verts[b]) * 0.5)
	cache[key] = mid_idx
	return mid_idx


func _smooth_pass(verts: PackedVector3Array, indices: PackedInt32Array,
		strength: float) -> PackedVector3Array:
	# Build adjacency
	var adj: Array[Array] = []
	adj.resize(verts.size())
	for i in range(adj.size()):
		adj[i] = []
	for i in range(0, indices.size() - 2, 3):
		var tri := [indices[i], indices[i+1], indices[i+2]]
		for e in range(3):
			var a: int = tri[e]
			var b: int = tri[(e+1) % 3]
			if b not in adj[a]:
				adj[a].append(b)
			if a not in adj[b]:
				adj[b].append(a)

	var result := verts.duplicate()
	for vi in range(result.size()):
		if adj[vi].is_empty():
			continue
		var avg := Vector3.ZERO
		for ni in adj[vi]:
			avg += verts[ni]
		avg /= float(adj[vi].size())
		result[vi] = verts[vi].lerp(avg, strength)
	return result


func _compute_normals(verts: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for i in range(normals.size()):
		normals[i] = Vector3.ZERO

	for t in range(indices.size() / 3):
		var i0 := indices[t * 3]
		var i1 := indices[t * 3 + 1]
		var i2 := indices[t * 3 + 2]
		var fn := (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0])
		normals[i0] += fn
		normals[i1] += fn
		normals[i2] += fn

	for i in range(normals.size()):
		normals[i] = normals[i].normalized()
	return normals
