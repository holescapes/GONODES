class_name SmoothSOP
extends GNSopBase
## Smooth (relax) mesh vertices by averaging each vertex position with its
## neighbours.  Higher iterations produce smoother results.
##
## Uses iterative Laplacian smoothing: each vertex moves toward the average
## of its connected neighbours.  Edge vertices can optionally be pinned.
##
## TouchDesigner equivalent: Smooth SOP.


func _init() -> void:
	node_type = "smooth"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry", "In")
	add_output("out", GNFamily.Type.SOP, "Smoothed geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("iterations", 3, 1, 100,
		"Iterations", "Number of smoothing passes"))
	add_parameter(GNParameter.create_float("strength", 0.5, 0.0, 1.0, 0.01,
		"Strength", "Blend factor per iteration (0 = no change, 1 = full average)"))
	add_parameter(GNParameter.create_bool("pin_borders", true,
		"Pin Borders", "Keep boundary vertices in place"))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo := _get_input_sop(inputs, 0)
	if in_geo == null or not in_geo.has_geometry():
		return null

	var iterations: int = get_param_value("iterations")
	var strength: float = get_param_value("strength")
	var pin_borders: bool = get_param_value("pin_borders")

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

		# Build adjacency map
		var adjacency: Array[PackedInt32Array] = _build_adjacency(verts.size(), indices)

		# Detect border vertices (connected to an edge with only one face)
		var border_set: Dictionary = {}
		if pin_borders:
			border_set = _find_border_vertices(verts.size(), indices)

		# Iterative Laplacian smoothing
		var curr := verts.duplicate()
		for _iter in range(iterations):
			var next := curr.duplicate()
			for vi in range(curr.size()):
				if pin_borders and border_set.has(vi):
					continue
				var neighbors := adjacency[vi]
				if neighbors.is_empty():
					continue
				var avg := Vector3.ZERO
				for ni in neighbors:
					avg += curr[ni]
				avg /= float(neighbors.size())
				next[vi] = curr[vi].lerp(avg, strength)
			curr = next

		arrays[Mesh.ARRAY_VERTEX] = curr

		# Recompute normals after smoothing
		if arrays[Mesh.ARRAY_NORMAL] != null:
			arrays[Mesh.ARRAY_NORMAL] = _recompute_normals(curr, indices)

		new_mesh.add_surface_from_arrays(prim, arrays)

	out_geo.set_mesh(new_mesh)
	return out_geo


func _build_adjacency(vert_count: int, indices: PackedInt32Array) -> Array[PackedInt32Array]:
	var adj: Array[PackedInt32Array] = []
	adj.resize(vert_count)
	for i in range(vert_count):
		adj[i] = PackedInt32Array()

	if indices.is_empty():
		# Sequential triangles
		for i in range(0, vert_count - 2, 3):
			_add_edge(adj, indices[i] if not indices.is_empty() else i,
				indices[i+1] if not indices.is_empty() else i+1)
			_add_edge(adj, indices[i+1] if not indices.is_empty() else i+1,
				indices[i+2] if not indices.is_empty() else i+2)
			_add_edge(adj, indices[i+2] if not indices.is_empty() else i+2,
				indices[i] if not indices.is_empty() else i)
	else:
		for i in range(0, indices.size() - 2, 3):
			_add_edge(adj, indices[i], indices[i+1])
			_add_edge(adj, indices[i+1], indices[i+2])
			_add_edge(adj, indices[i+2], indices[i])

	return adj


func _add_edge(adj: Array[PackedInt32Array], a: int, b: int) -> void:
	if a < adj.size() and b < adj.size():
		if b not in adj[a]:
			adj[a].append(b)
		if a not in adj[b]:
			adj[b].append(a)


func _find_border_vertices(vert_count: int, indices: PackedInt32Array) -> Dictionary:
	# An edge is a border edge if it's shared by only one triangle
	var edge_count: Dictionary = {}
	var tri_count := indices.size() / 3 if not indices.is_empty() else vert_count / 3
	for t in range(tri_count):
		var base := t * 3
		var v: Array[int]
		if not indices.is_empty():
			v = [indices[base], indices[base+1], indices[base+2]]
		else:
			v = [base, base+1, base+2]
		for e in range(3):
			var a := mini(v[e], v[(e+1) % 3])
			var b := maxi(v[e], v[(e+1) % 3])
			var key := a * vert_count + b
			edge_count[key] = edge_count.get(key, 0) + 1

	var borders: Dictionary = {}
	for key in edge_count:
		if edge_count[key] == 1:
			var b: int = key % vert_count
			var a: int = (key - b) / vert_count
			borders[a] = true
			borders[b] = true
	return borders


func _recompute_normals(verts: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for i in range(normals.size()):
		normals[i] = Vector3.ZERO

	var tri_count: int
	if not indices.is_empty():
		tri_count = indices.size() / 3
	else:
		tri_count = verts.size() / 3

	for t in range(tri_count):
		var i0: int; var i1: int; var i2: int
		if not indices.is_empty():
			i0 = indices[t * 3]
			i1 = indices[t * 3 + 1]
			i2 = indices[t * 3 + 2]
		else:
			i0 = t * 3
			i1 = t * 3 + 1
			i2 = t * 3 + 2
		var face_normal := (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0])
		normals[i0] += face_normal
		normals[i1] += face_normal
		normals[i2] += face_normal

	for i in range(normals.size()):
		normals[i] = normals[i].normalized()
	return normals
