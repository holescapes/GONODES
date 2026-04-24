class_name PolyBevelSOPNative
extends GNSopBase
## Native-accelerated polygon bevel — delegates to GNNativePolyBevelSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "polybevel_native"
	node_description = "Vertex-pull edge bevel with rounded divisions — native C++ accelerated."
	if ClassDB.class_exists("GNNativePolyBevelSop"):
		_processor = ClassDB.instantiate("GNNativePolyBevelSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Beveled geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("offset", 0.05, 0.0, 10.0, 0.001,
		"Offset", "Bevel distance"))
	add_parameter(GNParameter.create_int("divisions", 1, 1, 8,
		"Divisions", "Bevel profile segments"))
	add_parameter(GNParameter.create_float("roundness", 0.5, 0.0, 1.0, 0.01,
		"Roundness", "Blend toward arc profile"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = _get_input_sop(inputs, 0)
	if in_geo == null or not in_geo.has_geometry():
		return null

	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for s in range(in_geo.get_surface_count()):
		var arrays: Array = in_geo.get_surface_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			positions = arrays[Mesh.ARRAY_VERTEX]
			if arrays[Mesh.ARRAY_NORMAL] != null:
				normals = arrays[Mesh.ARRAY_NORMAL]
			if arrays[Mesh.ARRAY_INDEX] != null:
				indices = arrays[Mesh.ARRAY_INDEX]
			break

	if positions.is_empty() or not _processor:
		return null

	var result: Dictionary = _processor.process(positions, normals, indices,
		get_param_value("offset"), get_param_value("divisions"),
		get_param_value("roundness"))

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
