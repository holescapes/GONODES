class_name PolyReduceSOP
extends GNSopBase
## PolyReduce SOP — Mesh decimation / simplification using iterative
## edge-collapse with a quadric error metric (QEM).
##
## Reduces the triangle count of the input mesh to a target percentage while
## preserving overall shape as much as possible.  The algorithm:
##   1. Build half-edge adjacency from triangle soup.
##   2. For each vertex compute an initial quadric matrix (sum of face planes).
##   3. For each edge compute the collapse cost (quadric error of optimal point).
##   4. Greedily collapse the lowest-cost edge, update neighbours.
##   5. Repeat until the target triangle count is reached.
##
## This is a CPU implementation suited for later C++ porting.

func _init() -> void:
	node_type = "polyreduce"
	node_description = "Mesh decimation via quadric error metric edge collapse."


func _init_ports() -> void:
	add_input("geo", GNFamily.Type.SOP, true, "Geometry to simplify")
	add_output("out", GNFamily.Type.SOP, "Reduced geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("target_percent", 50.0, 1.0, 100.0, 1.0,
		"Target %", "Percentage of original triangles to keep"))
	add_parameter(GNParameter.create_bool("preserve_boundary", true,
		"Preserve Boundary", "Add extra cost to boundary edges to preserve silhouette"))
	add_parameter(GNParameter.create_float("boundary_weight", 10.0, 0.1, 1000.0, 1.0,
		"Boundary Weight", "Extra penalty multiplier for boundary edges"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = _require_input_geo(inputs)
	if in_geo == null:
		return null
	if in_geo.mesh.get_surface_count() == 0:
		return in_geo

	var target_pct: float = get_param_value("target_percent") / 100.0
	var preserve_boundary: bool = get_param_value("preserve_boundary")
	var boundary_weight: float = get_param_value("boundary_weight")

	# Work on first surface only (most common case)
	var arrays: Array = in_geo.mesh.surface_get_arrays(0)
	if arrays[Mesh.ARRAY_VERTEX] == null:
		return in_geo

	var src_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_indices = arrays[Mesh.ARRAY_INDEX]

	# Convert to indexed triangle list if not already
	var positions := PackedVector3Array()
	var triangles := PackedInt32Array()  # flat i0,i1,i2,...

	if src_indices != null and src_indices.size() > 0:
		positions = src_verts.duplicate()
		triangles = src_indices.duplicate()
	else:
		# Non-indexed: weld identical vertices then build index buffer
		var map := {}
		var idx_remap := PackedInt32Array()
		idx_remap.resize(src_verts.size())
		for vi in range(src_verts.size()):
			var key: String = _vec_key(src_verts[vi])
			if map.has(key):
				idx_remap[vi] = map[key]
			else:
				var ni: int = positions.size()
				map[key] = ni
				idx_remap[vi] = ni
				positions.append(src_verts[vi])
		for vi in range(src_verts.size()):
			triangles.append(idx_remap[vi])

	var orig_tri_count: int = triangles.size() / 3
	var target_tris: int = maxi(int(orig_tri_count * target_pct), 1)

	if orig_tri_count <= target_tris:
		return in_geo

	# ── Build data structures ──
	var vert_count: int = positions.size()

	# Quadric per vertex (stored as 10 floats: a11, a12, a13, a14, a22, a23, a24, a33, a34, a44)
	var quadrics: Array[PackedFloat64Array] = []
	quadrics.resize(vert_count)
	for i in range(vert_count):
		quadrics[i] = PackedFloat64Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0])

	# Initialise quadrics from face planes
	for ti in range(orig_tri_count):
		var i0: int = triangles[ti * 3]
		var i1: int = triangles[ti * 3 + 1]
		var i2: int = triangles[ti * 3 + 2]
		var v0: Vector3 = positions[i0]
		var v1: Vector3 = positions[i1]
		var v2: Vector3 = positions[i2]
		var normal: Vector3 = (v1 - v0).cross(v2 - v0)
		var len: float = normal.length()
		if len < 0.00001:
			continue
		normal /= len
		var d: float = -normal.dot(v0)
		var plane: PackedFloat64Array = _plane_quadric(normal.x, normal.y, normal.z, d)
		quadrics[i0] = _add_quadrics(quadrics[i0], plane)
		quadrics[i1] = _add_quadrics(quadrics[i1], plane)
		quadrics[i2] = _add_quadrics(quadrics[i2], plane)

	# Boundary edge detection (edges with only 1 adjacent triangle)
	var edge_face_count := {}
	for ti in range(orig_tri_count):
		for ei in range(3):
			var a: int = triangles[ti * 3 + ei]
			var b: int = triangles[ti * 3 + (ei + 1) % 3]
			var key: int = _edge_key(a, b)
			edge_face_count[key] = edge_face_count.get(key, 0) + 1

	if preserve_boundary:
		for key in edge_face_count:
			if edge_face_count[key] == 1:
				var a: int = key >> 20
				var b: int = key & 0xFFFFF
				# Add large plane quadric perpendicular to edge at midpoint
				var mid: Vector3 = (positions[a] + positions[b]) * 0.5
				var edge_dir: Vector3 = (positions[b] - positions[a]).normalized()
				if edge_dir.length_squared() < 0.0001:
					continue
				# Two perpendicular constraint planes
				var up := Vector3.UP
				if absf(edge_dir.dot(up)) > 0.99:
					up = Vector3.RIGHT
				var n1: Vector3 = edge_dir.cross(up).normalized()
				var n2: Vector3 = edge_dir.cross(n1).normalized()
				var bq1 := _plane_quadric(n1.x, n1.y, n1.z, -n1.dot(mid))
				var bq2 := _plane_quadric(n2.x, n2.y, n2.z, -n2.dot(mid))
				for _w in range(int(boundary_weight)):
					quadrics[a] = _add_quadrics(quadrics[a], bq1)
					quadrics[a] = _add_quadrics(quadrics[a], bq2)
					quadrics[b] = _add_quadrics(quadrics[b], bq1)
					quadrics[b] = _add_quadrics(quadrics[b], bq2)

	# ── Build edge collapse candidates ──
	# Store edges as pairs with computed cost
	var edge_set := {}  # edge_key -> [cost, optimal_pos, a, b]
	for ti in range(orig_tri_count):
		for ei in range(3):
			var a: int = triangles[ti * 3 + ei]
			var b: int = triangles[ti * 3 + (ei + 1) % 3]
			var key: int = _edge_key(a, b)
			if not edge_set.has(key):
				var result: Array = _compute_collapse(a, b, positions, quadrics)
				edge_set[key] = result

	# Track which vertices are alive
	var alive := PackedByteArray()
	alive.resize(vert_count)
	alive.fill(1)

	# Vertex remap table (collapse a->b means a remaps to b)
	var remap := PackedInt32Array()
	remap.resize(vert_count)
	for i in range(vert_count):
		remap[i] = i

	# ── Iterative collapse ──
	var current_tris: int = orig_tri_count

	while current_tris > target_tris and not edge_set.is_empty():
		# Find minimum cost edge (linear scan — could use a heap for perf)
		var best_key: int = -1
		var best_cost: float = INF
		for key in edge_set:
			var data: Array = edge_set[key]
			if data[0] < best_cost:
				best_cost = data[0]
				best_key = key

		if best_key == -1:
			break

		var data: Array = edge_set[best_key]
		var opt_pos: Vector3 = data[1]
		var va: int = data[2]
		var vb: int = data[3]
		edge_set.erase(best_key)

		# Resolve remaps
		va = _resolve(va, remap)
		vb = _resolve(vb, remap)
		if va == vb:
			continue

		# Collapse vb into va
		positions[va] = opt_pos
		quadrics[va] = _add_quadrics(quadrics[va], quadrics[vb])
		alive[vb] = 0
		remap[vb] = va

		# Update triangles: replace vb with va, remove degenerate
		var removed: int = 0
		var ti: int = 0
		while ti < current_tris:
			var base: int = ti * 3
			for ci in range(3):
				if triangles[base + ci] == vb:
					triangles[base + ci] = va

			# Check degenerate
			if (triangles[base] == triangles[base + 1] or
				triangles[base + 1] == triangles[base + 2] or
				triangles[base] == triangles[base + 2]):
				# Swap with last triangle
				var last: int = (current_tris - 1) * 3
				for ci in range(3):
					triangles[base + ci] = triangles[last + ci]
				current_tris -= 1
				removed += 1
			else:
				ti += 1

		# Remove stale edges involving vb and recompute edges involving va
		var to_remove := PackedInt64Array()
		var to_recompute := PackedInt64Array()
		for key in edge_set:
			var ed: Array = edge_set[key]
			var ea: int = _resolve(ed[2], remap)
			var eb: int = _resolve(ed[3], remap)
			if ea == eb:
				to_remove.append(key)
			elif ea == va or eb == va:
				to_recompute.append(key)
		for key in to_remove:
			edge_set.erase(key)
		for key in to_recompute:
			var ed: Array = edge_set[key]
			var ea: int = _resolve(ed[2], remap)
			var eb: int = _resolve(ed[3], remap)
			var new_key: int = _edge_key(ea, eb)
			edge_set.erase(key)
			var result: Array = _compute_collapse(ea, eb, positions, quadrics)
			edge_set[new_key] = result

	# ── Build output mesh ──
	# Compact vertices
	var compact_remap := {}
	var final_verts := PackedVector3Array()
	var final_indices := PackedInt32Array()

	for ti in range(current_tris):
		for ci in range(3):
			var vi: int = _resolve(triangles[ti * 3 + ci], remap)
			if not compact_remap.has(vi):
				compact_remap[vi] = final_verts.size()
				final_verts.append(positions[vi])
			final_indices.append(compact_remap[vi])

	if final_verts.is_empty():
		return in_geo

	# Recompute normals
	var final_normals := PackedVector3Array()
	final_normals.resize(final_verts.size())
	for i in range(final_normals.size()):
		final_normals[i] = Vector3.ZERO
	for ti in range(final_indices.size() / 3):
		var i0: int = final_indices[ti * 3]
		var i1: int = final_indices[ti * 3 + 1]
		var i2: int = final_indices[ti * 3 + 2]
		var e1: Vector3 = final_verts[i1] - final_verts[i0]
		var e2: Vector3 = final_verts[i2] - final_verts[i0]
		var fn: Vector3 = e1.cross(e2)
		final_normals[i0] += fn
		final_normals[i1] += fn
		final_normals[i2] += fn
	for i in range(final_normals.size()):
		var len: float = final_normals[i].length()
		if len > 0.0001:
			final_normals[i] /= len
		else:
			final_normals[i] = Vector3.UP

	var out := _prepare_geo()
	var out_arrays: Array = []
	out_arrays.resize(Mesh.ARRAY_MAX)
	out_arrays[Mesh.ARRAY_VERTEX] = final_verts
	out_arrays[Mesh.ARRAY_NORMAL] = final_normals
	out_arrays[Mesh.ARRAY_INDEX] = final_indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out_arrays)
	out.set_mesh(mesh)
	return out


