class_name TwistSOP
extends GNSopBase
## Rotates vertices around an axis proportional to their position along
## that axis, creating a twisting deformation.


func _init() -> void:
	node_type = "twist"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry", "In")
	add_output("out", GNFamily.Type.SOP, "Twisted geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("angle", 0.0, -720.0, 720.0, 0.1,
		"Twist Angle", "Total twist in degrees"))
	add_parameter(GNParameter.create_enum("axis",
		PackedStringArray(["X", "Y", "Z"]), 1, "Axis", "Twist axis"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo := _require_input_geo(inputs)
	if in_geo == null:
		return null

	var out := _prepare_geo()
	var angle_deg: float = get_param_value("angle")
	var axis_idx: int = get_param_value("axis")

	# No twist – pass through
	if absf(angle_deg) < 0.001:
		out.set_mesh(in_geo.mesh.duplicate() as ArrayMesh)
		return out

	var angle_rad: float = deg_to_rad(angle_deg)
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
		var has_normals: bool = arrays[Mesh.ARRAY_NORMAL] != null
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if has_normals else PackedVector3Array()

		# Compute bounds along twist axis
		var min_v: float = INF
		var max_v: float = -INF
		for v in verts:
			var val: float = v[axis_idx]
			min_v = minf(min_v, val)
			max_v = maxf(max_v, val)

		var extent: float = max_v - min_v
		if extent < 0.0001:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		var new_verts := PackedVector3Array()
		new_verts.resize(verts.size())
		var new_normals := PackedVector3Array()
		if has_normals:
			new_normals.resize(normals.size())

		for i in range(verts.size()):
			var v: Vector3 = verts[i]
			var t: float = (v[axis_idx] - min_v) / extent
			var theta: float = t * angle_rad
			var cos_t: float = cos(theta)
			var sin_t: float = sin(theta)

			var new_v := Vector3()
			new_v[axis_idx] = v[axis_idx]
			new_v[perp1] = v[perp1] * cos_t - v[perp2] * sin_t
			new_v[perp2] = v[perp1] * sin_t + v[perp2] * cos_t
			new_verts[i] = new_v

			if has_normals:
				var n: Vector3 = normals[i]
				var new_n := Vector3()
				new_n[axis_idx] = n[axis_idx]
				new_n[perp1] = n[perp1] * cos_t - n[perp2] * sin_t
				new_n[perp2] = n[perp1] * sin_t + n[perp2] * cos_t
				new_normals[i] = new_n.normalized()

		arrays[Mesh.ARRAY_VERTEX] = new_verts
		if has_normals:
			arrays[Mesh.ARRAY_NORMAL] = new_normals
		new_mesh.add_surface_from_arrays(prim, arrays)

	out.set_mesh(new_mesh)
	return out
