class_name BendSOP
extends GNSopBase
## Bends geometry along an axis using circular arc deformation.
## Vertices are displaced along a circular arc proportional to their
## position along the chosen axis.


func _init() -> void:
	node_type = "bend"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry", "In")
	add_output("out", GNFamily.Type.SOP, "Bent geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("angle", 0.0, -360.0, 360.0, 0.1,
		"Bend Angle", "Bend angle in degrees"))
	add_parameter(GNParameter.create_enum("axis",
		PackedStringArray(["X", "Y", "Z"]), 1, "Axis", "Bend axis"))
	add_parameter(GNParameter.create_float("origin", 0.0, -10.0, 10.0, 0.01,
		"Origin", "Center of bend along axis"))
	add_parameter(GNParameter.create_float("length_val", 0.0, null, null, 0.01,
		"Length", "Region length (0 = auto from bounds)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo := _require_input_geo(inputs)
	if in_geo == null:
		return null

	var out := _prepare_geo()
	var angle_deg: float = get_param_value("angle")
	var axis_idx: int = get_param_value("axis")
	var origin_val: float = get_param_value("origin")
	var length_val: float = get_param_value("length_val")

	# Degenerate case: no bend – just duplicate input
	if absf(angle_deg) < 0.001:
		out.set_mesh(in_geo.mesh.duplicate() as ArrayMesh)
		return out

	var angle_rad: float = deg_to_rad(angle_deg)
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

		# Determine bend region length
		var region_len: float = length_val
		if region_len <= 0.0:
			var min_v: float = INF
			var max_v: float = -INF
			for v in verts:
				var val: float = v[axis_idx]
				min_v = minf(min_v, val)
				max_v = maxf(max_v, val)
			region_len = max_v - min_v
		if region_len < 0.0001:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		var radius: float = region_len / angle_rad
		var perp: int = (axis_idx + 1) % 3   # axis we bend into
		var other: int = (axis_idx + 2) % 3   # axis that stays unchanged

		var new_verts := PackedVector3Array()
		new_verts.resize(verts.size())
		var new_normals := PackedVector3Array()
		if has_normals:
			new_normals.resize(normals.size())

		for i in range(verts.size()):
			var v: Vector3 = verts[i]
			var t: float = clampf((v[axis_idx] - origin_val) / region_len, 0.0, 1.0)
			var theta: float = t * angle_rad

			var new_v := Vector3()
			new_v[axis_idx] = origin_val + sin(theta) * radius
			new_v[perp] = v[perp] + (1.0 - cos(theta)) * radius
			new_v[other] = v[other]
			new_verts[i] = new_v

			if has_normals:
				var n: Vector3 = normals[i]
				var new_n := Vector3()
				new_n[axis_idx] = cos(theta) * n[axis_idx] + sin(theta) * n[perp]
				new_n[perp] = -sin(theta) * n[axis_idx] + cos(theta) * n[perp]
				new_n[other] = n[other]
				new_normals[i] = new_n.normalized()

		arrays[Mesh.ARRAY_VERTEX] = new_verts
		if has_normals:
			arrays[Mesh.ARRAY_NORMAL] = new_normals
		new_mesh.add_surface_from_arrays(prim, arrays)

	out.set_mesh(new_mesh)
	return out
