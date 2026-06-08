class_name FuseSOP
extends GNSopBase
## Merge coincident vertices within a distance threshold.
## Essential for cleaning geometry after Boolean, Merge, or Copy operations.
##
## Algorithm: spatial hash grid — O(N) average for typical meshes.
## Each vertex is placed in a cell of size = threshold. Only vertices
## in the same or neighbouring cells are compared. Duplicate vertices
## are collapsed to the first-found representative.

func _init() -> void:
	node_type = "fuse"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry", "In")
	add_output("out", GNFamily.Type.SOP, "Fused geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("threshold", 0.001, 0.0, 1.0, 0.0001,
		"Distance", "Max distance to merge vertices"))
	add_parameter(GNParameter.create_bool("recompute_normals", true,
		"Recompute Normals", "Regenerate smooth normals after fusing"))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo: GNGeoData = _require_input_geo(inputs)
	if geo == null:
		return null

	var threshold: float = get_param_value("threshold")
	var recompute: bool = get_param_value("recompute_normals")
	var output: GNGeoData = _prepare_geo()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for surf_idx in range(geo.get_surface_count()):
		var arrays: Array = geo.get_surface_arrays(surf_idx)
		if arrays.is_empty():
			continue
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals = arrays[Mesh.ARRAY_NORMAL]
		var uvs = arrays[Mesh.ARRAY_TEX_UV]
		var indices = arrays[Mesh.ARRAY_INDEX]

		# Build spatial hash: cell_key → representative index
		var cell_size: float = maxf(threshold, 0.0001)
		var remap: Dictionary = {}  # original index → fused index
		var unique_positions: PackedVector3Array = PackedVector3Array()
		var unique_normals: PackedVector3Array = PackedVector3Array()
		var unique_uvs: PackedVector2Array = PackedVector2Array()
		var grid: Dictionary = {}  # Vector3i → Array[int] (indices into unique_*)

		for i in range(positions.size()):
			var pos: Vector3 = positions[i]
			var cell := Vector3i(
				floori(pos.x / cell_size),
				floori(pos.y / cell_size),
				floori(pos.z / cell_size))

			var found: int = -1
			# Search 3x3x3 neighbourhood
			for dx in range(-1, 2):
				if found >= 0:
					break
				for dy in range(-1, 2):
					if found >= 0:
						break
					for dz in range(-1, 2):
						var nc := Vector3i(cell.x + dx, cell.y + dy, cell.z + dz)
						if grid.has(nc):
							for idx: int in grid[nc]:
								if unique_positions[idx].distance_to(pos) <= threshold:
									found = idx
									break
						if found >= 0:
							break

			if found >= 0:
				remap[i] = found
			else:
				var new_idx: int = unique_positions.size()
				remap[i] = new_idx
				unique_positions.append(pos)
				if normals != null and i < normals.size():
					unique_normals.append(normals[i])
				if uvs != null and i < uvs.size():
					unique_uvs.append(uvs[i])
				if not grid.has(cell):
					grid[cell] = []
				grid[cell].append(new_idx)

		# Rebuild triangles with remapped indices
		var tri_verts: PackedInt32Array
		if indices != null and indices.size() > 0:
			tri_verts = indices
		else:
			# Non-indexed: every 3 vertices form a triangle
			tri_verts = PackedInt32Array()
			tri_verts.resize(positions.size())
			for i in range(positions.size()):
				tri_verts[i] = i

		var tri_count: int = tri_verts.size() / 3
		for t in range(tri_count):
			var i0: int = remap[tri_verts[t * 3]]
			var i1: int = remap[tri_verts[t * 3 + 1]]
			var i2: int = remap[tri_verts[t * 3 + 2]]
			# Skip degenerate triangles (collapsed by fusing)
			if i0 == i1 or i1 == i2 or i2 == i0:
				continue
			for vi in [i0, i1, i2]:
				if unique_normals.size() > vi:
					st.set_normal(unique_normals[vi])
				if unique_uvs.size() > vi:
					st.set_uv(unique_uvs[vi])
				st.add_vertex(unique_positions[vi])

	if recompute:
		st.generate_normals()
	st.index()
	output.set_from_surface_tool(st)
	return output
