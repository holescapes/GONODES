class_name SmoothSOPNative
extends GNSopBase
## Native-accelerated Laplacian vertex smoothing — delegates to GNNativeSmoothSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "smooth_native"
	node_description = "Laplacian vertex smoothing with border pinning — native C++ accelerated."
	if ClassDB.class_exists("GNNativeSmoothSop"):
		_processor = ClassDB.instantiate("GNNativeSmoothSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Smoothed geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("iterations", 3, 1, 100, "Iterations",
		"Number of smoothing passes"))
	add_parameter(GNParameter.create_float("strength", 0.5, 0.0, 1.0, 0.01,
		"Strength", "Blend factor per iteration"))
	add_parameter(GNParameter.create_bool("pin_borders", true, "Pin Borders",
		"Freeze boundary vertices"))


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

	var iters: int = get_param_value("iterations")
	var strength: float = get_param_value("strength")
	var pin: bool = get_param_value("pin_borders")

	var result: Dictionary = _processor.process(positions, indices, iters, strength, pin)
	var out_pos: PackedVector3Array = result.get("positions", PackedVector3Array())
	if out_pos.is_empty():
		return null

	var out := _prepare_geo()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(out_pos.size()):
		st.add_vertex(out_pos[i])
	if not indices.is_empty():
		for idx in indices:
			st.add_index(idx)
	st.generate_normals()
	st.generate_tangents()
	out.set_from_surface_tool(st)
	return out
