class_name ExtrudeSOP
extends GNSopBase
## Extrudes each triangle face along its normal by a configurable distance.
## Per-triangle extrusion — each face is independently pushed outward,
## creating a faceted extrusion effect.


func _init() -> void:
	node_type = "extrude"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Extruded geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("distance", 0.2, -10.0, 10.0, 0.01,
		"Distance", "Extrusion distance along face normals"))
	add_parameter(GNParameter.create_bool("output_sides", true, "",
		"Generate side walls between original and extruded faces"))
	add_parameter(GNParameter.create_bool("output_front", true, "",
		"Output the extruded (front) face"))
	add_parameter(GNParameter.create_bool("output_back", false, "",
		"Output the original (back) face"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = _require_input_geo(inputs)
	if in_geo == null:
		return null

	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var dist: float = get_param_value("distance")
	var do_sides: bool = get_param_value("output_sides")
	var do_front: bool = get_param_value("output_front")
	var do_back: bool = get_param_value("output_back")

	var new_mesh := ArrayMesh.new()

	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)

		if prim != Mesh.PRIMITIVE_TRIANGLES or arrays[Mesh.ARRAY_VERTEX] == null:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		_extrude_surface(arrays, new_mesh, dist, do_front, do_back, do_sides)

	_cached_geo.set_mesh(new_mesh)
	return _cached_geo


func _extrude_surface(arrays: Array, out_mesh: ArrayMesh, dist: float,
		do_front: bool, do_back: bool, do_sides: bool) -> void:
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

		var face_n: Vector3 = (v1 - v0).cross(v2 - v0).normalized()
		var offset: Vector3 = face_n * dist

		var e0: Vector3 = v0 + offset
		var e1: Vector3 = v1 + offset
		var e2: Vector3 = v2 + offset

		var uv0: Vector2 = uvs[i0] if i0 < uvs.size() else Vector2.ZERO
		var uv1: Vector2 = uvs[i1] if i1 < uvs.size() else Vector2.ZERO
		var uv2: Vector2 = uvs[i2] if i2 < uvs.size() else Vector2.ZERO

		# Front face (extruded, same winding)
		if do_front:
			st.set_normal(face_n)
			st.set_uv(uv0); st.add_vertex(e0)
			st.set_normal(face_n)
			st.set_uv(uv1); st.add_vertex(e1)
			st.set_normal(face_n)
			st.set_uv(uv2); st.add_vertex(e2)

		# Back face (original position, reversed winding)
		if do_back:
			var back_n: Vector3 = -face_n
			st.set_normal(back_n)
			st.set_uv(uv0); st.add_vertex(v0)
			st.set_normal(back_n)
			st.set_uv(uv2); st.add_vertex(v2)
			st.set_normal(back_n)
			st.set_uv(uv1); st.add_vertex(v1)

		# Side walls (3 quads = 6 triangles per face)
		if do_sides:
			_add_side_quad(st, v0, v1, e1, e0)
			_add_side_quad(st, v1, v2, e2, e1)
			_add_side_quad(st, v2, v0, e0, e2)

	st.generate_tangents()
	st.commit(out_mesh)


func _add_side_quad(st: SurfaceTool, a: Vector3, b: Vector3,
		c: Vector3, d: Vector3) -> void:
	var side_n: Vector3 = (b - a).cross(d - a).normalized()
	# Triangle 1: a, b, c
	st.set_normal(side_n)
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(a)
	st.set_normal(side_n)
	st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(b)
	st.set_normal(side_n)
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(c)
	# Triangle 2: a, c, d
	st.set_normal(side_n)
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(a)
	st.set_normal(side_n)
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(c)
	st.set_normal(side_n)
	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(d)
