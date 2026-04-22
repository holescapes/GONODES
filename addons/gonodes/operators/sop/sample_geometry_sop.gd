class_name SampleGeometrySOP
extends GNSopBase
## Built-in sample geometry for quick prototyping and testing.
## Bundles iconic CG test meshes so no external files needed.
##
## Samples:
##   Suzanne  — Blender monkey head. UV-mapped, textured (CC0).
##   Fox      — Animated quadruped. Rigged skeleton with Survey/Walk/Run
##              animation cycles, textured (CC0 model, CC BY 4.0 rig).
##   Duck     — Classic glTF rubber duck. Textured (SCEA license).
##   Teapot   — Utah Teapot (Martin Newell, 1975). Geometry only — no UVs,
##              no texture, no rig. The original CG benchmark (public domain).
##   Damaged Helmet — Battle-worn sci-fi helmet. Full PBR material set
##              (base color, normal, emissive, occlusion, metallic-roughness).
##              Great for material/lighting tests (CC BY 3.0).

const SAMPLE_DIR := "res://assets/samples/meshes/"

## Enum values must match the order in _init_parameters.
enum Sample { SUZANNE, FOX, DUCK, TEAPOT, DAMAGED_HELMET }

const SAMPLE_PATHS: Dictionary = {
	Sample.SUZANNE: "suzanne/Suzanne.gltf",
	Sample.FOX: "fox.glb",
	Sample.DUCK: "duck.glb",
	Sample.TEAPOT: "teapot.glb",
	Sample.DAMAGED_HELMET: "damaged_helmet.glb",
}

var _loaded_sample: int = -1


func _init() -> void:
	node_type = "sample_geometry"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.SOP, "Sample geometry output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("sample",
		["Suzanne", "Fox", "Duck", "Teapot", "Damaged Helmet"],
		Sample.SUZANNE, "Sample", "Which built-in sample mesh to output"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var sample_idx: int = get_param_value("sample")

	# Re-use cached mesh if same selection.
	if sample_idx == _loaded_sample and _cached_geo != null and _cached_geo.has_geometry():
		return _cached_geo

	var geo: GNGeoData = _prepare_geo()
	var rel_path: String = SAMPLE_PATHS.get(sample_idx, "")
	if rel_path.is_empty():
		return geo

	var path: String = SAMPLE_DIR + rel_path
	if not FileAccess.file_exists(path):
		node_warning = "Sample mesh not found: %s" % path
		return geo

	var ext: String = path.get_extension().to_lower()
	if ext == "glb" or ext == "gltf":
		_load_gltf(path, geo)
	else:
		node_warning = "Unsupported sample format: %s" % ext
		return geo

	_loaded_sample = sample_idx
	node_warning = ""
	return geo


func _load_gltf(path: String, geo: GNGeoData) -> void:
	var gltf_doc := GLTFDocument.new()
	var gltf_state := GLTFState.new()
	var err: int = gltf_doc.append_from_file(path, gltf_state)
	if err != OK:
		node_warning = "Failed to load glTF: %s" % path
		return

	var scene: Node = gltf_doc.generate_scene(gltf_state)
	if scene == null:
		return

	var mesh_inst: MeshInstance3D = _find_mesh_instance(scene)
	if mesh_inst == null:
		scene.queue_free()
		return

	var src_mesh: Mesh = mesh_inst.mesh
	# Build a single ArrayMesh from all surfaces.
	var arr_mesh := ArrayMesh.new()
	for s in range(src_mesh.get_surface_count()):
		var st := SurfaceTool.new()
		st.create_from(src_mesh, s)
		st.commit(arr_mesh)
		# Preserve material per surface.
		var mat: Material = src_mesh.surface_get_material(s)
		if mat != null:
			arr_mesh.surface_set_material(arr_mesh.get_surface_count() - 1, mat)

	# Normalize: center at origin and fit inside a 2-unit bounding cube.
	_normalize_mesh(arr_mesh)
	geo.set_mesh(arr_mesh)
	scene.queue_free()


## Centers the mesh at the origin and uniformly scales it so the longest
## axis of the AABB is exactly TARGET_SIZE units.  This ensures all sample
## meshes appear at a consistent size in the viewport.
const TARGET_SIZE := 2.0

static func _normalize_mesh(mesh: ArrayMesh) -> ArrayMesh:
	var aabb := mesh.get_aabb()
	if aabb.size.is_zero_approx():
		return mesh

	var center := aabb.get_center()
	var longest := maxf(maxf(aabb.size.x, aabb.size.y), aabb.size.z)
	var scale_factor := TARGET_SIZE / longest
	var offset := -center * scale_factor

	# Collect transformed surface data, then rebuild the mesh from scratch.
	var surface_count := mesh.get_surface_count()
	var surfaces: Array = []
	for s in range(surface_count):
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in range(verts.size()):
			verts[i] = verts[i] * scale_factor + offset
		arrays[Mesh.ARRAY_VERTEX] = verts
		surfaces.append({
			"arrays": arrays,
			"format": mesh.surface_get_format(s),
			"material": mesh.surface_get_material(s),
		})

	mesh.clear_surfaces()
	for surf in surfaces:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
			surf["arrays"], [], {}, surf["format"])
		if surf["material"] != null:
			mesh.surface_set_material(mesh.get_surface_count() - 1, surf["material"])
	return mesh


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var result: MeshInstance3D = _find_mesh_instance(child)
		if result != null:
			return result
	return null
