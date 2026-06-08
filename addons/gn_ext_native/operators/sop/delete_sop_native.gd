class_name DeleteSOPNative
extends GNSopBase
## Native-accelerated delete — delegates to GNNativeDeleteSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "delete_native"
	node_description = "Delete triangles by range, bounding box, or random — native C++ accelerated."
	if ClassDB.class_exists("GNNativeDeleteSop"):
		_processor = ClassDB.instantiate("GNNativeDeleteSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry", "In")
	add_output("out", GNFamily.Type.SOP, "Reduced geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("method",
		PackedStringArray(["Range", "Bounding Box", "Random %"]), 0, "Method", ""))
	add_parameter(GNParameter.create_int("start", 0, 0, 100000, "Start", ""))
	add_parameter(GNParameter.create_int("end", 10, 0, 100000, "End", ""))
	add_parameter(GNParameter.create_float("bmin_x", -1.0, null, null, 0.1, "BBox Min X", ""))
	add_parameter(GNParameter.create_float("bmin_y", -1.0, null, null, 0.1, "BBox Min Y", ""))
	add_parameter(GNParameter.create_float("bmin_z", -1.0, null, null, 0.1, "BBox Min Z", ""))
	add_parameter(GNParameter.create_float("bmax_x", 1.0, null, null, 0.1, "BBox Max X", ""))
	add_parameter(GNParameter.create_float("bmax_y", 1.0, null, null, 0.1, "BBox Max Y", ""))
	add_parameter(GNParameter.create_float("bmax_z", 1.0, null, null, 0.1, "BBox Max Z", ""))
	add_parameter(GNParameter.create_float("percent", 0.5, 0.0, 1.0, 0.01, "Percent", ""))
	add_parameter(GNParameter.create_int("seed", 0, 0, 9999, "Seed", ""))
	add_parameter(GNParameter.create_bool("invert", false, "Invert", ""))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = inputs[0] as GNGeoData if inputs.size() > 0 and inputs[0] is GNGeoData else null
	if in_geo == null or not in_geo.has_geometry():
		return null

	var geo := _prepare_geo()
	var new_mesh := ArrayMesh.new()

	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] if arrays[Mesh.ARRAY_VERTEX] else PackedVector3Array()
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] else PackedVector3Array()
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] else PackedVector2Array()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] else PackedInt32Array()

		if verts.is_empty() or not _processor or indices.is_empty():
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		var bmin := Vector3(get_param_value("bmin_x"), get_param_value("bmin_y"), get_param_value("bmin_z"))
		var bmax := Vector3(get_param_value("bmax_x"), get_param_value("bmax_y"), get_param_value("bmax_z"))
		var result: Dictionary = _processor.process(verts, normals, uvs, indices,
			get_param_value("method"), get_param_value("start"), get_param_value("end"),
			bmin, bmax, get_param_value("percent"), get_param_value("seed"),
			get_param_value("invert"))

		var out_v: PackedVector3Array = result.get("positions", PackedVector3Array())
		if out_v.is_empty():
			continue
		var out_arr: Array = []
		out_arr.resize(Mesh.ARRAY_MAX)
		out_arr[Mesh.ARRAY_VERTEX] = out_v
		if result.has("normals") and not result["normals"].is_empty():
			out_arr[Mesh.ARRAY_NORMAL] = result["normals"]
		if result.has("uvs") and not result["uvs"].is_empty():
			out_arr[Mesh.ARRAY_TEX_UV] = result["uvs"]
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out_arr)

	geo.set_mesh(new_mesh)
	return geo
