class_name MeasureSOP
extends GNSopBase
## Measures geometric properties of input geometry.
## Outputs per-primitive area, perimeter and curvature as point attributes.
## Also sets aggregate values as point_attribs on the output.


func _init() -> void:
	node_type = "measure"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry to measure", "In")
	add_output("out", GNFamily.Type.SOP, "Geometry with measurement attributes", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("area", true,
		"Area", "Compute surface area"))
	add_parameter(GNParameter.create_bool("perimeter", true,
		"Perimeter", "Compute edge perimeter"))
	add_parameter(GNParameter.create_bool("curvature", false,
		"Curvature", "Compute mean curvature per vertex"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo := _require_input_geo(inputs)
	if in_geo == null:
		return null

	var geo := _prepare_geo()
	var do_area: bool = get_param_value("area")
	var do_perim: bool = get_param_value("perimeter")
	var do_curv: bool = get_param_value("curvature")

	var new_mesh := ArrayMesh.new()
	var total_area: float = 0.0
	var total_perim: float = 0.0

	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)
		new_mesh.add_surface_from_arrays(prim, arrays)

		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if verts == null or verts.is_empty():
			continue
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()

		if do_area and prim == Mesh.PRIMITIVE_TRIANGLES:
			total_area += _compute_area(verts, indices)

		if do_perim and prim == Mesh.PRIMITIVE_TRIANGLES:
			total_perim += _compute_perimeter(verts, indices)

	geo.set_mesh(new_mesh)

	if do_area:
		geo.point_attribs["total_area"] = PackedFloat32Array([total_area])
	if do_perim:
		geo.point_attribs["total_perimeter"] = PackedFloat32Array([total_perim])

	if do_curv and in_geo.mesh.get_surface_count() > 0:
		var arrays: Array = in_geo.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		if verts != null and normals.size() == verts.size():
			geo.point_attribs["curvature"] = _estimate_curvature(verts, normals)

	return geo


func _compute_area(verts: PackedVector3Array, indices: PackedInt32Array) -> float:
	var area: float = 0.0
	if indices.size() >= 3:
		for i in range(0, indices.size() - 2, 3):
			var v0: Vector3 = verts[indices[i]]
			var v1: Vector3 = verts[indices[i + 1]]
			var v2: Vector3 = verts[indices[i + 2]]
			area += (v1 - v0).cross(v2 - v0).length() * 0.5
	elif verts.size() >= 3:
		for i in range(0, verts.size() - 2, 3):
			area += (verts[i + 1] - verts[i]).cross(verts[i + 2] - verts[i]).length() * 0.5
	return area


func _compute_perimeter(verts: PackedVector3Array, indices: PackedInt32Array) -> float:
	var edges: Dictionary = {}
	var add_edge := func(a: int, b: int) -> void:
		var key: int = mini(a, b) * 100000 + maxi(a, b)
		if not edges.has(key):
			edges[key] = verts[a].distance_to(verts[b])

	if indices.size() >= 3:
		for i in range(0, indices.size() - 2, 3):
			add_edge.call(indices[i], indices[i + 1])
			add_edge.call(indices[i + 1], indices[i + 2])
			add_edge.call(indices[i + 2], indices[i])
	var total: float = 0.0
	for e in edges.values():
		total += e
	return total


func _estimate_curvature(verts: PackedVector3Array, normals: PackedVector3Array) -> PackedFloat32Array:
	var curvature := PackedFloat32Array()
	curvature.resize(verts.size())
	for i in range(verts.size()):
		# Simple curvature estimate: divergence of normals to neighbors
		var c: float = 0.0
		var count: int = 0
		for j in range(verts.size()):
			if i == j:
				continue
			var dist: float = verts[i].distance_to(verts[j])
			if dist < 0.001:
				continue
			if dist < 0.5:
				c += (1.0 - normals[i].dot(normals[j])) / dist
				count += 1
		curvature[i] = c / maxf(float(count), 1.0)
	return curvature