# ─── Quadric helpers ──────────────────────────────────────────────────────────

static func _plane_quadric(a: float, b: float, c: float, d: float) -> PackedFloat64Array:
	return PackedFloat64Array([
		a * a, a * b, a * c, a * d,
		b * b, b * c, b * d,
		c * c, c * d,
		d * d
	])


static func _add_quadrics(q1: PackedFloat64Array, q2: PackedFloat64Array) -> PackedFloat64Array:
	var r := PackedFloat64Array()
	r.resize(10)
	for i in range(10):
		r[i] = q1[i] + q2[i]
	return r


static func _eval_quadric(q: PackedFloat64Array, v: Vector3) -> float:
	var x: float = v.x; var y: float = v.y; var z: float = v.z
	return (q[0] * x * x + 2.0 * q[1] * x * y + 2.0 * q[2] * x * z + 2.0 * q[3] * x +
			q[4] * y * y + 2.0 * q[5] * y * z + 2.0 * q[6] * y +
			q[7] * z * z + 2.0 * q[8] * z +
			q[9])


static func _compute_collapse(a: int, b: int, pos: PackedVector3Array,
		quadrics: Array[PackedFloat64Array]) -> Array:
	var combined := _add_quadrics(quadrics[a], quadrics[b])
	# Try midpoint and both endpoints, pick best
	var mid: Vector3 = (pos[a] + pos[b]) * 0.5
	var cost_a: float = _eval_quadric(combined, pos[a])
	var cost_b: float = _eval_quadric(combined, pos[b])
	var cost_mid: float = _eval_quadric(combined, mid)

	var best_pos: Vector3 = mid
	var best_cost: float = cost_mid
	if cost_a < best_cost:
		best_cost = cost_a
		best_pos = pos[a]
	if cost_b < best_cost:
		best_cost = cost_b
		best_pos = pos[b]

	return [best_cost, best_pos, a, b]


static func _edge_key(a: int, b: int) -> int:
	if a > b:
		return (a << 20) | b
	return (b << 20) | a


static func _resolve(v: int, remap: PackedInt32Array) -> int:
	var max_iter: int = 1000
	while remap[v] != v and max_iter > 0:
		remap[v] = remap[remap[v]]  # Path compression
		v = remap[v]
		max_iter -= 1
	return v


static func _vec_key(v: Vector3) -> String:
	# Quantise to micrometer precision for welding
	return "%d_%d_%d" % [int(v.x * 10000), int(v.y * 10000), int(v.z * 10000)]
