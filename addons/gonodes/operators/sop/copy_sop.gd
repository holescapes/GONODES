class_name CopySOP
extends GNSopBase
## Copies geometry from input A onto each point of input B.
## Each copy is placed at the point position with optional normal alignment.
## Similar to TouchDesigner's Copy SOP / Houdini's Copy to Points.


func _init() -> void:
	node_type = "copy"
	node_description = "Copy geometry onto points of another mesh."


func _init_ports() -> void:
	add_input("template", GNFamily.Type.SOP, false, "Template geometry to copy")
	add_input("points", GNFamily.Type.SOP, false, "Target points / mesh")
	add_output("out", GNFamily.Type.SOP, "Instanced copies")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("align_to_normal", true, "",
		"Rotate copies to align with target point normals"))
	add_parameter(GNParameter.create_float("scale", 1.0, 0.001, 100.0, 0.01,
		"Scale", "Uniform scale per copy"))
	add_parameter(GNParameter.create_bool("use_point_scale", false, "",
		"Use 'pscale' point attribute from target for per-point scale"))


func _cook(inputs: Array[GNData]) -> GNData:
	var template_geo: GNGeoData = _get_input_sop(inputs, 0)
	var points_geo: GNGeoData = _get_input_sop(inputs, 1)

	if template_geo == null or not template_geo.has_geometry():
		return null
	if points_geo == null or not points_geo.has_geometry():
		return null

	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var align: bool = get_param_value("align_to_normal")
	var base_scale: float = get_param_value("scale")
	var use_pscale: bool = get_param_value("use_point_scale")

	# Extract target points and normals from all surfaces
	var target_pts := PackedVector3Array()
	var target_norms := PackedVector3Array()
	for s in range(points_geo.mesh.get_surface_count()):
		var arrays: Array = points_geo.mesh.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			target_pts.append_array(arrays[Mesh.ARRAY_VERTEX])
			if arrays[Mesh.ARRAY_NORMAL] != null:
				target_norms.append_array(arrays[Mesh.ARRAY_NORMAL])
			else:
				var pad := PackedVector3Array()
				pad.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
				pad.fill(Vector3.UP)
				target_norms.append_array(pad)

	# Per-point scale from attribute
	var pscale_attr: PackedFloat32Array = points_geo.get_point_attrib("pscale")

	if target_pts.is_empty():
		return null

	var new_mesh := ArrayMesh.new()

	# For each template surface, build all copies
	for ts in range(template_geo.mesh.get_surface_count()):
		var t_arrays: Array = template_geo.mesh.surface_get_arrays(ts)
		var t_prim: Mesh.PrimitiveType = template_geo.mesh.surface_get_primitive_type(ts)

		if t_arrays[Mesh.ARRAY_VERTEX] == null:
			continue

		var t_verts: PackedVector3Array = t_arrays[Mesh.ARRAY_VERTEX]
		var t_normals: PackedVector3Array = t_arrays[Mesh.ARRAY_NORMAL] if t_arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var t_uvs: PackedVector2Array = t_arrays[Mesh.ARRAY_TEX_UV] if t_arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var t_indices: PackedInt32Array = t_arrays[Mesh.ARRAY_INDEX] if t_arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()

		var vert_count: int = t_verts.size()
		var total_verts: int = vert_count * target_pts.size()

		var out_verts := PackedVector3Array()
		out_verts.resize(total_verts)
		var out_normals := PackedVector3Array()
		if not t_normals.is_empty():
			out_normals.resize(total_verts)
		var out_uvs := PackedVector2Array()
		if not t_uvs.is_empty():
			out_uvs.resize(total_verts)

		var out_indices := PackedInt32Array()
		if not t_indices.is_empty():
			out_indices.resize(t_indices.size() * target_pts.size())

		for pi in range(target_pts.size()):
			var pos: Vector3 = target_pts[pi]
			var n: Vector3 = target_norms[pi] if pi < target_norms.size() else Vector3.UP
			var s: float = base_scale
			if use_pscale and pi < pscale_attr.size():
				s *= pscale_attr[pi]

			# Build transform: scale → rotate → translate
			var xform := Transform3D.IDENTITY
			if align and n.length_squared() > 0.001:
				xform.basis = _basis_from_normal(n.normalized())
			xform.basis = xform.basis.scaled(Vector3(s, s, s))
			xform.origin = pos

			var base_v: int = pi * vert_count
			for vi in range(vert_count):
				out_verts[base_v + vi] = xform * t_verts[vi]
				if not t_normals.is_empty() and vi < t_normals.size():
					out_normals[base_v + vi] = (xform.basis * t_normals[vi]).normalized()
				if not t_uvs.is_empty() and vi < t_uvs.size():
					out_uvs[base_v + vi] = t_uvs[vi]

			if not t_indices.is_empty():
				var base_i: int = pi * t_indices.size()
				for ii in range(t_indices.size()):
					out_indices[base_i + ii] = t_indices[ii] + base_v

		var out_arrays: Array = []
		out_arrays.resize(Mesh.ARRAY_MAX)
		out_arrays[Mesh.ARRAY_VERTEX] = out_verts
		if not out_normals.is_empty():
			out_arrays[Mesh.ARRAY_NORMAL] = out_normals
		if not out_uvs.is_empty():
			out_arrays[Mesh.ARRAY_TEX_UV] = out_uvs
		if not out_indices.is_empty():
			out_arrays[Mesh.ARRAY_INDEX] = out_indices

		new_mesh.add_surface_from_arrays(t_prim, out_arrays)

	_cached_geo.set_mesh(new_mesh)
	return _cached_geo


## Build an orthonormal basis where Y axis aligns with the given normal.
func _basis_from_normal(n: Vector3) -> Basis:
	var up: Vector3 = n
	var right: Vector3
	if absf(up.dot(Vector3.UP)) > 0.999:
		right = Vector3.RIGHT
	else:
		right = up.cross(Vector3.UP).normalized()
	var forward: Vector3 = right.cross(up).normalized()
	return Basis(right, up, forward)
