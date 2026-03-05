class_name TaperSOP
extends GNSopBase
## Scales perpendicular axes as a function of position along the taper axis,
## creating a tapering (narrowing/widening) deformation.


func _init() -> void:
	node_type = "taper"
	node_description = "Taper geometry along an axis."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Tapered geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("scale_start", 1.0, 0.0, 10.0, 0.01,
		"Scale Start", "Scale factor at the start of the axis"))
	add_parameter(GNParameter.create_float("scale_end", 0.5, 0.0, 10.0, 0.01,
		"Scale End", "Scale factor at the end of the axis"))
	add_parameter(GNParameter.create_enum("axis",
		PackedStringArray(["X", "Y", "Z"]), 1, "Axis", "Taper axis"))
	add_parameter(GNParameter.create_enum("profile",
		PackedStringArray(["Linear", "Smooth"]), 0, "Profile", "Interpolation profile"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo := _require_input_geo(inputs)
	if in_geo == null:
		return null

	var out := _prepare_geo()
	var scale_start: float = get_param_value("scale_start")
	var scale_end: float = get_param_value("scale_end")
	var axis_idx: int = get_param_value("axis")
	var profile_idx: int = get_param_value("profile")
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

		# Compute bounds along taper axis
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
			var t: float = clampf((v[axis_idx] - min_v) / extent, 0.0, 1.0)

			# Apply profile
			if profile_idx == 1:
				t = t * t * (3.0 - 2.0 * t)  # smoothstep

			var scale_factor: float = lerpf(scale_start, scale_end, t)

			var new_v := Vector3()
			new_v[axis_idx] = v[axis_idx]
			new_v[perp1] = v[perp1] * scale_factor
			new_v[perp2] = v[perp2] * scale_factor
			new_verts[i] = new_v

			if has_normals:
				var n: Vector3 = normals[i]
				# Inverse-transpose scaling for normals on perpendicular axes
				var inv_scale: float = 1.0 / maxf(scale_factor, 0.0001)
				var new_n := Vector3()
				new_n[axis_idx] = n[axis_idx]
				new_n[perp1] = n[perp1] * inv_scale
				new_n[perp2] = n[perp2] * inv_scale
				new_normals[i] = new_n.normalized()

		arrays[Mesh.ARRAY_VERTEX] = new_verts
		if has_normals:
			arrays[Mesh.ARRAY_NORMAL] = new_normals
		new_mesh.add_surface_from_arrays(prim, arrays)

	out.set_mesh(new_mesh)
	return out
