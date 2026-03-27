# @input sop Source geometry
# @param float low_y -1.0 Bottom of color ramp (blue=cold)
# @param float high_y 1.0 Top of color ramp (red=hot)
# @param float deform_strength 0.3 Noise displacement on hot vertices
# @param float frequency 3.0 Noise spatial frequency
# @param float speed 1.0 Animation speed

func cook():
	var geo = inputs[0] if inputs.size() > 0 else null
	if geo == null or not (geo is GNGeoData) or not geo.has_geometry():
		return

	var lo = par("low_y")
	var hi = par("high_y")
	var strength = par("deform_strength")
	var freq = par("frequency")
	var spd = par("speed")
	var range_inv = 1.0 / max(hi - lo, 0.001)

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Accumulate attrib arrays across all surfaces
	var all_cd_r := PackedFloat32Array()
	var all_cd_g := PackedFloat32Array()
	var all_cd_b := PackedFloat32Array()
	var all_mask := PackedFloat32Array()

	for surf_idx in range(geo.get_surface_count()):
		var arrays = geo.get_surface_arrays(surf_idx)
		if arrays.is_empty():
			continue
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals = arrays[Mesh.ARRAY_NORMAL]
		var uvs = arrays[Mesh.ARRAY_TEX_UV]

		for i in range(positions.size()):
			var pos = positions[i]

			# Height-based 0→1 gradient (clamped)
			var t = clampf((pos.y - lo) * range_inv, 0.0, 1.0)

			# Color: blue (cold) → green (mid) → red (hot)
			var r = clampf(t * 2.0 - 1.0, 0.0, 1.0)
			var g = 1.0 - abs(t * 2.0 - 1.0)
			var b = clampf(1.0 - t * 2.0, 0.0, 1.0)

			all_cd_r.append(r)
			all_cd_g.append(g)
			all_cd_b.append(b)
			all_mask.append(t)

			# Use mask (height) to drive displacement — hot areas deform more
			var normal = normals[i] if normals != null and i < normals.size() else Vector3.UP
			var noise_val = sin(pos.x * freq + time * spd) * cos(pos.z * freq + time * spd * 0.8)
			var displaced = pos + normal * noise_val * strength * t

			st.set_color(Color(r, g, b, 1.0))
			if normals != null and i < normals.size():
				st.set_normal(normals[i])
			if uvs != null and i < uvs.size():
				st.set_uv(uvs[i])
			st.add_vertex(displaced)

	st.generate_normals()
	op.set_from_surface_tool(st)

	# Store point attributes on the output GNGeoData
	# These travel downstream for other SOPs/CHOPs to read
	op.set_point_attrib("Cd_r", all_cd_r)
	op.set_point_attrib("Cd_g", all_cd_g)
	op.set_point_attrib("Cd_b", all_cd_b)
	op.set_point_attrib("mask", all_mask)
