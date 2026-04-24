class_name PolyStitchSOPNative
extends GNSopBase
## Native-accelerated polygon stitching — delegates to GNNativePolyStitchSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "polystitch_native"
	node_description = "Stitch two point sets by nearest-pair quad strips — native C++ accelerated."
	if ClassDB.class_exists("GNNativePolyStitchSop"):
		_processor = ClassDB.instantiate("GNNativePolyStitchSop")


func _init_ports() -> void:
	add_input("geo_a", GNFamily.Type.SOP, false, "First geometry")
	add_input("geo_b", GNFamily.Type.SOP, false, "Second geometry")
	add_output("out", GNFamily.Type.SOP, "Stitched geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("max_distance", 1.0, 0.0, 100.0, 0.01,
		"Max Distance", "Maximum distance for stitching pairs"))
	add_parameter(GNParameter.create_bool("include_inputs", true, "Include Inputs",
		"Include original geometry in output"))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo_a: GNGeoData = _get_input_sop(inputs, 0)
	var geo_b: GNGeoData = _get_input_sop(inputs, 1)
	if geo_a == null or geo_b == null:
		return null
	if not geo_a.has_geometry() or not geo_b.has_geometry():
		return null

	var pts_a := PackedVector3Array()
	var pts_b := PackedVector3Array()
	for s in range(geo_a.get_surface_count()):
		var arrays: Array = geo_a.get_surface_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			pts_a = arrays[Mesh.ARRAY_VERTEX]
			break
	for s in range(geo_b.get_surface_count()):
		var arrays: Array = geo_b.get_surface_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			pts_b = arrays[Mesh.ARRAY_VERTEX]
			break

	if pts_a.is_empty() or pts_b.is_empty() or not _processor:
		return null

	var result: Dictionary = _processor.process(pts_a, pts_b,
		get_param_value("max_distance"))

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
