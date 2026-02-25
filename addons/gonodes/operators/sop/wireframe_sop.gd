class_name WireframeSOP
extends GNSopBase
## Converts triangle mesh to wireframe (line) representation.
## Useful for visualization and stylized rendering.


func _init() -> void:
	node_type = "wireframe"
	node_description = "Convert triangles to wireframe lines."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Wireframe mesh")


func _init_parameters() -> void:
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = inputs[0] as GNGeoData if inputs.size() > 0 and inputs[0] is GNGeoData else null
	if in_geo == null or not in_geo.has_geometry():
		return null

	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var new_mesh := ArrayMesh.new()

	for s in range(in_geo.mesh.get_surface_count()):
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)
		if prim != Mesh.PRIMITIVE_TRIANGLES:
			new_mesh.add_surface_from_arrays(prim, in_geo.mesh.surface_get_arrays(s))
			continue

		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()

		# If no indices, create sequential
		if indices.is_empty():
			indices.resize(verts.size())
			for i in range(verts.size()):
				indices[i] = i

		# Build line segments from triangle edges (deduplicate)
		var edge_set: Dictionary = {}
		var line_verts := PackedVector3Array()

		for tri in range(indices.size() / 3):
			var i0: int = indices[tri * 3]
			var i1: int = indices[tri * 3 + 1]
			var i2: int = indices[tri * 3 + 2]

			_add_edge(edge_set, line_verts, verts, i0, i1)
			_add_edge(edge_set, line_verts, verts, i1, i2)
			_add_edge(edge_set, line_verts, verts, i2, i0)

		var line_arrays: Array = []
		line_arrays.resize(Mesh.ARRAY_MAX)
		line_arrays[Mesh.ARRAY_VERTEX] = line_verts
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, line_arrays)

	_cached_geo.set_mesh(new_mesh)
	return _cached_geo


func _add_edge(edge_set: Dictionary, line_verts: PackedVector3Array,
		verts: PackedVector3Array, a: int, b: int) -> void:
	var key: int = mini(a, b) * 100000 + maxi(a, b)
	if edge_set.has(key):
		return
	edge_set[key] = true
	line_verts.append(verts[a])
	line_verts.append(verts[b])
