class_name CapSOP
extends GNSopBase
## Close open holes in polygon meshes by detecting boundary edges
## and filling them with a triangle fan.
##
## Boundary edges are edges that belong to only one triangle.
## Connected boundary loops are identified, then each loop is
## capped with a fan from the centroid.

func _init() -> void:
	node_type = "cap"
	node_description = "Close open boundary holes with triangle fan caps."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry with holes")
	add_output("out", GNFamily.Type.SOP, "Capped geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("cap_all", true,
		"Cap All Holes", "Fill all detected boundary loops"))
	add_parameter(GNParameter.create_bool("flip_cap_normals", false,
		"Flip Cap Normals", "Invert the winding of generated cap faces"))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo: GNGeoData = _require_input_geo(inputs)
	if geo == null:
		return null

	var flip: bool = get_param_value("flip_cap_normals")
	var output: GNGeoData = _prepare_geo()

	# Collect all triangles and find boundary edges
	var all_positions := PackedVector3Array()
	var all_normals := PackedVector3Array()
	var all_uvs := PackedVector2Array()
	var has_normals: bool = false
	var has_uvs: bool = false

	# First pass: copy existing geometry into SurfaceTool
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Also track edges for boundary detection
	# edge_key → count.  edge_key = sorted pair of position indices.
	var edge_count: Dictionary = {}
	# Position dedup map for edge matching
	var pos_to_idx: Dictionary = {}
	var unique_pos: PackedVector3Array = PackedVector3Array()
	var global_idx_map: PackedInt32Array = PackedInt32Array()  # per-vertex → unique pos idx

	for surf_idx in range(geo.get_surface_count()):
		var arrays: Array = geo.get_surface_arrays(surf_idx)
		if arrays.is_empty():
			continue
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals = arrays[Mesh.ARRAY_NORMAL]
		var uvs = arrays[Mesh.ARRAY_TEX_UV]
		if normals != null and normals.size() > 0:
			has_normals = true
		if uvs != null and uvs.size() > 0:
			has_uvs = true

		var base: int = all_positions.size()
		for i in range(positions.size()):
			all_positions.append(positions[i])
			if has_normals and normals != null and i < normals.size():
				all_normals.append(normals[i])
			else:
				all_normals.append(Vector3.UP)
			if has_uvs and uvs != null and i < uvs.size():
				all_uvs.append(uvs[i])
			else:
				all_uvs.append(Vector2.ZERO)

			# Unique position map (snap to grid for floating point matching)
			var snapped: Vector3i = Vector3i(
				roundi(positions[i].x * 10000),
				roundi(positions[i].y * 10000),
				roundi(positions[i].z * 10000))
			if not pos_to_idx.has(snapped):
				pos_to_idx[snapped] = unique_pos.size()
				unique_pos.append(positions[i])
			global_idx_map.append(pos_to_idx[snapped])

		# Count edges (triangles)
		var indices = arrays[Mesh.ARRAY_INDEX]
		var tri_indices: PackedInt32Array
		if indices != null and indices.size() > 0:
			tri_indices = indices
		else:
			tri_indices = PackedInt32Array()
			tri_indices.resize(positions.size())
			for i in range(positions.size()):
				tri_indices[i] = i

		for t in range(tri_indices.size() / 3):
			var a: int = global_idx_map[base + tri_indices[t * 3]]
			var b: int = global_idx_map[base + tri_indices[t * 3 + 1]]
			var c: int = global_idx_map[base + tri_indices[t * 3 + 2]]
			for edge: Vector2i in [Vector2i(mini(a, b), maxi(a, b)),
					Vector2i(mini(b, c), maxi(b, c)),
					Vector2i(mini(a, c), maxi(a, c))]:
				edge_count[edge] = edge_count.get(edge, 0) + 1

	# Copy original vertices
	for i in range(all_positions.size()):
		st.set_normal(all_normals[i])
		st.set_uv(all_uvs[i])
		st.add_vertex(all_positions[i])

	# Find boundary edges (count == 1)
	var boundary_edges: Array = []
	for edge_key: Vector2i in edge_count:
		if edge_count[edge_key] == 1:
			boundary_edges.append(edge_key)

	if boundary_edges.is_empty():
		# No holes — pass through
		st.generate_normals()
		output.set_from_surface_tool(st)
		return output

	# Build adjacency for boundary vertices and trace loops
	var adj: Dictionary = {}  # unique_pos_idx → Array[unique_pos_idx]
	for edge: Vector2i in boundary_edges:
		if not adj.has(edge.x):
			adj[edge.x] = []
		adj[edge.x].append(edge.y)
		if not adj.has(edge.y):
			adj[edge.y] = []
		adj[edge.y].append(edge.x)

	# Trace closed loops
	var visited: Dictionary = {}
	var loops: Array = []
	for start_idx: int in adj:
		if visited.has(start_idx):
			continue
		var loop: PackedInt32Array = PackedInt32Array()
		var current: int = start_idx
		var prev: int = -1
		while true:
			if visited.has(current):
				break
			visited[current] = true
			loop.append(current)
			var neighbors: Array = adj.get(current, [])
			var next: int = -1
			for n: int in neighbors:
				if n != prev:
					next = n
					break
			if next < 0:
				break
			prev = current
			current = next
		if loop.size() >= 3:
			loops.append(loop)

	# Fill each loop with a triangle fan from centroid
	for loop: PackedInt32Array in loops:
		var centroid := Vector3.ZERO
		for idx: int in loop:
			centroid += unique_pos[idx]
		centroid /= float(loop.size())

		# Compute fan normal from first triangle
		var fan_normal: Vector3 = (unique_pos[loop[1]] - unique_pos[loop[0]]).cross(
			centroid - unique_pos[loop[0]]).normalized()
		if flip:
			fan_normal = -fan_normal

		for i in range(loop.size()):
			var a: Vector3 = unique_pos[loop[i]]
			var b: Vector3 = unique_pos[loop[(i + 1) % loop.size()]]
			if flip:
				st.set_normal(fan_normal)
				st.add_vertex(centroid)
				st.set_normal(fan_normal)
				st.add_vertex(b)
				st.set_normal(fan_normal)
				st.add_vertex(a)
			else:
				st.set_normal(fan_normal)
				st.add_vertex(a)
				st.set_normal(fan_normal)
				st.add_vertex(b)
				st.set_normal(fan_normal)
				st.add_vertex(centroid)

	st.generate_normals()
	output.set_from_surface_tool(st)
	return output
