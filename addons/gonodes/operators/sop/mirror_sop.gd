class_name MirrorSOP
extends GNSopBase
## Mirrors geometry across a plane and optionally merges with the original.
## Uses Godot's Transform3D for the reflection.


func _init() -> void:
	node_type = "mirror"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry", "In")
	add_output("out", GNFamily.Type.SOP, "Mirrored geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("plane",
		PackedStringArray(["YZ (Mirror X)", "XZ (Mirror Y)", "XY (Mirror Z)"]),
		0, "", "Reflection plane"))
	add_parameter(GNParameter.create_float("origin", 0.0, null, null, 0.01,
		"Origin", "Plane offset along the mirror axis"))
	add_parameter(GNParameter.create_bool("merge", true, "Enable merge",
		"Merge original and mirrored geometry"))
	add_parameter(GNParameter.create_bool("reverse_winding", true, "Enable reverse winding",
		"Reverse winding of mirrored faces (keeps normals correct)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = _require_input_geo(inputs)
	if in_geo == null:
		return null

	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var plane: int = get_param_value("plane")
	var origin: float = get_param_value("origin")
	var do_merge: bool = get_param_value("merge")
	var rev_wind: bool = get_param_value("reverse_winding")

	# Build reflection axis
	var mirror_axis: Vector3
	match plane:
		0: mirror_axis = Vector3(1, 0, 0)  # YZ plane → mirror X
		1: mirror_axis = Vector3(0, 1, 0)  # XZ plane → mirror Y
		_: mirror_axis = Vector3(0, 0, 1)  # XY plane → mirror Z

	var new_mesh := ArrayMesh.new()

	# Add original surfaces if merging
	if do_merge:
		for s in range(in_geo.mesh.get_surface_count()):
			new_mesh.add_surface_from_arrays(
				in_geo.mesh.surface_get_primitive_type(s),
				in_geo.mesh.surface_get_arrays(s))

	# Add mirrored surfaces
	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)

		if arrays[Mesh.ARRAY_VERTEX] == null:
			continue

		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var new_verts := PackedVector3Array()
		new_verts.resize(verts.size())

		for i in range(verts.size()):
			var p: Vector3 = verts[i]
			# Reflect: p' = p - 2 * (dot(p - origin_pt, axis)) * axis
			var offset: float = p.dot(mirror_axis) - origin
			new_verts[i] = p - 2.0 * offset * mirror_axis
		arrays[Mesh.ARRAY_VERTEX] = new_verts

		# Flip normals across the mirror plane
		if arrays[Mesh.ARRAY_NORMAL] != null:
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var new_normals := PackedVector3Array()
			new_normals.resize(normals.size())
			for i in range(normals.size()):
				var n: Vector3 = normals[i]
				new_normals[i] = (n - 2.0 * n.dot(mirror_axis) * mirror_axis).normalized()
			arrays[Mesh.ARRAY_NORMAL] = new_normals

		# Reverse winding order to maintain correct face orientation
		if rev_wind and prim == Mesh.PRIMITIVE_TRIANGLES:
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				indices.resize(new_verts.size())
				for i in range(new_verts.size()):
					indices[i] = i
			for tri in range(indices.size() / 3):
				var base: int = tri * 3
				var tmp: int = indices[base + 1]
				indices[base + 1] = indices[base + 2]
				indices[base + 2] = tmp
			arrays[Mesh.ARRAY_INDEX] = indices

		new_mesh.add_surface_from_arrays(prim, arrays)

	_cached_geo.set_mesh(new_mesh)
	return _cached_geo
