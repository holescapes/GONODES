class_name FileOutSOP
extends GNSopBase
## Exports input geometry to an OBJ file on disk.
## Reads ArrayMesh surfaces and writes standard Wavefront OBJ.

func _init() -> void:
	node_type = "file_out"
	node_description = "Export geometry to a Wavefront OBJ file."


## Local filesystem access — not available on web.
func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux", "android", "ios"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Geometry to export")
	add_output("out", GNFamily.Type.SOP, "Pass-through geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_file("file", "",
		PackedStringArray(["*.obj"]),
		"File", "Output file path (.obj)"))
	add_parameter(GNParameter.create_bool("write", false, "Write",
		"Pulse to export current geometry"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = _get_input_sop(inputs, 0)
	if in_geo == null or not in_geo.has_geometry():
		return _prepare_geo()

	var do_write: bool = get_param_value("write")
	if do_write:
		var path: String = get_param_value("file").strip_edges()
		if not path.is_empty():
			_export_obj(in_geo, path)

	# Pass-through
	return in_geo


func _export_obj(geo: GNGeoData, path: String) -> void:
	var dir_path: String = path.get_base_dir()
	if not dir_path.is_empty():
		DirAccess.make_dir_recursive_absolute(dir_path)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		GNLogger.warn("FileOutSOP", "'%s' — cannot open '%s' for writing" % [id, path])
		return

	file.store_line("# Exported by GONODES FileOutSOP")

	var vertex_offset: int = 0
	var normal_offset: int = 0
	var uv_offset: int = 0

	for s in range(geo.mesh.get_surface_count()):
		var arrays: Array = geo.mesh.surface_get_arrays(s)
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
			continue

		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()

		file.store_line("g surface_%d" % s)

		# Vertices
		for v in verts:
			file.store_line("v %.6f %.6f %.6f" % [v.x, v.y, v.z])

		# Normals
		for n in normals:
			file.store_line("vn %.6f %.6f %.6f" % [n.x, n.y, n.z])

		# UVs
		for uv in uvs:
			file.store_line("vt %.6f %.6f" % [uv.x, uv.y])

		# Faces
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var has_normals: bool = not normals.is_empty()
		var has_uvs: bool = not uvs.is_empty()

		if indices.is_empty():
			# Non-indexed: every 3 verts is a triangle
			for i in range(0, verts.size(), 3):
				var face_str := "f"
				for j in range(3):
					var vi: int = vertex_offset + i + j + 1
					face_str += " " + _format_face_index(vi,
						(uv_offset + i + j + 1) if has_uvs else -1,
						(normal_offset + i + j + 1) if has_normals else -1)
				file.store_line(face_str)
		else:
			for i in range(0, indices.size(), 3):
				var face_str := "f"
				for j in range(3):
					var idx: int = indices[i + j]
					var vi: int = vertex_offset + idx + 1
					face_str += " " + _format_face_index(vi,
						(uv_offset + idx + 1) if has_uvs else -1,
						(normal_offset + idx + 1) if has_normals else -1)
				file.store_line(face_str)

		vertex_offset += verts.size()
		normal_offset += normals.size()
		uv_offset += uvs.size()

	file.close()
	GNLogger.info("FileOutSOP", "'%s' — exported to '%s'" % [id, path])


func _format_face_index(vi: int, ti: int, ni: int) -> String:
	if ti > 0 and ni > 0:
		return "%d/%d/%d" % [vi, ti, ni]
	elif ti > 0:
		return "%d/%d" % [vi, ti]
	elif ni > 0:
		return "%d//%d" % [vi, ni]
	return str(vi)
