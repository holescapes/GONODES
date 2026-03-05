class_name UVProjectSOP
extends GNSopBase
## Assigns UV coordinates to geometry using planar, cylindrical,
## or spherical projection.


func _init() -> void:
	node_type = "uvproject"
	node_description = "Project UV coordinates onto geometry."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Geometry with projected UVs")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Planar", "Cylindrical", "Spherical"]), 0,
		"Mode", "UV projection mode"))
	add_parameter(GNParameter.create_enum("axis",
		PackedStringArray(["X", "Y", "Z"]), 1,
		"Axis", "Projection axis"))
	add_parameter(GNParameter.create_float("scale_u", 1.0, 0.001, 100.0, 0.01,
		"Scale U", "UV scale in U direction"))
	add_parameter(GNParameter.create_float("scale_v", 1.0, 0.001, 100.0, 0.01,
		"Scale V", "UV scale in V direction"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo := _require_input_geo(inputs)
	if in_geo == null:
		return null

	var out := _prepare_geo()
	var mode_idx: int = get_param_value("mode")
	var axis_idx: int = get_param_value("axis")
	var su: float = get_param_value("scale_u")
	var sv: float = get_param_value("scale_v")

	var perp1: int = (axis_idx + 1) % 3
	var perp2: int = (axis_idx + 2) % 3

	var new_mesh := ArrayMesh.new()

	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)

		if arrays[Mesh.ARRAY_VERTEX] == null:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var new_uvs := PackedVector2Array()
		new_uvs.resize(verts.size())

		match mode_idx:
			0:  # Planar
				_project_planar(verts, new_uvs, axis_idx, perp1, perp2, su, sv)
			1:  # Cylindrical
				_project_cylindrical(verts, new_uvs, axis_idx, perp1, perp2, su, sv)
			2:  # Spherical
				_project_spherical(verts, new_uvs, axis_idx, perp1, perp2, su, sv)

		arrays[Mesh.ARRAY_TEX_UV] = new_uvs
		new_mesh.add_surface_from_arrays(prim, arrays)

	out.set_mesh(new_mesh)
	return out


func _project_planar(verts: PackedVector3Array, uvs: PackedVector2Array,
		_axis_idx: int, perp1: int, perp2: int, su: float, sv: float) -> void:
	# Compute AABB on the projection plane
	var min1: float = INF
	var max1: float = -INF
	var min2: float = INF
	var max2: float = -INF
	for v in verts:
		min1 = minf(min1, v[perp1])
		max1 = maxf(max1, v[perp1])
		min2 = minf(min2, v[perp2])
		max2 = maxf(max2, v[perp2])
	var range1: float = maxf(max1 - min1, 0.0001)
	var range2: float = maxf(max2 - min2, 0.0001)

	for i in range(verts.size()):
		var v: Vector3 = verts[i]
		var u: float = ((v[perp1] - min1) / range1) * su
		var vv: float = ((v[perp2] - min2) / range2) * sv
		uvs[i] = Vector2(u, vv)


func _project_cylindrical(verts: PackedVector3Array, uvs: PackedVector2Array,
		axis_idx: int, perp1: int, perp2: int, su: float, sv: float) -> void:
	# U from atan2 of two perpendicular components, V from axis position
	var min_ax: float = INF
	var max_ax: float = -INF
	for v in verts:
		min_ax = minf(min_ax, v[axis_idx])
		max_ax = maxf(max_ax, v[axis_idx])
	var range_ax: float = maxf(max_ax - min_ax, 0.0001)

	for i in range(verts.size()):
		var v: Vector3 = verts[i]
		var u: float = (atan2(v[perp1], v[perp2]) / TAU + 0.5) * su
		var vv: float = ((v[axis_idx] - min_ax) / range_ax) * sv
		uvs[i] = Vector2(u, vv)


func _project_spherical(verts: PackedVector3Array, uvs: PackedVector2Array,
		axis_idx: int, perp1: int, perp2: int, su: float, sv: float) -> void:
	for i in range(verts.size()):
		var v: Vector3 = verts[i]
		var len_xz: float = sqrt(v[perp1] * v[perp1] + v[perp2] * v[perp2])
		var u: float = (atan2(v[perp1], v[perp2]) / TAU + 0.5) * su
		var vv: float = (atan2(v[axis_idx], len_xz) / PI + 0.5) * sv
		uvs[i] = Vector2(u, vv)
