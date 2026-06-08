class_name CreepSOP
extends GNSopBase
## Moves source points along the surface of a target mesh.
## Each source vertex is projected onto the nearest triangle of the target,
## then displaced along the surface by the specified distance.

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	node_type = "creep"


func _init_ports() -> void:
	add_input("source", GNFamily.Type.SOP, false, "Points to creep along surface", "Source")
	add_input("surface", GNFamily.Type.SOP, false, "Target surface to creep on", "Surface")
	add_output("out", GNFamily.Type.SOP, "Displaced points", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("distance", 0.1, -10.0, 10.0, 0.01,
		"Distance", "Distance to move along the surface"))
	add_parameter(GNParameter.create_enum("direction",
		PackedStringArray(["Normal", "Tangent U", "Tangent V", "Random"]), 0,
		"Direction", "Direction of movement along surface"))
	add_parameter(GNParameter.create_int("seed", 0, 0, 99999,
		"Seed", "Random seed for random direction mode"))


func _cook(inputs: Array[GNData]) -> GNData:
	var src_geo := _get_input_sop(inputs, 0)
	var surf_geo := _get_input_sop(inputs, 1)
	if src_geo == null or not src_geo.has_geometry():
		return null
	if surf_geo == null or not surf_geo.has_geometry():
		return src_geo

	var dist: float = get_param_value("distance")
	var dir_mode: int = get_param_value("direction")
	var seed_val: int = get_param_value("seed")
	_rng.seed = seed_val

	# Build triangle list from surface
	var tri_verts: PackedVector3Array = PackedVector3Array()
	var tri_normals: PackedVector3Array = PackedVector3Array()
	for s in range(surf_geo.mesh.get_surface_count()):
		var arrays: Array = surf_geo.mesh.surface_get_arrays(s)
		if surf_geo.mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var sv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var sn: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var si: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if si.size() >= 3:
			for i in range(0, si.size() - 2, 3):
				tri_verts.append(sv[si[i]])
				tri_verts.append(sv[si[i + 1]])
				tri_verts.append(sv[si[i + 2]])
				var n: Vector3 = (sv[si[i + 1]] - sv[si[i]]).cross(sv[si[i + 2]] - sv[si[i]]).normalized()
				tri_normals.append(n)
		elif sv.size() >= 3:
			for i in range(0, sv.size() - 2, 3):
				tri_verts.append(sv[i])
				tri_verts.append(sv[i + 1])
				tri_verts.append(sv[i + 2])
				var n: Vector3 = (sv[i + 1] - sv[i]).cross(sv[i + 2] - sv[i]).normalized()
				tri_normals.append(n)

	if tri_verts.is_empty():
		return src_geo

	var geo := _prepare_geo()
	var new_mesh := ArrayMesh.new()

	for s in range(src_geo.mesh.get_surface_count()):
		var arrays: Array = src_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = src_geo.mesh.surface_get_primitive_type(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if verts == null or verts.is_empty():
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		var new_verts := PackedVector3Array()
		new_verts.resize(verts.size())

		for i in range(verts.size()):
			var pt: Vector3 = verts[i]
			# Find nearest triangle
			var best_dist: float = INF
			var best_tri: int = -1
			var num_tris: int = tri_normals.size()
			for t in range(num_tris):
				var center: Vector3 = (tri_verts[t * 3] + tri_verts[t * 3 + 1] + tri_verts[t * 3 + 2]) / 3.0
				var d: float = pt.distance_squared_to(center)
				if d < best_dist:
					best_dist = d
					best_tri = t

			if best_tri < 0:
				new_verts[i] = pt
				continue

			var n: Vector3 = tri_normals[best_tri]
			var t0: Vector3 = tri_verts[best_tri * 3]
			var t1: Vector3 = tri_verts[best_tri * 3 + 1]
			var edge: Vector3 = (t1 - t0).normalized()
			var tangent_u: Vector3 = edge
			var tangent_v: Vector3 = n.cross(tangent_u).normalized()

			# Project point onto triangle plane
			var proj: Vector3 = pt - n * n.dot(pt - t0)

			var move_dir: Vector3
			match dir_mode:
				0: move_dir = n
				1: move_dir = tangent_u
				2: move_dir = tangent_v
				3:
					var angle: float = _rng.randf() * TAU
					move_dir = (tangent_u * cos(angle) + tangent_v * sin(angle)).normalized()
				_: move_dir = n

			new_verts[i] = proj + move_dir * dist

		arrays[Mesh.ARRAY_VERTEX] = new_verts
		new_mesh.add_surface_from_arrays(prim, arrays)

	geo.set_mesh(new_mesh)
	return geo
