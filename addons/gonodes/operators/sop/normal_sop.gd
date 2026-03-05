class_name NormalSOP
extends GNSopBase
## Recomputes vertex normals for input geometry.
## Leverages Godot's SurfaceTool.generate_normals() for robust normal generation.
## Can also flip normals or compute flat (faceted) normals.


func _init() -> void:
	node_type = "normal"
	node_description = "Recompute, flip, or facet vertex normals."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Geometry with new normals")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Recompute (Smooth)", "Flip", "Flat (Faceted)"]),
		0, "", "Normal computation mode"))
	add_parameter(GNParameter.create_bool("generate_tangents", true, "",
		"Also generate tangents (needed for normal mapping)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = _require_input_geo(inputs)
	if in_geo == null:
		return null

	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var mode: int = get_param_value("mode")
	var do_tangents: bool = get_param_value("generate_tangents")

	var new_mesh := ArrayMesh.new()

	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)

		match mode:
			0:  # Recompute Smooth — use SurfaceTool
				if prim == Mesh.PRIMITIVE_TRIANGLES:
					var st := SurfaceTool.new()
					st.begin(prim)
					_feed_surface_tool(st, arrays)
					st.generate_normals()
					if do_tangents:
						st.generate_tangents()
					st.commit(new_mesh)
				else:
					new_mesh.add_surface_from_arrays(prim, arrays)

			1:  # Flip
				if arrays[Mesh.ARRAY_NORMAL] != null:
					var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
					var flipped := PackedVector3Array()
					flipped.resize(normals.size())
					for i in range(normals.size()):
						flipped[i] = -normals[i]
					arrays[Mesh.ARRAY_NORMAL] = flipped
				new_mesh.add_surface_from_arrays(prim, arrays)

			2:  # Flat (Faceted) — unshare vertices so each face has its own normals
				if prim == Mesh.PRIMITIVE_TRIANGLES:
					_make_flat(arrays, new_mesh)
				else:
					new_mesh.add_surface_from_arrays(prim, arrays)

	_cached_geo.set_mesh(new_mesh)
	return _cached_geo


func _feed_surface_tool(st: SurfaceTool, arrays: Array) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()

	if indices.is_empty():
		for i in range(verts.size()):
			if i < uvs.size():
				st.set_uv(uvs[i])
			st.add_vertex(verts[i])
	else:
		for i in range(verts.size()):
			if i < uvs.size():
				st.set_uv(uvs[i])
			st.add_vertex(verts[i])
		for idx in indices:
			st.add_index(idx)


func _make_flat(arrays: Array, out_mesh: ArrayMesh) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()

	if indices.is_empty():
		indices.resize(verts.size())
		for i in range(verts.size()):
			indices[i] = i

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for tri in range(indices.size() / 3):
		var i0: int = indices[tri * 3]
		var i1: int = indices[tri * 3 + 1]
		var i2: int = indices[tri * 3 + 2]
		var v0: Vector3 = verts[i0]
		var v1: Vector3 = verts[i1]
		var v2: Vector3 = verts[i2]

		var face_normal: Vector3 = (v1 - v0).cross(v2 - v0).normalized()

		for vi in [i0, i1, i2]:
			st.set_normal(face_normal)
			if vi < uvs.size():
				st.set_uv(uvs[vi])
			st.add_vertex(verts[vi])

	st.generate_tangents()
	st.commit(out_mesh)
