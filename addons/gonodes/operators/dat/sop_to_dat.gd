class_name SOPtoDAT
extends GNDatBase
## Converts SOP geometry information into a DAT table.
## Points mode outputs per-vertex attributes; Summary mode outputs mesh metadata.


func _init() -> void:
	node_type = "sop_to_dat"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "SOP geometry input", "In")
	add_output("out", GNFamily.Type.DAT, "Geometry data table", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("attribute",
		PackedStringArray(["Points", "Summary"]), 0,
		"Attribute", "What data to extract from the geometry"))
	add_parameter(GNParameter.create_int("max_points", 1000, 1, 100000,
		"Max Points", "Maximum number of points to output (Points mode)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_table()
	out.is_table = true
	out.has_header = true

	if inputs.size() == 0 or not (inputs[0] is GNGeoData):
		GNLogger.warn("SOPtoDAT", "No valid SOP input connected.")
		return out

	var geo: GNGeoData = inputs[0] as GNGeoData
	if geo.mesh == null or geo.mesh.get_surface_count() == 0:
		out.set_headers(PackedStringArray(["attribute", "value"]))
		out.append_row(PackedStringArray(["vertex_count", "0"]))
		return out

	var mode: int = get_param_value("attribute")

	if mode == 0:
		# ── Points mode ─────────────────────────────────────────────────────
		_extract_points(geo, out)
	else:
		# ── Summary mode ────────────────────────────────────────────────────
		_extract_summary(geo, out)

	return out


## Extracts per-vertex data: position, normal, UV into a table.
func _extract_points(geo: GNGeoData, tbl: GNTableData) -> void:
	tbl.set_headers(PackedStringArray(["px", "py", "pz", "nx", "ny", "nz", "u", "v"]))
	var max_pts: int = get_param_value("max_points")
	var total_output: int = 0

	for surf_idx in range(geo.mesh.get_surface_count()):
		if total_output >= max_pts:
			break
		var arrays: Array = geo.mesh.surface_get_arrays(surf_idx)
		if arrays.is_empty():
			continue

		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] if arrays[Mesh.ARRAY_VERTEX] != null else PackedVector3Array()
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays.size() > Mesh.ARRAY_NORMAL and arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays.size() > Mesh.ARRAY_TEX_UV and arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()

		for v in range(positions.size()):
			if total_output >= max_pts:
				break
			var pos: Vector3 = positions[v]
			var nrm := Vector3.ZERO
			if v < normals.size():
				nrm = normals[v]
			var uv := Vector2.ZERO
			if v < uvs.size():
				uv = uvs[v]

			tbl.append_row(PackedStringArray([
				"%.6f" % pos.x, "%.6f" % pos.y, "%.6f" % pos.z,
				"%.6f" % nrm.x, "%.6f" % nrm.y, "%.6f" % nrm.z,
				"%.6f" % uv.x, "%.6f" % uv.y
			]))
			total_output += 1


## Extracts mesh summary metadata into a key-value table.
func _extract_summary(geo: GNGeoData, tbl: GNTableData) -> void:
	tbl.set_headers(PackedStringArray(["attribute", "value"]))

	tbl.append_row(PackedStringArray(["vertex_count", str(geo.vertex_count)]))
	tbl.append_row(PackedStringArray(["surface_count", str(geo.mesh.get_surface_count())]))

	var aabb: AABB = geo.bounds
	tbl.append_row(PackedStringArray(["aabb_min",
		"%.3f, %.3f, %.3f" % [aabb.position.x, aabb.position.y, aabb.position.z]]))
	tbl.append_row(PackedStringArray(["aabb_max",
		"%.3f, %.3f, %.3f" % [aabb.end.x, aabb.end.y, aabb.end.z]]))
	tbl.append_row(PackedStringArray(["aabb_size",
		"%.3f, %.3f, %.3f" % [aabb.size.x, aabb.size.y, aabb.size.z]]))

	# Per-surface info
	for s in range(geo.mesh.get_surface_count()):
		var arrays: Array = geo.mesh.surface_get_arrays(s)
		var vert_count: int = 0
		if not arrays.is_empty() and arrays[Mesh.ARRAY_VERTEX] != null:
			vert_count = arrays[Mesh.ARRAY_VERTEX].size()
		tbl.append_row(PackedStringArray(["surface_%d_vertices" % s, str(vert_count)]))
