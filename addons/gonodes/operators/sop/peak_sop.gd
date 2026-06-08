class_name PeakSOP
extends GNSopBase
## Pushes vertices along their normals by a uniform distance.
## Simple but effective for inflation, outline shells, and shrink-wrap effects.


func _init() -> void:
	node_type = "peak"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry", "In")
	add_output("out", GNFamily.Type.SOP, "Displaced geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("distance", 0.1, -100.0, 100.0, 0.01,
		"Distance", "Displacement distance along normals"))
	add_parameter(GNParameter.create_bool("recompute_normals", true, "Enable recompute normals",
		"Recompute normals after displacement"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = _require_input_geo(inputs)
	if in_geo == null:
		return null

	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var dist: float = get_param_value("distance")
	var recompute: bool = get_param_value("recompute_normals")

	var new_mesh := ArrayMesh.new()

	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)

		if arrays[Mesh.ARRAY_VERTEX] == null:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
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

	_cached_geo.set_mesh(new_mesh)
	return _cached_geo


func _feed_st(st: SurfaceTool, arrays: Array) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()

	for i in range(verts.size()):
		if i < uvs.size():
			st.set_uv(uvs[i])
		st.add_vertex(verts[i])
	for idx in indices:
		st.add_index(idx)
