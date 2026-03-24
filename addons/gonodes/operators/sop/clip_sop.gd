class_name ClipSOP
extends GNSopBase
## Clips geometry against a plane, keeping one side and clipping triangles
## that straddle the boundary.  Produces watertight cuts.


func _init() -> void:
	node_type = "clip"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Clipped geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("plane",
		PackedStringArray(["X", "Y", "Z"]), 1, "", "Clip plane normal axis"))
	add_parameter(GNParameter.create_float("origin", 0.0, null, null, 0.01,
		"Origin", "Plane offset along axis"))
	add_parameter(GNParameter.create_bool("keep_above", true, "",
		"Keep geometry above the plane (true) or below (false)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = _require_input_geo(inputs)
	if in_geo == null:
		return null

	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var axis: int = get_param_value("plane")
	var origin: float = get_param_value("origin")
	var keep_above: bool = get_param_value("keep_above")

	var normal: Vector3
	match axis:
		0: normal = Vector3.RIGHT
		1: normal = Vector3.UP
		_: normal = Vector3.BACK

	if not keep_above:
		normal = -normal
		origin = -origin

	var new_mesh := ArrayMesh.new()

	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)

		if prim != Mesh.PRIMITIVE_TRIANGLES or arrays[Mesh.ARRAY_VERTEX] == null:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		_clip_surface(arrays, new_mesh, normal, origin)

	_cached_geo.set_mesh(new_mesh)
	return _cached_geo


func _clip_surface(arrays: Array, out_mesh: ArrayMesh, normal: Vector3, origin: float) -> void:
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
		var idx: Array[int] = [indices[tri * 3], indices[tri * 3 + 1], indices[tri * 3 + 2]]
		var v: Array[Vector3] = [verts[idx[0]], verts[idx[1]], verts[idx[2]]]
		var uv: Array[Vector2] = []
		for k in range(3):
			uv.append(uvs[idx[k]] if idx[k] < uvs.size() else Vector2.ZERO)

		# Signed distances from plane
		var dist: Array[float] = []
		for k in range(3):
			dist.append(v[k].dot(normal) - origin)

		# Count how many vertices are above (≥0)
		var above: int = 0
		for d in dist:
			if d >= 0.0:
				above += 1

		if above == 3:
			# Fully above — keep entire triangle
			_add_tri_to_st(st, v, uv)
		elif above == 0:
			# Fully below — discard
			continue
		else:
			# Partially clipped — split triangle
			_clip_triangle(st, v, uv, dist)

	st.generate_normals()
	st.generate_tangents()
	st.commit(out_mesh)


func _clip_triangle(st: SurfaceTool, v: Array[Vector3], uv: Array[Vector2],
		dist: Array[float]) -> void:
	# Sort so that the lone vertex is at index 0
	# If 2 above: lone is below → we output a quad (2 tris) on the above side
	# If 1 above: lone is above → we output a single triangle

	var above_indices: Array[int] = []
	var below_indices: Array[int] = []
	for i in range(3):
		if dist[i] >= 0.0:
			above_indices.append(i)
		else:
			below_indices.append(i)

	if above_indices.size() == 2:
		# Two above, one below → output quad on above side
		var b: int = below_indices[0]
		var a0: int = above_indices[0]
		var a1: int = above_indices[1]

		var t0: float = dist[a0] / (dist[a0] - dist[b])
		var t1: float = dist[a1] / (dist[a1] - dist[b])

		var clip0: Vector3 = v[a0].lerp(v[b], t0)
		var clip1: Vector3 = v[a1].lerp(v[b], t1)
		var uv_clip0: Vector2 = uv[a0].lerp(uv[b], t0)
		var uv_clip1: Vector2 = uv[a1].lerp(uv[b], t1)

		_add_tri_to_st(st, [v[a0], v[a1], clip1], [uv[a0], uv[a1], uv_clip1])
		_add_tri_to_st(st, [v[a0], clip1, clip0], [uv[a0], uv_clip1, uv_clip0])

	elif above_indices.size() == 1:
		# One above, two below → output single triangle
		var a: int = above_indices[0]
		var b0: int = below_indices[0]
		var b1: int = below_indices[1]

		var t0: float = dist[a] / (dist[a] - dist[b0])
		var t1: float = dist[a] / (dist[a] - dist[b1])

		var clip0: Vector3 = v[a].lerp(v[b0], t0)
		var clip1: Vector3 = v[a].lerp(v[b1], t1)
		var uv_clip0: Vector2 = uv[a].lerp(uv[b0], t0)
		var uv_clip1: Vector2 = uv[a].lerp(uv[b1], t1)

		_add_tri_to_st(st, [v[a], clip0, clip1], [uv[a], uv_clip0, uv_clip1])


func _add_tri_to_st(st: SurfaceTool, v: Array, uv: Array) -> void:
	for i in range(3):
		st.set_uv(uv[i] as Vector2)
		st.add_vertex(v[i] as Vector3)
