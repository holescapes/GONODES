class_name RemeshSOPNative
extends GNSopBase
## Native-accelerated edge-length remeshing — delegates to GNNativeRemeshSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "remesh"
	node_description = "Adaptive remeshing by edge-length subdivision — native C++ accelerated."
	if ClassDB.class_exists("GNNativeRemeshSop"):
		_processor = ClassDB.instantiate("GNNativeRemeshSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Remeshed geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("target_edge", 0.1, 0.001, 100.0, 0.001,
		"Target Edge Length", "Edges longer than this are split"))
	add_parameter(GNParameter.create_int("iterations", 3, 1, 10,
		"Iterations", "Number of remeshing passes"))
	add_parameter(GNParameter.create_bool("smooth", true, "Smooth",
		"Apply smoothing pass after subdivision"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = _get_input_sop(inputs, 0)
	if in_geo == null or not in_geo.has_geometry():
		return null

	var positions := PackedVector3Array()
	var indices := PackedInt32Array()
	for s in range(in_geo.get_surface_count()):
		var arrays: Array = in_geo.get_surface_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			positions = arrays[Mesh.ARRAY_VERTEX]
			if arrays[Mesh.ARRAY_INDEX] != null:
				indices = arrays[Mesh.ARRAY_INDEX]
			break

	if positions.is_empty() or not _processor:
		return null

	var result: Dictionary = _processor.process(positions, indices,
		get_param_value("target_edge"), get_param_value("iterations"),
		get_param_value("smooth"))

	var out_pos: PackedVector3Array = result.get("positions", PackedVector3Array())
	var out_idx: PackedInt32Array = result.get("indices", PackedInt32Array())
	if out_pos.is_empty():
		return null

	var out := _prepare_geo()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(out_pos.size()):
		st.add_vertex(out_pos[i])
	for idx in out_idx:
		st.add_index(idx)
	st.generate_normals()
	st.generate_tangents()
	out.set_from_surface_tool(st)
	return out
