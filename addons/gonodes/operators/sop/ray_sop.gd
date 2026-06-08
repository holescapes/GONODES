class_name RaySOP
extends GNSopBase
## Project vertices from one mesh onto the surface of another via raycasting.
## Uses Godot's PhysicsServer3D for GPU-accelerated ray intersection.
##
## Input 0: Source geometry (vertices to project)
## Input 1: Target geometry (surface to project onto)
##
## Each source vertex is cast along its projection axis (or normal) toward
## the target. If a hit is found, the vertex snaps to the hit point.

func _init() -> void:
	node_type = "ray"


func _init_ports() -> void:
	add_input("source", GNFamily.Type.SOP, false, "Source geometry (vertices to project)", "Source")
	add_input("target", GNFamily.Type.SOP, false, "Target surface (project onto)", "Target")
	add_output("out", GNFamily.Type.SOP, "Projected geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("direction",
		PackedStringArray(["Along Normal", "-Y (Down)", "+Y (Up)", "-Z (Forward)", "+Z (Back)", "-X (Left)", "+X (Right)"]),
		0, "Direction", "Ray cast direction per vertex"))
	add_parameter(GNParameter.create_float("max_dist", 100.0, 0.1, 10000.0, 0.1,
		"Max Distance", "Maximum ray length"))
	add_parameter(GNParameter.create_float("offset", 0.0, -10.0, 10.0, 0.001,
		"Offset", "Distance above the hit surface along the hit normal"))
	add_parameter(GNParameter.create_bool("use_hit_normal", true,
		"Use Hit Normal", "Replace vertex normals with the surface hit normal"))


func _cook(inputs: Array[GNData]) -> GNData:
	var src_geo: GNGeoData = _get_input_sop(inputs, 0)
	var tgt_geo: GNGeoData = _get_input_sop(inputs, 1)
	if src_geo == null or not src_geo.has_geometry():
		return null
	if tgt_geo == null or not tgt_geo.has_geometry():
		# No target — pass through source unchanged
		return src_geo

	var dir_mode: int = get_param_value("direction")
	var max_dist: float = get_param_value("max_dist")
	var offset_val: float = get_param_value("offset")
	var use_hit_n: bool = get_param_value("use_hit_normal")

	# Build target collision mesh for raycasting
	var tgt_mesh: ArrayMesh = tgt_geo.mesh
	if tgt_mesh == null:
		return src_geo

	var tgt_faces: PackedVector3Array = _extract_faces(tgt_geo)
	if tgt_faces.is_empty():
		return src_geo

	var output: GNGeoData = _prepare_geo()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for surf_idx in range(src_geo.get_surface_count()):
		var arrays: Array = src_geo.get_surface_arrays(surf_idx)
		if arrays.is_empty():
			continue
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals = arrays[Mesh.ARRAY_NORMAL]
		var uvs = arrays[Mesh.ARRAY_TEX_UV]

		for i in range(positions.size()):
			var pos: Vector3 = positions[i]
			var normal: Vector3 = normals[i] if normals != null and i < normals.size() else Vector3.UP

			var ray_dir: Vector3 = _get_ray_direction(dir_mode, normal)
			var hit: Dictionary = _raycast_triangles(pos, ray_dir, max_dist, tgt_faces)

			var out_pos: Vector3 = pos
			var out_normal: Vector3 = normal
			if not hit.is_empty():
				out_pos = hit["position"] + hit["normal"] * offset_val
				if use_hit_n:
					out_normal = hit["normal"]

			st.set_normal(out_normal)
			if uvs != null and i < uvs.size():
				st.set_uv(uvs[i])
			st.add_vertex(out_pos)

	st.generate_normals()
	output.set_from_surface_tool(st)
	return output


func _get_ray_direction(mode: int, vertex_normal: Vector3) -> Vector3:
	match mode:
		0: return -vertex_normal.normalized()  # Along (inverted) normal toward surface
		1: return Vector3.DOWN
		2: return Vector3.UP
		3: return Vector3.FORWARD
		4: return Vector3.BACK
		5: return Vector3.LEFT
		6: return Vector3.RIGHT
		_: return Vector3.DOWN


## CPU triangle intersection — Möller–Trumbore algorithm.
## Shoots a ray from origin in direction dir against all target triangles.
func _raycast_triangles(origin: Vector3, dir: Vector3, max_dist: float,
		faces: PackedVector3Array) -> Dictionary:
	var best_t: float = max_dist
	var best_hit: Dictionary = {}
	var eps: float = 1e-8

	var tri_count: int = faces.size() / 3
	for tri in range(tri_count):
		var v0: Vector3 = faces[tri * 3]
		var v1: Vector3 = faces[tri * 3 + 1]
		var v2: Vector3 = faces[tri * 3 + 2]

		var e1: Vector3 = v1 - v0
		var e2: Vector3 = v2 - v0
		var h: Vector3 = dir.cross(e2)
		var a: float = e1.dot(h)
		if absf(a) < eps:
			continue

		var f: float = 1.0 / a
		var s: Vector3 = origin - v0
		var u: float = f * s.dot(h)
		if u < 0.0 or u > 1.0:
			continue

		var q: Vector3 = s.cross(e1)
		var v: float = f * dir.dot(q)
		if v < 0.0 or u + v > 1.0:
			continue

		var t: float = f * e2.dot(q)
		if t > eps and t < best_t:
			best_t = t
			var hit_normal: Vector3 = e1.cross(e2).normalized()
			best_hit = {"position": origin + dir * t, "normal": hit_normal, "t": t}

	return best_hit


func _extract_faces(geo: GNGeoData) -> PackedVector3Array:
	var faces := PackedVector3Array()
	for surf_idx in range(geo.get_surface_count()):
		var arrays: Array = geo.get_surface_arrays(surf_idx)
		if arrays.is_empty():
			continue
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices = arrays[Mesh.ARRAY_INDEX]
		if indices != null and indices.size() > 0:
			for idx: int in indices:
				faces.append(positions[idx])
		else:
			faces.append_array(positions)
	return faces
