class_name PeakSOPNative
extends GNSopBase
## Native-accelerated vertex displacement along normals — delegates to GNNativePeakSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "peak"
	if ClassDB.class_exists("GNNativePeakSop"):
		_processor = ClassDB.instantiate("GNNativePeakSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Displaced geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("distance", 0.1, -100.0, 100.0, 0.01,
		"Distance", "Displacement distance along normals"))
	add_parameter(GNParameter.create_bool("recompute_normals", true, "",
		"Recompute normals after displacement"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = _require_input_geo(inputs)
	if in_geo == null:
		return null

	var dist: float = get_param_value("distance")
	var recompute: bool = get_param_value("recompute_normals")

	var out := _prepare_geo()
	var new_mesh := ArrayMesh.new()

	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)

		if arrays[Mesh.ARRAY_VERTEX] == null:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()

		if _processor:
			arrays[Mesh.ARRAY_VERTEX] = _processor.process(verts, normals, dist)
		else:
			var new_verts := PackedVector3Array()
			new_verts.resize(verts.size())
			for i in range(verts.size()):
				var n: Vector3 = normals[i] if i < normals.size() else Vector3.UP
				new_verts[i] = verts[i] + n * dist
			arrays[Mesh.ARRAY_VERTEX] = new_verts

		if recompute and prim == Mesh.PRIMITIVE_TRIANGLES:
			var st := SurfaceTool.new()
			st.begin(prim)
			_feed_st(st, arrays)
			st.generate_normals()
			st.generate_tangents()
			st.commit(new_mesh)
		else:
			new_mesh.add_surface_from_arrays(prim, arrays)

	out.set_mesh(new_mesh)
	return out


func _feed_st(st: SurfaceTool, arrays: Array) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()

	for i in range(verts.size()):
		if i < uvs.size():
			st.set_uv(uvs[i])
		st.add_vertex(verts[i])
	for idx: int in indices:
		st.add_index(idx)
