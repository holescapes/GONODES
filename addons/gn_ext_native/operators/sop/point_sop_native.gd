class_name PointSOPNative
extends GNSopBase
## Native-accelerated per-vertex expression — delegates to GNNativePointSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "point"
	time_dependent = true
	node_description = "Per-vertex position expressions — native C++ accelerated."
	if ClassDB.class_exists("GNNativePointSop"):
		_processor = ClassDB.instantiate("GNNativePointSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Modified geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("expr_x", "px", "Position X expression", ""))
	add_parameter(GNParameter.create_string("expr_y", "py", "Position Y expression", ""))
	add_parameter(GNParameter.create_string("expr_z", "pz", "Position Z expression", ""))
	add_parameter(GNParameter.create_bool("recompute_normals", true, "", "Recompute normals"))


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
		if verts.is_empty() or not _processor:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] else PackedVector3Array()
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] else PackedVector2Array()

		var result: Dictionary = _processor.process(verts, normals, uvs,
			get_param_value("expr_x"), get_param_value("expr_y"),
			get_param_value("expr_z"), elapsed_time)

		arrays[Mesh.ARRAY_VERTEX] = result.get("positions", verts)
		if get_param_value("recompute_normals") and prim == Mesh.PRIMITIVE_TRIANGLES:
			var st := SurfaceTool.new()
			st.begin(prim)
			for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
				if arrays[Mesh.ARRAY_TEX_UV] and i < arrays[Mesh.ARRAY_TEX_UV].size():
					st.set_uv(arrays[Mesh.ARRAY_TEX_UV][i])
				st.add_vertex(arrays[Mesh.ARRAY_VERTEX][i])
			if arrays[Mesh.ARRAY_INDEX]:
				for idx in arrays[Mesh.ARRAY_INDEX]:
					st.add_index(idx)
			st.generate_normals()
			new_mesh = st.commit(new_mesh)
		else:
			new_mesh.add_surface_from_arrays(prim, arrays)

	geo.set_mesh(new_mesh)
	return geo
