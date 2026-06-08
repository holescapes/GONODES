class_name ReverseSOP
extends GNSopBase
## Reverses triangle winding order and/or flips normals.
## Useful for fixing inside-out geometry.


func _init() -> void:
	node_type = "reverse"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry", "In")
	add_output("out", GNFamily.Type.SOP, "Reversed geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("reverse_winding", true, "Enable reverse winding",
		"Reverse triangle winding order"))
	add_parameter(GNParameter.create_bool("flip_normals", true, "Enable flip normals",
		"Flip vertex normals"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = _require_input_geo(inputs)
	if in_geo == null:
		return null

	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var rev_wind: bool = get_param_value("reverse_winding")
	var flip_n: bool = get_param_value("flip_normals")

	var new_mesh := ArrayMesh.new()

	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)

		if prim == Mesh.PRIMITIVE_TRIANGLES and rev_wind:
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				# Generate implicit indices
				var vcount: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				indices.resize(vcount)
				for i in range(vcount):
					indices[i] = i

			# Swap second and third index of each triangle
			for tri in range(indices.size() / 3):
				var base: int = tri * 3
				var tmp: int = indices[base + 1]
				indices[base + 1] = indices[base + 2]
				indices[base + 2] = tmp
			arrays[Mesh.ARRAY_INDEX] = indices

		if flip_n and arrays[Mesh.ARRAY_NORMAL] != null:
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var flipped := PackedVector3Array()
			flipped.resize(normals.size())
			for i in range(normals.size()):
				flipped[i] = -normals[i]
			arrays[Mesh.ARRAY_NORMAL] = flipped

		new_mesh.add_surface_from_arrays(prim, arrays)

	_cached_geo.set_mesh(new_mesh)
	return _cached_geo
