# @output sop Output geometry
# @input sop Source geometry to deform
# @param float amplitude 0.5 Noise displacement strength
# @param float frequency 2.0 Noise spatial frequency
# @param float speed 1.0 Animation speed

func cook():
	var geo = inputs[0] if inputs.size() > 0 else null
	if geo == null or not (geo is GNGeoData) or not geo.has_geometry():
		return

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var amp = par("amplitude")
	var freq = par("frequency")
	var spd = par("speed")

	# Process each surface
	for surf_idx in range(geo.get_surface_count()):
		var arrays = geo.get_surface_arrays(surf_idx)
		if arrays.is_empty():
			continue
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals = arrays[Mesh.ARRAY_NORMAL]
		var uvs = arrays[Mesh.ARRAY_TEX_UV]

		for i in range(positions.size()):
			var pos = positions[i]
			# Simple 3D noise displacement along normal
			var n = sin(pos.x * freq + time * spd) * \
					cos(pos.y * freq + time * spd * 0.7) * \
					sin(pos.z * freq + time * spd * 1.3)
			var normal = normals[i] if normals != null and i < normals.size() else Vector3.UP
			var displaced = pos + normal * n * amp

			if normals != null and i < normals.size():
				st.set_normal(normals[i])
			if uvs != null and i < uvs.size():
				st.set_uv(uvs[i])
			st.add_vertex(displaced)

	st.generate_normals()
	op.set_from_surface_tool(st)
