class_name SortSOPNative
extends GNSopBase
## Native-accelerated vertex sort — delegates to GNNativeSortSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "sort"
	node_description = "Sort vertices by axis, distance, or randomly — native C++ accelerated."
	if ClassDB.class_exists("GNNativeSortSop"):
		_processor = ClassDB.instantiate("GNNativeSortSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Sorted geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("method",
		PackedStringArray(["Along X", "Along Y", "Along Z", "Distance from Point", "Random", "Reverse"]),
		0, "", "Sort method"))
	add_parameter(GNParameter.create_float("px", 0.0, null, null, 0.01, "Point X", ""))
	add_parameter(GNParameter.create_float("py", 0.0, null, null, 0.01, "Point Y", ""))
	add_parameter(GNParameter.create_float("pz", 0.0, null, null, 0.01, "Point Z", ""))
	add_parameter(GNParameter.create_int("seed", 0, 0, 9999, "Seed", ""))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = inputs[0] as GNGeoData if inputs.size() > 0 and inputs[0] is GNGeoData else null
	if in_geo == null or not in_geo.has_geometry():
		return null

	var geo := _prepare_geo()
	var new_mesh := ArrayMesh.new()
	var method: int = get_param_value("method")
	var ref_pt := Vector3(get_param_value("px"), get_param_value("py"), get_param_value("pz"))
	var seed_val: int = get_param_value("seed")

	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] if arrays[Mesh.ARRAY_VERTEX] else PackedVector3Array()
		if verts.is_empty() or not _processor:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] else PackedVector3Array()
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] else PackedVector2Array()
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] else PackedFloat32Array()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] else PackedInt32Array()

		var result: Dictionary = _processor.process(verts, normals, uvs, tangents, indices,
			method, ref_pt, seed_val)
		arrays[Mesh.ARRAY_VERTEX] = result.get("positions", verts)
		if result.has("normals"): arrays[Mesh.ARRAY_NORMAL] = result["normals"]
		if result.has("uvs"): arrays[Mesh.ARRAY_TEX_UV] = result["uvs"]
		if result.has("tangents"): arrays[Mesh.ARRAY_TANGENT] = result["tangents"]
		if result.has("indices"): arrays[Mesh.ARRAY_INDEX] = result["indices"]
		new_mesh.add_surface_from_arrays(prim, arrays)

	geo.set_mesh(new_mesh)
	return geo
