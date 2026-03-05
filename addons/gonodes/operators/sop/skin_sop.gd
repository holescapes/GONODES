class_name SkinSOP
extends GNSopBase
## Skins (lofts) multiple cross-section curves into a surface mesh.
## Each dynamic input supplies a cross-section polyline/polygon.
## Cross-sections should have matching vertex counts for best results.


func _init() -> void:
	node_type = "skin"
	node_description = "Skin cross-sections into a mesh surface."
	_enable_dynamic_inputs(GNFamily.Type.SOP, "section", "Cross-section")


func _init_ports() -> void:
	add_input("section_0", GNFamily.Type.SOP, false, "Cross-section 0")
	add_output("out", GNFamily.Type.SOP, "Skinned mesh")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("close_u", true, "",
		"Close each cross-section ring"))
	add_parameter(GNParameter.create_bool("close_v", false, "",
		"Close along backbone (loop)"))
	add_parameter(GNParameter.create_bool("end_caps", false, "",
		"Cap ends with fan triangles"))
	add_parameter(GNParameter.create_bool("recompute_normals", true, "",
		"Recompute smooth normals after skinning"))


func _cook(inputs: Array[GNData]) -> GNData:
	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var close_u: bool = get_param_value("close_u")
	var close_v: bool = get_param_value("close_v")
	var end_caps: bool = get_param_value("end_caps")
	var recompute: bool = get_param_value("recompute_normals")

	# Gather cross-sections from all inputs
	var sections: Array[PackedVector3Array] = []
	for i in range(inputs.size()):
		var geo: GNGeoData = _get_input_sop(inputs, i)
		if geo != null and geo.has_geometry():
			var pts := _extract_points(geo)
			if pts.size() >= 2:
				sections.append(pts)

	if sections.size() < 2:
		return null

	# Determine the maximum segment count across all cross-sections
	# and resample shorter ones to match (linear interpolation)
	var max_pts: int = 0
	for sec in sections:
		max_pts = maxi(max_pts, sec.size())

	if max_pts < 2:
		return null

	var uniform_sections: Array[PackedVector3Array] = []
	for sec in sections:
		if sec.size() == max_pts:
			uniform_sections.append(sec)
		else:
			uniform_sections.append(_resample_section(sec, max_pts))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rings: int = uniform_sections.size()
	var sides: int = max_pts

	# Build quads between consecutive cross-sections
	var ring_count: int = rings + (1 if close_v else 0)
	for ri in range(ring_count - 1):
		var r0_idx: int = ri % rings
		var r1_idx: int = (ri + 1) % rings
		var r0: PackedVector3Array = uniform_sections[r0_idx]
		var r1: PackedVector3Array = uniform_sections[r1_idx]

		var side_count: int = sides - (0 if close_u else 1)

		for si in range(side_count):
			var s0: int = si
			var s1: int = (si + 1) % sides

			var v00: Vector3 = r0[s0]
			var v10: Vector3 = r0[s1]
			var v01: Vector3 = r1[s0]
			var v11: Vector3 = r1[s1]

			var u0: float = float(si) / sides
			var u1: float = float(si + 1) / sides
			var vv0: float = float(ri) / maxf(ring_count - 1, 1)
			var vv1: float = float(ri + 1) / maxf(ring_count - 1, 1)

			st.set_uv(Vector2(u0, vv0)); st.add_vertex(v00)
			st.set_uv(Vector2(u1, vv0)); st.add_vertex(v10)
			st.set_uv(Vector2(u0, vv1)); st.add_vertex(v01)

			st.set_uv(Vector2(u1, vv0)); st.add_vertex(v10)
			st.set_uv(Vector2(u1, vv1)); st.add_vertex(v11)
			st.set_uv(Vector2(u0, vv1)); st.add_vertex(v01)

	# End caps
	if end_caps and not close_v and rings >= 2:
		_add_fan_cap(st, uniform_sections[0], false)
		_add_fan_cap(st, uniform_sections[rings - 1], true)

	if recompute:
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


## Linearly resample a polyline to a target point count.
func _resample_section(pts: PackedVector3Array, target_count: int) -> PackedVector3Array:
	var result := PackedVector3Array()
	result.resize(target_count)
	var src_count: int = pts.size()
	for i in range(target_count):
		var frac: float = float(i) / maxf(target_count - 1, 1)
		var src_f: float = frac * (src_count - 1)
		var idx: int = mini(int(src_f), src_count - 2)
		var t: float = src_f - idx
		result[i] = pts[idx].lerp(pts[idx + 1], t)
	return result


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
