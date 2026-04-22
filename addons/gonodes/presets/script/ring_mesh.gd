# @param int segments 64 Number of ring segments
# @param float inner_radius 0.3 Inner ring radius
# @param float outer_radius 1.0 Outer ring radius
# @param float twist 0.0 Twist amount (radians)

func cook():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var segs = par("segments")
	var r_inner = par("inner_radius")
	var r_outer = par("outer_radius")
	var tw = par("twist")

	for i in range(segs):
		var t0 = float(i) / float(segs) * TAU
		var t1 = float(i + 1) / float(segs) * TAU

		var twist0 = float(i) / float(segs) * tw
		var twist1 = float(i + 1) / float(segs) * tw

		# Inner and outer vertices for two consecutive segments
		var vi0 = Vector3(cos(t0) * r_inner, sin(twist0) * 0.1, sin(t0) * r_inner)
		var vo0 = Vector3(cos(t0) * r_outer, 0.0, sin(t0) * r_outer)
		var vi1 = Vector3(cos(t1) * r_inner, sin(twist1) * 0.1, sin(t1) * r_inner)
		var vo1 = Vector3(cos(t1) * r_outer, 0.0, sin(t1) * r_outer)

		var normal = Vector3.UP
		st.set_normal(normal)

		# Triangle 1
		st.set_uv(Vector2(float(i) / segs, 0))
		st.add_vertex(vi0)
		st.set_uv(Vector2(float(i) / segs, 1))
		st.add_vertex(vo0)
		st.set_uv(Vector2(float(i + 1) / segs, 1))
		st.add_vertex(vo1)

		# Triangle 2
		st.set_uv(Vector2(float(i) / segs, 0))
		st.add_vertex(vi0)
		st.set_uv(Vector2(float(i + 1) / segs, 1))
		st.add_vertex(vo1)
		st.set_uv(Vector2(float(i + 1) / segs, 0))
		st.add_vertex(vi1)

	st.generate_normals()
	op.set_from_surfacetool(st)
