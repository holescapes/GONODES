class_name PolySplineSOP
extends GNSopBase
## Generate a smooth spline curve or tube from input points.
##
## Takes input point positions and fits a Catmull-Rom spline through
## them, optionally creating a tube/ribbon mesh around the curve.
##
## TouchDesigner equivalent: PolySpline SOP.


func _init() -> void:
	node_type = "poly_spline"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input points (vertices used as control points)", "In")
	add_output("out", GNFamily.Type.SOP, "Spline curve or tube mesh", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("subdivisions", 8, 1, 64,
		"Subdivisions", "Points per spline segment"))
	add_parameter(GNParameter.create_enum("output", ["Line", "Tube", "Ribbon"],
		0, "Output", "Geometry type"))
	add_parameter(GNParameter.create_float("radius", 0.05, 0.001, 10.0, 0.001,
		"Radius", "Tube/ribbon radius"))
	add_parameter(GNParameter.create_int("sides", 8, 3, 32,
		"Sides", "Number of sides for tube cross-section"))
	add_parameter(GNParameter.create_bool("closed", false,
		"Closed", "Close the spline loop"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo := _get_input_sop(inputs, 0)
	if in_geo == null or not in_geo.has_geometry():
		return null

	var cp := in_geo.get_positions()
	if cp.size() < 2:
		return null

	var subdivs: int = get_param_value("subdivisions")
	var output_mode: int = get_param_value("output")
	var radius: float = get_param_value("radius")
	var sides: int = get_param_value("sides")
	var closed: bool = get_param_value("closed")

	# Evaluate Catmull-Rom spline
	var spline_pts := _evaluate_catmull_rom(cp, subdivs, closed)

	if output_mode == 0:
		return _build_line(spline_pts)
	elif output_mode == 1:
		return _build_tube(spline_pts, radius, sides)
	else:
		return _build_ribbon(spline_pts, radius)


func _evaluate_catmull_rom(cp: PackedVector3Array, subdivs: int,
		closed: bool) -> PackedVector3Array:
	var result := PackedVector3Array()
	var n := cp.size()

	for i in range(n - 1 if not closed else n):
		var p0 := cp[((i - 1) + n) % n]
		var p1 := cp[i]
		var p2 := cp[(i + 1) % n]
		var p3 := cp[(i + 2) % n]

		for s in range(subdivs):
			var t := float(s) / float(subdivs)
			result.append(_catmull_rom(p0, p1, p2, p3, t))

	# Add final point
	if not closed:
		result.append(cp[n - 1])

	return result


func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _build_line(pts: PackedVector3Array) -> GNData:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINE_STRIP)
	for pt in pts:
		st.add_vertex(pt)
	var out_geo := _prepare_geo()
	out_geo.set_from_surface_tool(st)
	return out_geo


func _build_tube(pts: PackedVector3Array, radius: float, sides: int) -> GNData:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rings: Array[PackedVector3Array] = []
	for i in range(pts.size()):
		var forward: Vector3
		if i < pts.size() - 1:
			forward = (pts[i + 1] - pts[i]).normalized()
		else:
			forward = (pts[i] - pts[i - 1]).normalized()

		# Build perpendicular frame
		var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
		var right := forward.cross(up).normalized()
		up = right.cross(forward).normalized()

		var ring := PackedVector3Array()
		for s in range(sides):
			var angle := float(s) / float(sides) * TAU
			var offset := (right * cos(angle) + up * sin(angle)) * radius
			ring.append(pts[i] + offset)
		rings.append(ring)

	# Connect rings
	for i in range(rings.size() - 1):
		for s in range(sides):
			var s_next := (s + 1) % sides
			var a := rings[i][s]
			var b := rings[i][s_next]
			var c := rings[i + 1][s_next]
			var d := rings[i + 1][s]

			var n := (c - a).cross(b - a).normalized()
			st.set_normal(n)
			st.add_vertex(a)
			st.set_normal(n)
			st.add_vertex(b)
			st.set_normal(n)
			st.add_vertex(c)
			st.set_normal(n)
			st.add_vertex(a)
			st.set_normal(n)
			st.add_vertex(c)
			st.set_normal(n)
			st.add_vertex(d)

	var out_geo := _prepare_geo()
	out_geo.set_from_surface_tool(st)
	return out_geo


func _build_ribbon(pts: PackedVector3Array, radius: float) -> GNData:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(pts.size() - 1):
		var forward := (pts[i + 1] - pts[i]).normalized()
		var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
		var right := forward.cross(up).normalized()

		var a := pts[i] - right * radius
		var b := pts[i] + right * radius
		var c := pts[i + 1] + right * radius
		var d := pts[i + 1] - right * radius

		var n := (c - a).cross(b - a).normalized()
		st.set_normal(n)
		st.add_vertex(a)
		st.set_normal(n)
		st.add_vertex(b)
		st.set_normal(n)
		st.add_vertex(c)
		st.set_normal(n)
		st.add_vertex(a)
		st.set_normal(n)
		st.add_vertex(c)
		st.set_normal(n)
		st.add_vertex(d)

	var out_geo := _prepare_geo()
	out_geo.set_from_surface_tool(st)
	return out_geo
