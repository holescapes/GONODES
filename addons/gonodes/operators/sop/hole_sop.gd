class_name HoleSOP
extends GNSopBase
## Cuts holes in planar polygon surfaces using a second input as the hole shape.
## Operates by removing triangles from the base mesh that fall inside the
## hole outline, effectively subtracting the hole profile from the surface.


func _init() -> void:
	node_type = "hole"


func _init_ports() -> void:
	add_input("base", GNFamily.Type.SOP, false, "Base surface geometry", "Base")
	add_input("hole", GNFamily.Type.SOP, false, "Hole profile geometry", "Hole")
	add_output("out", GNFamily.Type.SOP, "Surface with holes cut", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("plane",
		PackedStringArray(["XZ", "XY", "YZ"]), 0,
		"Plane", "2D projection plane for hole testing"))
	add_parameter(GNParameter.create_float("tolerance", 0.001, 0.0001, 1.0, 0.0001,
		"Tolerance", "Distance tolerance for inside testing"))
	add_parameter(GNParameter.create_bool("invert", false,
		"Invert", "Keep inside instead of outside"))


func _cook(inputs: Array[GNData]) -> GNData:
	var base_geo := _get_input_sop(inputs, 0)
	if base_geo == null or not base_geo.has_geometry():
		return null

	var hole_geo := _get_input_sop(inputs, 1)
	if hole_geo == null or not hole_geo.has_geometry():
		return base_geo

	var plane_idx: int = get_param_value("plane")
	var invert: bool = get_param_value("invert")

	# Extract hole outline vertices projected to 2D
	var hole_pts: PackedVector2Array = _extract_outline_2d(hole_geo, plane_idx)
	if hole_pts.is_empty():
		return base_geo

	var geo := _prepare_geo()
	var new_mesh := ArrayMesh.new()

	for s in range(base_geo.mesh.get_surface_count()):
		var arrays: Array = base_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = base_geo.mesh.surface_get_primitive_type(s)
		if prim != Mesh.PRIMITIVE_TRIANGLES:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if verts == null or verts.is_empty():
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		# Filter triangles based on their centroid being inside/outside hole
		var keep_indices := PackedInt32Array()
		if indices.size() >= 3:
			for i in range(0, indices.size() - 2, 3):
				var center: Vector3 = (verts[indices[i]] + verts[indices[i + 1]] + verts[indices[i + 2]]) / 3.0
				var pt_2d: Vector2 = _project_2d(center, plane_idx)
				var inside: bool = _point_in_polygon(pt_2d, hole_pts)
				if (inside and invert) or (not inside and not invert):
					keep_indices.append(indices[i])
					keep_indices.append(indices[i + 1])
					keep_indices.append(indices[i + 2])
		else:
			for i in range(0, verts.size() - 2, 3):
				var center: Vector3 = (verts[i] + verts[i + 1] + verts[i + 2]) / 3.0
				var pt_2d: Vector2 = _project_2d(center, plane_idx)
				var inside: bool = _point_in_polygon(pt_2d, hole_pts)
				if (inside and invert) or (not inside and not invert):
					keep_indices.append(i)
					keep_indices.append(i + 1)
					keep_indices.append(i + 2)

		if keep_indices.is_empty():
			continue

		arrays[Mesh.ARRAY_INDEX] = keep_indices
		new_mesh.add_surface_from_arrays(prim, arrays)

	geo.set_mesh(new_mesh)
	return geo


func _project_2d(v: Vector3, plane: int) -> Vector2:
	match plane:
		0: return Vector2(v.x, v.z)  # XZ
		1: return Vector2(v.x, v.y)  # XY
		_: return Vector2(v.y, v.z)  # YZ


func _extract_outline_2d(geo: GNGeoData, plane: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for s in range(geo.mesh.get_surface_count()):
		var arrays: Array = geo.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if verts == null:
			continue
		for v in verts:
			pts.append(_project_2d(v, plane))
	# Sort by angle from centroid for convex hull ordering
	if pts.is_empty():
		return pts
	var cx: float = 0.0
	var cy: float = 0.0
	for p in pts:
		cx += p.x
		cy += p.y
	cx /= float(pts.size())
	cy /= float(pts.size())
	var center := Vector2(cx, cy)

	var indexed: Array[Dictionary] = []
	for i in range(pts.size()):
		indexed.append({"angle": (pts[i] - center).angle(), "pt": pts[i]})
	indexed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["angle"] < b["angle"])

	var sorted := PackedVector2Array()
	for d in indexed:
		sorted.append(d["pt"])
	return sorted


func _point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	# Ray casting algorithm
	var n: int = polygon.size()
	if n < 3:
		return false
	var inside: bool = false
	var j: int = n - 1
	for i in range(n):
		var pi: Vector2 = polygon[i]
		var pj: Vector2 = polygon[j]
		if ((pi.y > point.y) != (pj.y > point.y)) and \
				(point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x):
			inside = not inside
		j = i
	return inside
