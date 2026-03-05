class_name SweepSOP
extends GNSopBase
## Sweeps a cross-section profile along a backbone curve (rail).
## Input 0 = backbone (line strip), Input 1 = profile (cross-section, optional).
## Uses rotation-minimizing frames (parallel transport) for twist-free extrusion.


func _init() -> void:
	node_type = "sweep"
	node_description = "Sweep a cross-section along a curve."


func _init_ports() -> void:
	add_input("backbone", GNFamily.Type.SOP, false, "Backbone curve (line strip)")
	add_input("profile", GNFamily.Type.SOP, true, "Profile cross-section (optional — uses circle)")
	add_output("out", GNFamily.Type.SOP, "Swept mesh")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("scale", 0.1, 0.001, 50.0, 0.01,
		"Profile Scale", "Uniform scale of the cross-section"))
	add_parameter(GNParameter.create_int("profile_segs", 12, 3, 128,
		"Profile Segments", "Circle segments if no profile input"))
	add_parameter(GNParameter.create_bool("close_profile", true, "",
		"Close the profile ring"))
	add_parameter(GNParameter.create_bool("close_backbone", false, "",
		"Close the backbone (loop)"))
	add_parameter(GNParameter.create_bool("end_caps", false, "",
		"Generate end caps"))


func _cook(inputs: Array[GNData]) -> GNData:
	var bb_geo: GNGeoData = _get_input_sop(inputs, 0)
	if bb_geo == null or not bb_geo.has_geometry():
		return null

	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var profile_geo: GNGeoData = _get_input_sop(inputs, 1)
	var scl: float = get_param_value("scale")
	var prof_segs: int = maxi(get_param_value("profile_segs"), 3)
	var close_prof: bool = get_param_value("close_profile")
	var close_bb: bool = get_param_value("close_backbone")
	var end_caps: bool = get_param_value("end_caps")

	# Extract backbone points
	var bb_points := _extract_points(bb_geo)
	if bb_points.size() < 2:
		return null

	# Extract or generate profile points (2D cross-section in XY)
	var profile: PackedVector2Array
	if profile_geo != null and profile_geo.has_geometry():
		profile = _extract_profile_2d(profile_geo)
	else:
		profile = _make_circle_profile(prof_segs)

	if profile.size() < 2:
		return null

	# Compute rotation-minimizing frames along backbone
	var frames: Array[Transform3D] = _compute_rmf(bb_points)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rings: int = frames.size()
	var sides: int = profile.size()

	# Place profile at each frame
	var ring_verts: Array[PackedVector3Array] = []
	for fi in range(rings):
		var xform: Transform3D = frames[fi]
		var ring := PackedVector3Array()
		ring.resize(sides)
		for si in range(sides):
			var local: Vector3 = Vector3(profile[si].x * scl, profile[si].y * scl, 0.0)
			ring[si] = xform * local
		ring_verts.append(ring)

	# Build quads between consecutive rings
	var ring_count: int = rings + (1 if close_bb else 0)
	for ri in range(ring_count - 1):
		var r0: int = ri % rings
		var r1: int = (ri + 1) % rings
		var side_count: int = sides - (0 if close_prof else 1)

		for si in range(side_count):
			var s0: int = si
			var s1: int = (si + 1) % sides

			var v00: Vector3 = ring_verts[r0][s0]
			var v10: Vector3 = ring_verts[r0][s1]
			var v01: Vector3 = ring_verts[r1][s0]
			var v11: Vector3 = ring_verts[r1][s1]

			var u0: float = float(si) / sides
			var u1: float = float(si + 1) / sides
			var vv0: float = float(ri) / (ring_count - 1)
			var vv1: float = float(ri + 1) / (ring_count - 1)

			st.set_uv(Vector2(u0, vv0)); st.add_vertex(v00)
			st.set_uv(Vector2(u1, vv0)); st.add_vertex(v10)
			st.set_uv(Vector2(u0, vv1)); st.add_vertex(v01)

			st.set_uv(Vector2(u1, vv0)); st.add_vertex(v10)
			st.set_uv(Vector2(u1, vv1)); st.add_vertex(v11)
			st.set_uv(Vector2(u0, vv1)); st.add_vertex(v01)

	# End caps
	if end_caps and not close_bb and ring_verts.size() >= 2:
		_add_fan_cap(st, ring_verts[0], false)
		_add_fan_cap(st, ring_verts[ring_verts.size() - 1], true)

	st.generate_normals()
	st.generate_tangents()

	var mesh := ArrayMesh.new()
	st.commit(mesh)
	_cached_geo.set_mesh(mesh)
	return _cached_geo


