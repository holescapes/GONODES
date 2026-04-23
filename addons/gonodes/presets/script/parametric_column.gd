# @output sop Output geometry
# @param float height 2.0 Total height
# @param float base_radius 1.0 Radius at bottom
# @param int stacks 12 Vertical divisions
# @param int slices 24 Radial divisions
# @param float taper 0.0 Top radius factor (0=cone, 1=cylinder)

func cook():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var h = par("height")
	var r = par("base_radius")
	var stx = par("stacks")
	var slx = par("slices")
	var taper = clampf(par("taper"), 0.0, 1.0)

	for j in range(stx):
		var y0 = float(j) / stx * h - h * 0.5
		var y1 = float(j + 1) / stx * h - h * 0.5
		var r0 = r * lerpf(1.0, taper, float(j) / stx)
		var r1 = r * lerpf(1.0, taper, float(j + 1) / stx)

		for i in range(slx):
			var a0 = float(i) / slx * TAU
			var a1 = float(i + 1) / slx * TAU

			var p00 = Vector3(cos(a0) * r0, y0, sin(a0) * r0)
			var p10 = Vector3(cos(a1) * r0, y0, sin(a1) * r0)
			var p01 = Vector3(cos(a0) * r1, y1, sin(a0) * r1)
			var p11 = Vector3(cos(a1) * r1, y1, sin(a1) * r1)

			st.set_uv(Vector2(float(i) / slx, float(j) / stx))
			st.add_vertex(p00)
			st.set_uv(Vector2(float(i + 1) / slx, float(j) / stx))
			st.add_vertex(p10)
			st.set_uv(Vector2(float(i + 1) / slx, float(j + 1) / stx))
			st.add_vertex(p11)

			st.set_uv(Vector2(float(i) / slx, float(j) / stx))
			st.add_vertex(p00)
			st.set_uv(Vector2(float(i + 1) / slx, float(j + 1) / stx))
			st.add_vertex(p11)
			st.set_uv(Vector2(float(i) / slx, float(j + 1) / stx))
			st.add_vertex(p01)

	st.generate_normals()
	op.set_from_surface_tool(st)
