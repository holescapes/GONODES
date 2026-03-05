class_name ScatterSOP
extends GNSopBase
## Scatters random points on the surface of input geometry.
## Uses weighted random triangle sampling for uniform distribution.
## Outputs a point cloud (PRIMITIVE_POINTS).


func _init() -> void:
	node_type = "scatter"
	node_description = "Scatter random points on mesh surface."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Scattered points")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("count", 100, 1, 100000, "Point Count",
		"Number of points to scatter"))
	add_parameter(GNParameter.create_int("seed", 42, 0, 99999, "Seed", "Random seed"))
	add_parameter(GNParameter.create_bool("emit_normals", true, "",
		"Interpolate and emit normals at scattered points"))
	add_parameter(GNParameter.create_bool("emit_uvs", true, "",
		"Interpolate and emit UVs at scattered points"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = _require_input_geo(inputs)
	if in_geo == null:
		return null

	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var count: int = maxi(get_param_value("count"), 1)
	var seed_val: int = get_param_value("seed")
	var emit_n: bool = get_param_value("emit_normals")
	var emit_uv: bool = get_param_value("emit_uvs")

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	# Collect all triangles across surfaces with area-weighted CDF
	var tri_verts: Array[PackedVector3Array] = []
	var tri_normals: Array[PackedVector3Array] = []
	var tri_uvs: Array[PackedVector2Array] = []
	var areas := PackedFloat32Array()

	for s in range(in_geo.mesh.get_surface_count()):
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)
		if prim != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()

		if indices.is_empty():
			indices.resize(verts.size())
			for i in range(verts.size()):
				indices[i] = i

		for tri in range(indices.size() / 3):
			var i0: int = indices[tri * 3]
			var i1: int = indices[tri * 3 + 1]
			var i2: int = indices[tri * 3 + 2]
			var v0: Vector3 = verts[i0]
			var v1: Vector3 = verts[i1]
			var v2: Vector3 = verts[i2]

			var tv := PackedVector3Array([v0, v1, v2])
			tri_verts.append(tv)

			var tn := PackedVector3Array()
			if i0 < norms.size() and i1 < norms.size() and i2 < norms.size():
				tn = PackedVector3Array([norms[i0], norms[i1], norms[i2]])
			tri_normals.append(tn)

			var tu := PackedVector2Array()
			if i0 < uvs.size() and i1 < uvs.size() and i2 < uvs.size():
				tu = PackedVector2Array([uvs[i0], uvs[i1], uvs[i2]])
			tri_uvs.append(tu)

			var area: float = (v1 - v0).cross(v2 - v0).length() * 0.5
			areas.append(area)

	if tri_verts.is_empty():
		return null

	# Build cumulative distribution
	var cdf := PackedFloat32Array()
	cdf.resize(areas.size())
	cdf[0] = areas[0]
	for i in range(1, areas.size()):
		cdf[i] = cdf[i - 1] + areas[i]
	var total_area: float = cdf[cdf.size() - 1]
	if total_area <= 0.0:
		return null

	# Sample points
	var out_verts := PackedVector3Array()
	var out_normals := PackedVector3Array()
	var out_uvs := PackedVector2Array()

	for _p in range(count):
		var r: float = rng.randf() * total_area
		# Binary search for triangle
		var lo: int = 0
		var hi: int = cdf.size() - 1
		while lo < hi:
			var mid: int = (lo + hi) / 2
			if cdf[mid] < r:
				lo = mid + 1
			else:
				hi = mid
		var tidx: int = lo

		# Random barycentric coordinates
		var u: float = rng.randf()
		var v: float = rng.randf()
		if u + v > 1.0:
			u = 1.0 - u
			v = 1.0 - v
		var w: float = 1.0 - u - v

		var tv: PackedVector3Array = tri_verts[tidx]
		out_verts.append(tv[0] * w + tv[1] * u + tv[2] * v)

		if emit_n and tri_normals[tidx].size() == 3:
			var tn: PackedVector3Array = tri_normals[tidx]
			out_normals.append((tn[0] * w + tn[1] * u + tn[2] * v).normalized())

		if emit_uv and tri_uvs[tidx].size() == 3:
			var tu: PackedVector2Array = tri_uvs[tidx]
			out_uvs.append(tu[0] * w + tu[1] * u + tu[2] * v)

	# Build output arrays
	var out_arrays: Array = []
	out_arrays.resize(Mesh.ARRAY_MAX)
	out_arrays[Mesh.ARRAY_VERTEX] = out_verts
	if not out_normals.is_empty():
		out_arrays[Mesh.ARRAY_NORMAL] = out_normals
	if not out_uvs.is_empty():
		out_arrays[Mesh.ARRAY_TEX_UV] = out_uvs

	var new_mesh := ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, out_arrays)
	_cached_geo.set_mesh(new_mesh)
	return _cached_geo
