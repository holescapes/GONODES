class_name ConvertLineSOP
extends GNSopBase
## Converts line geometry between polyline, bezier, and subdivision types.
## Can resample curves to different segment counts and smoothing levels.


func _init() -> void:
	node_type = "convertline"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input line geometry")
	add_output("out", GNFamily.Type.SOP, "Converted line geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("target",
		PackedStringArray(["Polyline", "Bezier (Cubic)", "Subdivision"]), 0,
		"Target Type", "Output line type"))
	add_parameter(GNParameter.create_int("segments", 16, 2, 256,
		"Segments", "Number of output segments per span"))
	add_parameter(GNParameter.create_float("tension", 0.5, 0.0, 1.0, 0.01,
		"Tension", "Curve tension for bezier/subdivision conversion"))
	add_parameter(GNParameter.create_bool("closed", false,
		"Close", "Close the curve into a loop"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo := _require_input_geo(inputs)
	if in_geo == null:
		return null

	var target: int = get_param_value("target")
	var segments: int = get_param_value("segments")
	var tension: float = get_param_value("tension")
	var do_close: bool = get_param_value("closed")

	var geo := _prepare_geo()

	# Extract input points from all line surfaces
	var input_pts := PackedVector3Array()
	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if verts != null:
			input_pts.append_array(verts)

	if input_pts.size() < 2:
		return null

	var output_pts: PackedVector3Array

	match target:
		0: # Polyline — just pass through with optional close
			output_pts = input_pts.duplicate()
			if do_close and output_pts.size() > 2:
				output_pts.append(output_pts[0])

		1: # Bezier (Cubic)
			output_pts = _to_bezier(input_pts, segments, tension, do_close)

		2: # Subdivision (Chaikin)
			output_pts = _to_subdivision(input_pts, segments, do_close)

		_:
			output_pts = input_pts.duplicate()

	# Build line mesh from output points
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINE_STRIP)
	for pt in output_pts:
		st.add_vertex(pt)
	var new_mesh := ArrayMesh.new()
	st.commit(new_mesh)
	geo.set_mesh(new_mesh)
	return geo


func _to_bezier(pts: PackedVector3Array, segs: int, tension: float, closed: bool) -> PackedVector3Array:
	var result := PackedVector3Array()
	var n: int = pts.size()
	if n < 2:
		return pts

	var points := pts.duplicate()
	if closed and n > 2:
		points.append(pts[0])
		points.append(pts[1])

	var total_spans: int = points.size() - 1
	for span in range(total_spans):
		var p0: Vector3 = points[maxi(span - 1, 0)]
		var p1: Vector3 = points[span]
		var p2: Vector3 = points[mini(span + 1, points.size() - 1)]
		var p3: Vector3 = points[mini(span + 2, points.size() - 1)]

		for s in range(segs):
			var t: float = float(s) / float(segs)
			result.append(_catmull_rom(p0, p1, p2, p3, t, tension))

	result.append(points[points.size() - 1])
	return result


func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float, tension: float) -> Vector3:
	var t2: float = t * t
	var t3: float = t2 * t
	var s: float = (1.0 - tension) * 0.5
	var b0: float = -s * t3 + 2.0 * s * t2 - s * t
	var b1: float = (2.0 - s) * t3 + (s - 3.0) * t2 + 1.0
	var b2: float = (s - 2.0) * t3 + (3.0 - 2.0 * s) * t2 + s * t
	var b3: float = s * t3 - s * t2
	return p0 * b0 + p1 * b1 + p2 * b2 + p3 * b3


func _to_subdivision(pts: PackedVector3Array, segs: int, closed: bool) -> PackedVector3Array:
	# Chaikin subdivision
	var points := pts.duplicate()
	if closed and points.size() > 2:
		points.append(pts[0])

	var iterations: int = clampi(int(log(float(segs)) / log(2.0)), 1, 8)
	for _iter in range(iterations):
		var new_pts := PackedVector3Array()
		for i in range(points.size() - 1):
			var q: Vector3 = points[i] * 0.75 + points[i + 1] * 0.25
			var r: Vector3 = points[i] * 0.25 + points[i + 1] * 0.75
			new_pts.append(q)
			new_pts.append(r)
		if closed and new_pts.size() > 1:
			new_pts.append(new_pts[0])
		points = new_pts

	return points
