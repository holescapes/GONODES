# @param int count 100 Number of points
# @param float radius 1.0 Sphere radius
# @param bool animate false Rotate points over time

func cook():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_POINTS)

	var n = par("count")
	var rad = par("radius")
	var t = time if par("animate") else 0.0

	# Fibonacci sphere distribution for even point spread
	var golden = (1.0 + sqrt(5.0)) / 2.0

	for i in range(n):
		var theta = acos(1.0 - 2.0 * (i + 0.5) / float(n))
		var phi = TAU * float(i) / golden + t

		var pos = Vector3(
			sin(theta) * cos(phi) * rad,
			cos(theta) * rad,
			sin(theta) * sin(phi) * rad)
		st.set_normal(pos.normalized())
		st.set_color(Color(
			(pos.x / rad + 1.0) * 0.5,
			(pos.y / rad + 1.0) * 0.5,
			(pos.z / rad + 1.0) * 0.5))
		st.add_vertex(pos)

	op.set_from_surfacetool(st)
