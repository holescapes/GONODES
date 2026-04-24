class_name PolySplineSOPNative
extends GNSopBase
## Native-accelerated spline generation — delegates to GNNativePolySplineSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "polyspline_native"
	if ClassDB.class_exists("GNNativePolySplineSop"):
		_processor = ClassDB.instantiate("GNNativePolySplineSop")


func _init_ports() -> void:
	add_input("pts", GNFamily.Type.SOP, false, "Control points")
	add_output("out", GNFamily.Type.SOP, "Spline geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("subdivisions", 8, 1, 128,
		"Subdivisions", "Segments between control points"))
	add_parameter(GNParameter.create_bool("closed", false, "Closed", "Close the spline"))
	add_parameter(GNParameter.create_bool("tube", false, "Tube", "Generate tube mesh"))
	add_parameter(GNParameter.create_float("radius", 0.1, 0.001, 10.0, 0.01,
		"Radius", "Tube radius"))
	add_parameter(GNParameter.create_int("sides", 8, 3, 64,
		"Sides", "Tube cross-section sides"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo := _get_input_sop(inputs, 0)
	if in_geo == null or not in_geo.has_geometry():
		return null

	var subdivs: int = get_param_value("subdivisions")
	var closed: bool = get_param_value("closed")
	var do_tube: bool = get_param_value("tube")
	var radius: float = get_param_value("radius")
	var sides: int = get_param_value("sides")

	# Extract control points
	var pts := PackedVector3Array()
	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			pts.append_array(arrays[Mesh.ARRAY_VERTEX])

	if pts.size() < 2 or _processor == null:
		return null

	var geo := _prepare_geo()
	var spine: PackedVector3Array = _processor.eval_spline(pts, subdivs, closed)

	if do_tube:
		var result: Dictionary = _processor.build_tube(spine, radius, sides, closed)
		var mesh := ArrayMesh.new()
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = result.get("vertices", PackedVector3Array())
		arrays[Mesh.ARRAY_NORMAL] = result.get("normals", PackedVector3Array())
		arrays[Mesh.ARRAY_TEX_UV] = result.get("uvs", PackedVector2Array())
		arrays[Mesh.ARRAY_INDEX] = result.get("indices", PackedInt32Array())
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		geo.set_mesh(mesh)
	else:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_LINE_STRIP)
		for pt in spine:
			st.add_vertex(pt)
		var mesh := ArrayMesh.new()
		st.commit(mesh)
		geo.set_mesh(mesh)

	return geo
