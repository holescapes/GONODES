class_name ScatterSOPNative
extends GNSopBase
## Native-accelerated scatter — delegates to GNNativeScatterSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "scatter"
	node_description = "Scatter random points on mesh surface — native C++ accelerated."
	if ClassDB.class_exists("GNNativeScatterSop"):
		_processor = ClassDB.instantiate("GNNativeScatterSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Scattered points")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("count", 100, 1, 100000, "Point Count", ""))
	add_parameter(GNParameter.create_int("seed", 42, 0, 99999, "Seed", ""))
	add_parameter(GNParameter.create_bool("emit_normals", true, "", "Interpolate normals"))
	add_parameter(GNParameter.create_bool("emit_uvs", true, "", "Interpolate UVs"))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo_in: GNGeoData = _get_input_sop(inputs, 0)
	if geo_in == null or not geo_in.has_geometry():
		return _prepare_geo()

	var count_val: int = get_param_value("count")
	var seed_val: int = get_param_value("seed")
	var do_normals: bool = get_param_value("emit_normals")
	var do_uvs: bool = get_param_value("emit_uvs")

	# Extract triangulated mesh data
	var all_verts := PackedVector3Array()
	var all_norms := PackedVector3Array()
	var all_uvs := PackedVector2Array()
	var all_indices := PackedInt32Array()

	for s in range(geo_in.mesh.get_surface_count()):
		var arrays: Array = geo_in.mesh.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var base: int = all_verts.size()
		all_verts.append_array(arrays[Mesh.ARRAY_VERTEX])
		if arrays[Mesh.ARRAY_NORMAL] != null:
			all_norms.append_array(arrays[Mesh.ARRAY_NORMAL])
		if arrays[Mesh.ARRAY_TEX_UV] != null:
			all_uvs.append_array(arrays[Mesh.ARRAY_TEX_UV])
		if arrays[Mesh.ARRAY_INDEX] != null:
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for i in range(idx.size()):
				all_indices.append(idx[i] + base)

	if all_verts.is_empty():
		return _prepare_geo()

	if _processor != null:
		var result: Dictionary = _processor.process(all_verts, all_norms, all_uvs,
			all_indices, count_val, seed_val, do_normals, do_uvs)

		var geo := _prepare_geo()
		var new_mesh := ArrayMesh.new()
		var out_arrays: Array = []
		out_arrays.resize(Mesh.ARRAY_MAX)
		out_arrays[Mesh.ARRAY_VERTEX] = result.get("positions", PackedVector3Array())
		if do_normals and result.has("normals"):
			out_arrays[Mesh.ARRAY_NORMAL] = result["normals"]
		if do_uvs and result.has("uvs"):
			out_arrays[Mesh.ARRAY_TEX_UV] = result["uvs"]
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, out_arrays)
		geo.set_mesh(new_mesh)
		return geo
	else:
		return _prepare_geo()
