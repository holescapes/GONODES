class_name CarveSOP
extends GNSopBase
## Carve SOP — Extracts a portion of the input mesh by trimming triangles
## along a parametric U range.
##
## Operates on the first surface of the input geometry.  Vertices are
## implicitly ordered by index; the U parameter maps linearly from the
## first vertex (U=0) to the last (U=1).  Triangles whose *centroid*
## falls outside the [First U, Second U] window are culled.
##
## Additionally supports an "Extract" toggle that inverts the selection
## (keeps the outside instead of the inside).
##
## For meshes with UV coordinates, an optional "Use UVs" mode trims based
## on the actual U texture coordinate of each triangle centroid instead of
## vertex index.
##
## Useful for reveal animations, progressive mesh construction, or slicing
## geometry into bands.

func _init() -> void:
	node_type = "carve"


func _init_ports() -> void:
	add_input("geo", GNFamily.Type.SOP, true, "Geometry to carve", "Geometry")
	add_output("out", GNFamily.Type.SOP, "Carved geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("first_u", 0.0, 0.0, 1.0, 0.001,
		"First U", "Start of kept range (0-1)"))
	add_parameter(GNParameter.create_float("second_u", 1.0, 0.0, 1.0, 0.001,
		"Second U", "End of kept range (0-1)"))
	add_parameter(GNParameter.create_bool("extract", false,
		"Extract", "Invert selection (keep outside range)"))
	add_parameter(GNParameter.create_bool("use_uvs", false,
		"Use UVs", "Use texture U coordinate instead of vertex index"))
	add_parameter(GNParameter.create_enum("axis",
		PackedStringArray(["X", "Y", "Z"]),
		1, "Axis", "Positional axis for slicing (when not using UVs or index)"))
	add_parameter(GNParameter.create_bool("use_position", false,
		"Use Position", "Carve by normalised position along axis instead of index"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = _require_input_geo(inputs)
	if in_geo == null:
		return null
	if in_geo.mesh.get_surface_count() == 0:
		return in_geo

	var first_u: float = get_param_value("first_u")
	var second_u: float = get_param_value("second_u")
	var extract: bool = get_param_value("extract")
	var use_uvs: bool = get_param_value("use_uvs")
	var use_position: bool = get_param_value("use_position")
	var axis: int = get_param_value("axis")

	# Make sure first <= second
	if first_u > second_u:
		var tmp: float = first_u
		first_u = second_u
		second_u = tmp

	var out := _prepare_geo()
	var new_mesh := ArrayMesh.new()

	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] == null:
			continue

		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs = arrays[Mesh.ARRAY_TEX_UV]
		var has_uvs: bool = uvs != null and uvs.size() == verts.size()
		var indices = arrays[Mesh.ARRAY_INDEX]
		var is_indexed: bool = indices != null and indices.size() > 0

		# Compute position bounds for positional mode
		var axis_min: float = INF
		var axis_max: float = -INF
		if use_position:
			for vi in range(verts.size()):
				var av: float = _get_axis(verts[vi], axis)
				axis_min = minf(axis_min, av)
				axis_max = maxf(axis_max, av)

		# Build new triangle list
		var new_verts := PackedVector3Array()
		var new_normals := PackedVector3Array()
		var new_uvs := PackedVector2Array() if has_uvs else null
		var old_normals = arrays[Mesh.ARRAY_NORMAL]
		var has_normals: bool = old_normals != null and old_normals.size() == verts.size()

		var tri_count: int
		if is_indexed:
			tri_count = indices.size() / 3
		else:
			tri_count = verts.size() / 3

		var total_tris: int = tri_count

		for ti in range(tri_count):
			var i0: int
			var i1: int
			var i2: int
			if is_indexed:
				i0 = indices[ti * 3]
				i1 = indices[ti * 3 + 1]
				i2 = indices[ti * 3 + 2]
			else:
				i0 = ti * 3
				i1 = ti * 3 + 1
				i2 = ti * 3 + 2

			# Compute centroid parameter
			var u_val: float
			if use_uvs and has_uvs:
				u_val = (uvs[i0].x + uvs[i1].x + uvs[i2].x) / 3.0
			elif use_position:
				var centroid: Vector3 = (verts[i0] + verts[i1] + verts[i2]) / 3.0
				var av: float = _get_axis(centroid, axis)
				var range_len: float = axis_max - axis_min
				if range_len > 0.0001:
					u_val = (av - axis_min) / range_len
				else:
					u_val = 0.5
			else:
				# Index-based: centroid index normalised
				var centroid_idx: float = float(i0 + i1 + i2) / 3.0
				u_val = centroid_idx / maxf(float(verts.size() - 1), 1.0)

			var inside: bool = u_val >= first_u and u_val <= second_u
			if extract:
				inside = not inside

			if inside:
				new_verts.append(verts[i0])
				new_verts.append(verts[i1])
				new_verts.append(verts[i2])
				if has_normals:
					new_normals.append(old_normals[i0])
					new_normals.append(old_normals[i1])
					new_normals.append(old_normals[i2])
				if has_uvs:
					new_uvs.append(uvs[i0])
					new_uvs.append(uvs[i1])
					new_uvs.append(uvs[i2])

		if new_verts.is_empty():
			continue

		var new_arrays: Array = []
		new_arrays.resize(Mesh.ARRAY_MAX)
		new_arrays[Mesh.ARRAY_VERTEX] = new_verts
		if has_normals and new_normals.size() == new_verts.size():
			new_arrays[Mesh.ARRAY_NORMAL] = new_normals
		if has_uvs and new_uvs.size() == new_verts.size():
			new_arrays[Mesh.ARRAY_TEX_UV] = new_uvs

		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_arrays)

	out.set_mesh(new_mesh)
	return out


static func _get_axis(v: Vector3, axis: int) -> float:
	match axis:
		0: return v.x
		1: return v.y
		2: return v.z
	return v.y