func _extract_points(geo: GNGeoData) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for s in range(geo.mesh.get_surface_count()):
		var arrays: Array = geo.mesh.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			pts.append_array(arrays[Mesh.ARRAY_VERTEX])
	return pts


func _extract_profile_2d(geo: GNGeoData) -> PackedVector2Array:
	var pts_3d := _extract_points(geo)
	var result := PackedVector2Array()
	for p in pts_3d:
		result.append(Vector2(p.x, p.y))
	return result


func _make_circle_profile(segs: int) -> PackedVector2Array:
	var profile := PackedVector2Array()
	for i in range(segs):
		var angle: float = TAU * float(i) / segs
		profile.append(Vector2(cos(angle), sin(angle)))
	return profile


## Parallel transport / rotation-minimizing frames along a polyline.
func _compute_rmf(points: PackedVector3Array) -> Array[Transform3D]:
	var n: int = points.size()
	var frames: Array[Transform3D] = []

	# Initial frame at first point
	var t0: Vector3 = (points[1] - points[0]).normalized()
	var up: Vector3
	if absf(t0.dot(Vector3.UP)) > 0.999:
		up = Vector3.RIGHT
	else:
		up = Vector3.UP
	var right0: Vector3 = t0.cross(up).normalized()
	var normal0: Vector3 = right0.cross(t0).normalized()

	var basis0 := Basis(right0, normal0, -t0)
	frames.append(Transform3D(basis0, points[0]))

	# Propagate frames using double reflection (rotation-minimizing)
	for i in range(1, n):
		var prev_t: Vector3 = frames[i - 1].basis.z * -1.0  # forward = -z
		var prev_r: Vector3 = frames[i - 1].basis.x
		var curr_t: Vector3
		if i < n - 1:
			curr_t = (points[i + 1] - points[i - 1]).normalized()
		else:
			curr_t = (points[i] - points[i - 1]).normalized()

		if curr_t.length_squared() < 0.0001:
			curr_t = prev_t

		# Double reflection method
		var v1: Vector3 = points[i] - points[i - 1]
		var c1: float = v1.dot(v1)
		if c1 < 0.00001:
			frames.append(Transform3D(frames[i - 1].basis, points[i]))
			continue

		var r_reflect: Vector3 = prev_r - (2.0 / c1) * v1.dot(prev_r) * v1
		var t_reflect: Vector3 = prev_t - (2.0 / c1) * v1.dot(prev_t) * v1

		var v2: Vector3 = curr_t - t_reflect
		var c2: float = v2.dot(v2)
		if c2 < 0.00001:
			var new_basis := Basis(r_reflect.normalized(),
				r_reflect.cross(-curr_t).normalized(), -curr_t)
			frames.append(Transform3D(new_basis, points[i]))
		else:
			var new_r: Vector3 = r_reflect - (2.0 / c2) * v2.dot(r_reflect) * v2
			var new_n: Vector3 = new_r.cross(curr_t).normalized()
			new_r = new_r.normalized()
			var new_basis := Basis(new_r, new_n, -curr_t)
			frames.append(Transform3D(new_basis, points[i]))

	return frames


func _add_fan_cap(st: SurfaceTool, ring: PackedVector3Array, flip: bool) -> void:
	if ring.size() < 3:
		return
	var center := Vector3.ZERO
	for p in ring:
		center += p
	center /= ring.size()

	for i in range(ring.size()):
		var i_next: int = (i + 1) % ring.size()
		st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(center)
		if flip:
			st.set_uv(Vector2(0, 0)); st.add_vertex(ring[i_next])
			st.set_uv(Vector2(1, 0)); st.add_vertex(ring[i])
		else:
			st.set_uv(Vector2(0, 0)); st.add_vertex(ring[i])
			st.set_uv(Vector2(1, 0)); st.add_vertex(ring[i_next])
