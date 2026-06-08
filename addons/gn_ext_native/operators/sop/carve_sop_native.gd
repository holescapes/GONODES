class_name CarveSOPNative
extends GNSopBase
## Native-accelerated carve/trim — delegates to GNNativeCarveSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "carve_native"
	node_description = "Trim triangles by parametric U range — native C++ accelerated."
	if ClassDB.class_exists("GNNativeCarveSop"):
		_processor = ClassDB.instantiate("GNNativeCarveSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry", "In")
	add_output("out", GNFamily.Type.SOP, "Carved geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("first_u", 0.0, 0.0, 1.0, 0.01, "First U", ""))
	add_parameter(GNParameter.create_float("second_u", 1.0, 0.0, 1.0, 0.01, "Second U", ""))
	add_parameter(GNParameter.create_bool("extract", true, "Extract", "Keep range (true) or remove it"))
	add_parameter(GNParameter.create_bool("use_uvs", false, "Use UVs", "Use UV coordinates for range"))
	add_parameter(GNParameter.create_bool("use_position", false, "Use Position", "Use position axis"))
	add_parameter(GNParameter.create_enum("axis", PackedStringArray(["X", "Y", "Z"]), 0, "Axis", ""))


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

		var result: Dictionary = _processor.process(verts, normals, uvs, indices,
			get_param_value("first_u"), get_param_value("second_u"),
			get_param_value("extract"), get_param_value("use_uvs"),
			get_param_value("use_position"), get_param_value("axis"))

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
