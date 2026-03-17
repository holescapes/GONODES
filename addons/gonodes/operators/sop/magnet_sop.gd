class_name MagnetSOP
extends GNSopBase
## Magnet SOP — Deforms input geometry by attracting / repelling vertices
## toward or away from one or more attractor points.
##
## Attractors can come from:
##   • A second SOP input (point cloud — each point is an attractor).
##   • A single built-in attractor (position from parameters).
##
## Parameters control the strength, direction (attract vs repel), falloff
## radius and falloff curve.  Useful for organic deformation, dents, bulges.

func _init() -> void:
	node_type = "magnet"
	node_description = "Deform geometry by attracting/repelling vertices toward points."


func _init_ports() -> void:
	add_input("geo", GNFamily.Type.SOP, true, "Geometry to deform", "Geometry")
	add_input("attractors", GNFamily.Type.SOP, false, "Attractor point cloud (optional)")
	add_output("out", GNFamily.Type.SOP, "Deformed geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("strength", 1.0, -10.0, 10.0, 0.05,
		"Strength", "Deformation strength (negative = repel)"))
	add_parameter(GNParameter.create_float("radius", 2.0, 0.01, 100.0, 0.1,
		"Radius", "Falloff radius around each attractor"))
	add_parameter(GNParameter.create_enum("falloff",
		PackedStringArray(["Linear", "Smooth", "Inverse Square", "Gaussian"]),
		1, "Falloff", "Distance falloff curve"))
	add_parameter(GNParameter.create_float("exponent", 2.0, 0.1, 10.0, 0.1,
		"Exponent", "Falloff exponent (Gaussian sigma / power)"))
	add_parameter(GNParameter.create_bool("affect_normals", true,
		"Affect Normals", "Recompute normals after deformation"))

	# Built-in single attractor (when no 2nd input)
	add_parameter(GNParameter.create_float("att_x", 0.0, -100.0, 100.0, 0.1, "Attractor X", ""))
	add_parameter(GNParameter.create_float("att_y", 0.0, -100.0, 100.0, 0.1, "Attractor Y", ""))
	add_parameter(GNParameter.create_float("att_z", 0.0, -100.0, 100.0, 0.1, "Attractor Z", ""))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = _require_input_geo(inputs)
	if in_geo == null:
		return null

	var att_geo: GNGeoData = _get_input_sop(inputs, 1)

	# ── Collect attractor positions ──
	var attractors := PackedVector3Array()
	if att_geo != null and att_geo.has_geometry():
		for s in range(att_geo.mesh.get_surface_count()):
			var arr: Array = att_geo.mesh.surface_get_arrays(s)
			if arr[Mesh.ARRAY_VERTEX] != null:
				attractors.append_array(arr[Mesh.ARRAY_VERTEX])
	else:
		attractors.append(Vector3(
			get_param_value("att_x"),
			get_param_value("att_y"),
			get_param_value("att_z")))

	if attractors.is_empty():
		return in_geo

	var strength: float = get_param_value("strength")
	var radius: float = get_param_value("radius")
	var falloff_type: int = get_param_value("falloff")
	var exponent: float = get_param_value("exponent")
	var affect_normals: bool = get_param_value("affect_normals")

	# Duplicate input mesh
	var out := _prepare_geo()
	var new_mesh := ArrayMesh.new()

	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] == null:
			continue

		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var deformed := PackedVector3Array()
		deformed.resize(verts.size())

		for vi in range(verts.size()):
			var v: Vector3 = verts[vi]
			var displacement := Vector3.ZERO

			for ai in range(attractors.size()):
				var att: Vector3 = attractors[ai]
				var diff: Vector3 = att - v
				var dist: float = diff.length()

				if dist > radius or dist < 0.0001:
					continue

				var dir: Vector3 = diff / dist
				var t: float = dist / radius  # 0 at attractor, 1 at radius edge
				var weight: float = _falloff(t, falloff_type, exponent)
				displacement += dir * weight * strength

			deformed[vi] = v + displacement

		arrays[Mesh.ARRAY_VERTEX] = deformed

		# Recompute normals if requested
		if affect_normals and arrays[Mesh.ARRAY_INDEX] != null:
			arrays[Mesh.ARRAY_NORMAL] = _recompute_normals(
				deformed, arrays[Mesh.ARRAY_INDEX])
		elif affect_normals and arrays[Mesh.ARRAY_NORMAL] != null:
			# Non-indexed: compute face normals
			arrays[Mesh.ARRAY_NORMAL] = _recompute_face_normals(deformed)

		var prim_type: int = in_geo.mesh.surface_get_primitive_type(s)
		new_mesh.add_surface_from_arrays(prim_type, arrays)

	out.set_mesh(new_mesh)
	return out


static func _falloff(t: float, falloff_type: int, exponent: float) -> float:
	# t: 0 = at attractor, 1 = at radius edge
	# Return weight 1→0 as t goes 0→1
	match falloff_type:
		0:  # Linear
			return 1.0 - t
		1:  # Smooth (smoothstep)
			var s: float = 1.0 - t
			return s * s * (3.0 - 2.0 * s)
		2:  # Inverse Square
			return 1.0 / (1.0 + pow(t * exponent, 2.0))
		3:  # Gaussian
			return exp(-(t * t) * exponent * exponent)
	return 1.0 - t


static func _recompute_normals(verts: PackedVector3Array,
		indices: PackedInt32Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for i in range(normals.size()):
		normals[i] = Vector3.ZERO

	var tri_count: int = indices.size() / 3
	for ti in range(tri_count):
		var i0: int = indices[ti * 3]
		var i1: int = indices[ti * 3 + 1]
		var i2: int = indices[ti * 3 + 2]
		var e1: Vector3 = verts[i1] - verts[i0]
		var e2: Vector3 = verts[i2] - verts[i0]
		var fn: Vector3 = e1.cross(e2)
		normals[i0] += fn
		normals[i1] += fn
		normals[i2] += fn

	for i in range(normals.size()):
		var len: float = normals[i].length()
		if len > 0.0001:
			normals[i] /= len
		else:
			normals[i] = Vector3.UP
	return normals


static func _recompute_face_normals(verts: PackedVector3Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	var tri_count: int = verts.size() / 3
	for ti in range(tri_count):
		var i0: int = ti * 3
		var e1: Vector3 = verts[i0 + 1] - verts[i0]
		var e2: Vector3 = verts[i0 + 2] - verts[i0]
		var fn: Vector3 = e1.cross(e2).normalized()
		if fn.length_squared() < 0.0001:
			fn = Vector3.UP
		normals[i0] = fn
		normals[i0 + 1] = fn
		normals[i0 + 2] = fn
	return normals
