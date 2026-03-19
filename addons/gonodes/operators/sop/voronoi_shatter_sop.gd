class_name VoronoiShatterSOP
extends GNSopBase
## Fractures input geometry via 3D Voronoi decomposition.
##
## Seeds are scattered inside the mesh bounding box.  Each seed defines
## a Voronoi cell.  The input mesh is clipped against each cell's
## half-planes, producing separate fragment surfaces.
##
## Outputs all fragments as distinct surfaces in the same GNGeoData.
## point_attrib "piece" stores the fragment index per vertex.

func _init() -> void:
	node_type = "voronoishatter"
	node_description = "Fracture geometry using 3D Voronoi decomposition."

func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Geometry to fracture")
	add_output("out", GNFamily.Type.SOP, "Fractured geometry (one surface per piece)")

func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("num_points", 8, 2, 256,
		"Num Points", "Number of Voronoi seed points"))
	add_parameter(GNParameter.create_int("seed", 0, 0, 99999,
		"Seed", "Random seed for point scatter"))
	add_parameter(GNParameter.create_float("offset", 0.0, 0.0, 0.1, 0.001,
		"Offset", "Gap between pieces (explode factor)"))
	add_parameter(GNParameter.create_bool("interior_faces", true,
		"Interior Faces", "Generate faces on cut planes"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo := _get_input_sop(inputs, 0)
	if in_geo == null or not in_geo.has_geometry():
		return null

	var num_pts: int = get_param_value("num_points")
	var rseed: int = get_param_value("seed")
	var offset_val: float = get_param_value("offset")
	var do_interior: bool = get_param_value("interior_faces")

	# Gather all triangles from input
	var all_tris: Array[PackedVector3Array] = []
	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices = arrays[Mesh.ARRAY_INDEX]
		if indices != null and indices.size() >= 3:
			var idx_arr: PackedInt32Array = indices
			for i in range(0, idx_arr.size(), 3):
				var tri := PackedVector3Array()
				tri.append(verts[idx_arr[i]])
				tri.append(verts[idx_arr[i + 1]])
				tri.append(verts[idx_arr[i + 2]])
				all_tris.append(tri)
		else:
			for i in range(0, verts.size(), 3):
				if i + 2 < verts.size():
					var tri := PackedVector3Array()
					tri.append(verts[i])
					tri.append(verts[i + 1])
					tri.append(verts[i + 2])
					all_tris.append(tri)

	if all_tris.is_empty():
		return null

	var bbox: AABB = in_geo.bounds

	# Generate seed points inside bounding box
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var seeds: PackedVector3Array = PackedVector3Array()
	seeds.resize(num_pts)
	for i in range(num_pts):
		seeds[i] = Vector3(
			rng.randf_range(bbox.position.x, bbox.end.x),
			rng.randf_range(bbox.position.y, bbox.end.y),
			rng.randf_range(bbox.position.z, bbox.end.z))

	var out_geo := _prepare_geo()
	var new_mesh := ArrayMesh.new()
	var piece_attrib := PackedFloat32Array()
	var vert_offset: int = 0

	# For each Voronoi cell: clip all triangles against half-planes
	for cell_idx in range(num_pts):
		var cell_seed: Vector3 = seeds[cell_idx]

		# Build clip planes: for each other seed, plane bisects the pair
		var planes: Array[Plane] = []
		for other_idx in range(num_pts):
			if other_idx == cell_idx:
				continue
			var midpoint: Vector3 = (cell_seed + seeds[other_idx]) * 0.5
			var normal: Vector3 = (seeds[other_idx] - cell_seed).normalized()
			planes.append(Plane(normal, midpoint))

		# Clip triangles against all half-planes
		var cell_polys: Array[PackedVector3Array] = []
		for tri in all_tris:
			var polys: Array[PackedVector3Array] = [tri]
			for plane in planes:
				var clipped: Array[PackedVector3Array] = []
				for poly in polys:
					var inside := _clip_polygon_by_plane(poly, plane)
					if inside.size() >= 3:
						clipped.append(inside)
				polys = clipped
				if polys.is_empty():
					break
			cell_polys.append_array(polys)

		if cell_polys.is_empty():
			continue

		# Build surface from clipped polygons
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var cell_vert_count: int = 0

		# Offset direction from global centroid
		var cell_centroid := Vector3.ZERO
		if offset_val > 0.0:
			cell_centroid = cell_seed - bbox.get_center()
			if cell_centroid.length_squared() > 0.001:
				cell_centroid = cell_centroid.normalized() * offset_val
			else:
				cell_centroid = Vector3.ZERO

		for poly in cell_polys:
			# Fan-triangulate convex polygon
			for i in range(1, poly.size() - 1):
				var v0: Vector3 = poly[0] + cell_centroid
				var v1: Vector3 = poly[i] + cell_centroid
				var v2: Vector3 = poly[i + 1] + cell_centroid
				var edge1: Vector3 = v1 - v0
				var edge2: Vector3 = v2 - v0
				var n: Vector3 = edge1.cross(edge2)
				if n.length_squared() < 1e-12:
					continue
				n = n.normalized()
				st.set_normal(n)
				st.add_vertex(v0)
				st.set_normal(n)
				st.add_vertex(v1)
				st.set_normal(n)
				st.add_vertex(v2)
				cell_vert_count += 3

		# Generate interior faces (cap the cut planes)
		if do_interior and cell_vert_count > 0:
			for plane in planes:
				var interior_verts := _collect_plane_intersection_loop(cell_polys, plane)
				if interior_verts.size() >= 3:
					var cap_n: Vector3 = -plane.normal
					for i in range(1, interior_verts.size() - 1):
						st.set_normal(cap_n)
						st.add_vertex(interior_verts[0] + cell_centroid)
						st.set_normal(cap_n)
						st.add_vertex(interior_verts[i] + cell_centroid)
						st.set_normal(cap_n)
						st.add_vertex(interior_verts[i + 1] + cell_centroid)
						cell_vert_count += 3

		if cell_vert_count > 0:
			st.generate_tangents()
			st.commit(new_mesh)
			# Track piece attribute
			for _v in range(cell_vert_count):
				piece_attrib.append(float(cell_idx))
			vert_offset += cell_vert_count

	out_geo.set_mesh(new_mesh)
	if piece_attrib.size() > 0:
		out_geo.set_point_attrib("piece", piece_attrib)
	return out_geo


# ══════════════════════════════════════════════════════════════════════════════
# Geometry Clipping Utilities
# ══════════════════════════════════════════════════════════════════════════════

## Sutherland-Hodgman clip: returns the portion of polygon on the negative
## side (toward the cell seed) of the plane.
func _clip_polygon_by_plane(poly: PackedVector3Array, plane: Plane) -> PackedVector3Array:
	var result := PackedVector3Array()
	var count: int = poly.size()
	if count < 3:
		return result

	for i in range(count):
		var cur: Vector3 = poly[i]
		var nxt: Vector3 = poly[(i + 1) % count]
		var d_cur: float = plane.normal.dot(cur) - plane.d
		var d_nxt: float = plane.normal.dot(nxt) - plane.d

		if d_cur <= 0.0:
			result.append(cur)
			if d_nxt > 0.0:
				# Exiting: add intersection
				var t: float = d_cur / (d_cur - d_nxt)
				result.append(cur.lerp(nxt, t))
		elif d_nxt <= 0.0:
			# Entering: add intersection
			var t: float = d_cur / (d_cur - d_nxt)
			result.append(cur.lerp(nxt, t))

	return result


## Collect vertices that lie (approximately) on a given plane from all polygons.
## Used for generating interior cap faces.
func _collect_plane_intersection_loop(polys: Array[PackedVector3Array], plane: Plane) -> PackedVector3Array:
	var on_plane := PackedVector3Array()
	var eps: float = 0.001

	for poly in polys:
		for v in poly:
			var dist: float = absf(plane.normal.dot(v) - plane.d)
			if dist < eps:
				# Skip duplicates
				var is_dup := false
				for existing in on_plane:
					if existing.distance_to(v) < eps:
						is_dup = true
						break
				if not is_dup:
					on_plane.append(v)

	if on_plane.size() < 3:
		return on_plane

	# Sort vertices into convex order by projecting onto the plane
	var center := Vector3.ZERO
	for v in on_plane:
		center += v
	center /= float(on_plane.size())

	var u_axis: Vector3 = (on_plane[0] - center)
	if u_axis.length_squared() < 1e-10:
		return on_plane
	u_axis = u_axis.normalized()
	var v_axis: Vector3 = plane.normal.cross(u_axis).normalized()

	# Compute angles and sort
	var angle_pairs: Array = []
	for v in on_plane:
		var rel: Vector3 = v - center
		var angle: float = atan2(rel.dot(v_axis), rel.dot(u_axis))
		angle_pairs.append([angle, v])
	angle_pairs.sort_custom(func(a, b): return a[0] < b[0])

	var sorted := PackedVector3Array()
	for pair in angle_pairs:
		sorted.append(pair[1])
	return sorted
