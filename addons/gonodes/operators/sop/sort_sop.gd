class_name SortSOP
extends GNSopBase
## Sorts vertices by position along an axis, by distance from a point, or randomly.
## Works on the vertex array directly — reindexes all associated attributes.


func _init() -> void:
	node_type = "sort"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Sorted geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("method",
		PackedStringArray(["Along X", "Along Y", "Along Z", "Distance from Point", "Random", "Reverse"]),
		0, "", "Sort method"))
	add_parameter(GNParameter.create_float("px", 0.0, null, null, 0.01, "Point X", "Reference point X"))
	add_parameter(GNParameter.create_float("py", 0.0, null, null, 0.01, "Point Y", "Reference point Y"))
	add_parameter(GNParameter.create_float("pz", 0.0, null, null, 0.01, "Point Z", "Reference point Z"))
	add_parameter(GNParameter.create_int("seed", 0, 0, 9999, "Seed", "Random seed"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = _require_input_geo(inputs)
	if in_geo == null:
		return null

	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var method: int = get_param_value("method")
	var ref_pt := Vector3(get_param_value("px"), get_param_value("py"), get_param_value("pz"))
	var seed_val: int = get_param_value("seed")

	var new_mesh := ArrayMesh.new()

	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)

		if arrays[Mesh.ARRAY_VERTEX] == null:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n: int = verts.size()

		# Build index mapping
		var order: Array[int] = []
		order.resize(n)
		for i in range(n):
			order[i] = i

		match method:
			0:  # Along X
				order.sort_custom(func(a: int, b: int) -> bool: return verts[a].x < verts[b].x)
			1:  # Along Y
				order.sort_custom(func(a: int, b: int) -> bool: return verts[a].y < verts[b].y)
			2:  # Along Z
				order.sort_custom(func(a: int, b: int) -> bool: return verts[a].z < verts[b].z)
			3:  # Distance from Point
				order.sort_custom(func(a: int, b: int) -> bool:
					return verts[a].distance_squared_to(ref_pt) < verts[b].distance_squared_to(ref_pt))
			4:  # Random (Fisher-Yates)
				var rng := RandomNumberGenerator.new()
				rng.seed = seed_val
				for i in range(n - 1, 0, -1):
					var j: int = rng.randi_range(0, i)
					var tmp: int = order[i]
					order[i] = order[j]
					order[j] = tmp
			5:  # Reverse
				order.reverse()

		# Remap arrays
		var out_arrays := _remap_arrays(arrays, order)
		new_mesh.add_surface_from_arrays(prim, out_arrays)

	_cached_geo.set_mesh(new_mesh)
	return _cached_geo


func _remap_arrays(arrays: Array, order: Array[int]) -> Array:
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	var n: int = order.size()

	# Build inverse mapping for index rewriting
	var inverse: PackedInt32Array = PackedInt32Array()
	inverse.resize(n)
	for new_i in range(n):
		inverse[order[new_i]] = new_i

	# Remap vertex positions
	if arrays[Mesh.ARRAY_VERTEX] != null:
		var src: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var dst := PackedVector3Array()
		dst.resize(n)
		for i in range(n):
			dst[i] = src[order[i]]
		out[Mesh.ARRAY_VERTEX] = dst

	# Remap normals
	if arrays[Mesh.ARRAY_NORMAL] != null:
		var src: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var dst := PackedVector3Array()
		dst.resize(n)
		for i in range(n):
			dst[i] = src[order[i]]
		out[Mesh.ARRAY_NORMAL] = dst

	# Remap UVs
	if arrays[Mesh.ARRAY_TEX_UV] != null:
		var src: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var dst := PackedVector2Array()
		dst.resize(n)
		for i in range(n):
			dst[i] = src[order[i]]
		out[Mesh.ARRAY_TEX_UV] = dst

	# Remap tangents
	if arrays[Mesh.ARRAY_TANGENT] != null:
		var src: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var dst := PackedFloat32Array()
		dst.resize(n * 4)
		for i in range(n):
			var si: int = order[i] * 4
			var di: int = i * 4
			dst[di] = src[si]; dst[di + 1] = src[si + 1]
			dst[di + 2] = src[si + 2]; dst[di + 3] = src[si + 3]
		out[Mesh.ARRAY_TANGENT] = dst

	# Remap indices using inverse map
	if arrays[Mesh.ARRAY_INDEX] != null:
		var src: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var dst := PackedInt32Array()
		dst.resize(src.size())
		for i in range(src.size()):
			dst[i] = inverse[src[i]]
		out[Mesh.ARRAY_INDEX] = dst

	return out
