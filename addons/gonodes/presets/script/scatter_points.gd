# @output sop Output geometry
# @param int count 100 Number of points to scatter
# @param float radius 2.0 Scatter radius
# @param int seed 0 Random seed (0 = use frame number)

func cook():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_POINTS)

	var rng = RandomNumberGenerator.new()
	rng.seed = par("seed") if par("seed") != 0 else frame

	var r = par("radius")
	for i in range(par("count")):
		var pos = Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0)
		).normalized() * r * rng.randf()
		st.set_normal(pos.normalized())
		st.add_vertex(pos)

	op.set_from_surface_tool(st)
