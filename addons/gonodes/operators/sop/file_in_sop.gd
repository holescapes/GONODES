class_name FileInSOP
extends GNSopBase
## Imports geometry from a file (OBJ, glTF, or Godot .tres/.res).
## Uses Godot's ResourceLoader for glTF/.tres, and manual parsing for OBJ.
##
## The **file** parameter also accepts HTTP/HTTPS URLs.  When a URL is provided,
## the file is fetched asynchronously via GNUrlCache, cached on disk, and loaded
## on the next cook once the download completes.

## Tracks the last URL that was resolved, to avoid spamming fetch requests.
var _last_url: String = ""


func _init() -> void:
	node_type = "file_in"
	thread_safe = false  # URL fetching uses HTTPRequest / scene tree


## Local filesystem access — not available on web.
func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux", "android", "ios"])


func _init_ports() -> void:
	add_output("out", GNFamily.Type.SOP, "Imported geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_file("file", "Path to the file",
		PackedStringArray(["*.obj", "*.glb", "*.gltf", "*.tres", "*.res"]),
		"File", "Path to geometry file (OBJ, glTF, .tres, .res)"))
	add_parameter(GNParameter.create_bool("reload", false, "Reload",
		"Pulse to force reload"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var geo: GNGeoData = _prepare_geo()
	var path: String = get_param_value("file").strip_edges()
	if path.is_empty():
		return geo

	# URL support — fetch via cache, cook with local path once ready
	if GNUrlCache.is_url(path):
		var result: Dictionary = GNUrlCache.resolve_url(path, self)
		match result.status:
			"ready":
				path = result.path
			"pending":
				return geo  # placeholder until download completes
			"error":
				GNLogger.warn("FileInSOP", "'%s' — URL fetch error: %s" % [id, result.error])
				return geo
	else:
		# Resolve project:// and other path tiers to absolute
		path = GNResourceLoader.resolve(path, project_dir)
		if path.is_empty():
			return geo

	var ext: String = path.get_extension().to_lower()

	match ext:
		"obj":
			_load_obj(path, geo)
		"glb", "gltf":
			_load_gltf(path, geo)
		"tres", "res":
			_load_resource(path, geo)
		_:
			GNLogger.warn("FileInSOP", "'%s' — unsupported extension '%s'" % [id, ext])

	return geo


func _load_obj(path: String, geo: GNGeoData) -> void:
	if not FileAccess.file_exists(path):
		GNLogger.warn("FileInSOP", "'%s' — file not found '%s'" % [id, path])
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		GNLogger.warn("FileInSOP", "'%s' — cannot open '%s'" % [id, path])
		return

	var positions: PackedVector3Array = PackedVector3Array()
	var tex_coords: PackedVector2Array = PackedVector2Array()
	var normals_src: PackedVector3Array = PackedVector3Array()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_faces := false

	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue

		var parts: PackedStringArray = line.split(" ", false)
		if parts.size() < 2:
			continue

		match parts[0]:
			"v":
				if parts.size() >= 4:
					positions.append(Vector3(
						parts[1].to_float(), parts[2].to_float(), parts[3].to_float()))
			"vt":
				if parts.size() >= 3:
					tex_coords.append(Vector2(parts[1].to_float(), parts[2].to_float()))
			"vn":
				if parts.size() >= 4:
					normals_src.append(Vector3(
						parts[1].to_float(), parts[2].to_float(), parts[3].to_float()))
			"f":
				has_faces = true
				var face_verts: Array[Dictionary] = []
				for i in range(1, parts.size()):
					var indices := parts[i].split("/")
					var vi: int = indices[0].to_int() - 1
					var ti: int = -1
					var ni: int = -1
					if indices.size() > 1 and not indices[1].is_empty():
						ti = indices[1].to_int() - 1
					if indices.size() > 2 and not indices[2].is_empty():
						ni = indices[2].to_int() - 1
					face_verts.append({"v": vi, "vt": ti, "vn": ni})

				# Triangulate (fan from first vertex)
				for i in range(1, face_verts.size() - 1):
					for idx in [0, i, i + 1]:
						var fv: Dictionary = face_verts[idx]
						if fv["vn"] >= 0 and fv["vn"] < normals_src.size():
							st.set_normal(normals_src[fv["vn"]])
						if fv["vt"] >= 0 and fv["vt"] < tex_coords.size():
							st.set_uv(tex_coords[fv["vt"]])
						if fv["v"] >= 0 and fv["v"] < positions.size():
							st.add_vertex(positions[fv["v"]])

	file.close()

	if has_faces:
		if normals_src.is_empty():
			st.generate_normals()
		st.generate_tangents()
		var arr_mesh := ArrayMesh.new()
		st.commit(arr_mesh)
		geo.set_mesh(arr_mesh)


func _load_gltf(path: String, geo: GNGeoData) -> void:
	if not FileAccess.file_exists(path):
		GNLogger.warn("FileInSOP", "'%s' — file not found '%s'" % [id, path])
		return

	var gltf_doc := GLTFDocument.new()
	var gltf_state := GLTFState.new()
	var err: int = gltf_doc.append_from_file(path, gltf_state)
	if err != OK:
		GNLogger.warn("FileInSOP", "'%s' — failed to load glTF '%s'" % [id, path])
		return

	var scene: Node = gltf_doc.generate_scene(gltf_state)
	if scene == null:
		return

	# Find first MeshInstance3D
	var mesh_inst: MeshInstance3D = _find_mesh_instance(scene)
	if mesh_inst != null and mesh_inst.mesh is ArrayMesh:
		geo.set_mesh(mesh_inst.mesh.duplicate() as ArrayMesh)
	elif mesh_inst != null:
		var st := SurfaceTool.new()
		st.create_from(mesh_inst.mesh, 0)
		var arr_mesh := ArrayMesh.new()
		st.commit(arr_mesh)
		geo.set_mesh(arr_mesh)

	scene.queue_free()


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var result: MeshInstance3D = _find_mesh_instance(child)
		if result != null:
			return result
	return null


func _load_resource(path: String, geo: GNGeoData) -> void:
	var res = ResourceLoader.load(path)
	if res is ArrayMesh:
		geo.set_mesh(res.duplicate() as ArrayMesh)
	elif res is Mesh:
		var st := SurfaceTool.new()
		st.create_from(res, 0)
		var arr_mesh := ArrayMesh.new()
		st.commit(arr_mesh)
		geo.set_mesh(arr_mesh)
	else:
		GNLogger.warn("FileInSOP", "'%s' — resource is not a Mesh" % [id])
