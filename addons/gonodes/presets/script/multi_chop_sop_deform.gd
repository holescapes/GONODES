# @input chop Control channels (use channel 0 for amplitude)
# @input sop  Input geometry to deform
# @output sop Deformed geometry
# @param float base_amplitude 0.5 Deformation strength when no CHOP input
# @param float frequency 3.0 Wave frequency across surface

func cook():
	# Read amplitude from CHOP input (first channel, last sample) or use default
	var amp = par("base_amplitude")
	var chop_src = inputs[0] if inputs.size() > 0 else null
	if chop_src != null and chop_src is GNChannelData:
		var ch_names = chop_src.get_channel_names()
		if not ch_names.is_empty():
			var samples = chop_src.get_channel(ch_names[0])
			if not samples.is_empty():
				amp = samples[samples.size() - 1]

	# Read geometry from SOP input
	var geo = inputs[1] if inputs.size() > 1 else null
	if geo == null or not (geo is GNGeoData) or not geo.has_geometry():
		return

	var freq = par("frequency")
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for surf_idx in range(geo.get_surface_count()):
		var arrays = geo.get_surface_arrays(surf_idx)
		if arrays.is_empty():
			continue
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals = arrays[Mesh.ARRAY_NORMAL]
		var uvs = arrays[Mesh.ARRAY_TEX_UV]

		for i in range(positions.size()):
			var p = positions[i]
			var wave = sin(p.x * freq + time * 2.0) * cos(p.z * freq + time * 1.5)
			var normal = normals[i] if normals != null and i < normals.size() else Vector3.UP
			var displaced = p + normal * wave * amp

			if normals != null and i < normals.size():
				st.set_normal(normals[i])
			if uvs != null and i < uvs.size():
				st.set_uv(uvs[i])
			st.add_vertex(displaced)

	st.generate_normals()
	outputs[0].set_from_surface_tool(st)
