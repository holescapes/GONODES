class_name GNGeoData
extends GNData
## Output data type for SOP operators.
## Wraps Godot's ArrayMesh — leveraging the engine's native mesh system
## for full compatibility with the renderer, physics, and instancing.
## RefCounted (inherits from GNData) — transient compute result.

## The generated mesh. Uses Godot's ArrayMesh which supports:
## - Multiple surfaces (sub-meshes with different materials)
## - All primitive types (triangles, lines, points)
## - Vertex attributes: position, normal, tangent, UV, UV2, color, bones, weights
## - Custom data channels via CUSTOM0–CUSTOM3
var mesh: ArrayMesh = null

## Optional transform applied to this geometry (local space).
var transform: Transform3D = Transform3D.IDENTITY

## Bounding box of the mesh (cached after build).
var bounds: AABB = AABB()

## Number of vertices across all surfaces.
var vertex_count: int = 0

## Optional point attribute data (SOP-style per-point attributes beyond mesh data).
## Maps attribute name → PackedFloat32Array (one value per vertex).
## Useful for CHOP↔SOP bridging (e.g., color-per-point from CHOP channels).
var point_attribs: Dictionary = {}


func get_family() -> int:
	return GNFamily.Type.SOP


func get_preview_text() -> String:
	if has_geometry() and mesh != null:
		var verts: int = 0
		var surfs: int = mesh.get_surface_count()
		for s in range(surfs):
			var arrays: Array = mesh.surface_get_arrays(s)
			if arrays[Mesh.ARRAY_VERTEX] != null:
				verts += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		return "%d verts\n%d surfaces" % [verts, surfs]
	return "no geo"


func get_data_summary() -> String:
	return "%dv" % vertex_count


# ─── Mesh Building Helpers ─────────────────────────────────────────────────────

## Creates the mesh from Godot SurfaceTool arrays.
## [param primitive] — Mesh.PrimitiveType (TRIANGLES, LINES, POINTS, etc.)
## [param arrays] — the standard Godot mesh array format (Mesh.ARRAY_* indexed).
func set_surface_arrays(primitive: Mesh.PrimitiveType, arrays: Array) -> void:
	if mesh == null:
		mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(primitive, arrays)
	_update_stats()


## Builds the mesh from a SurfaceTool (handles normals, tangents, index generation).
func set_from_surface_tool(st: SurfaceTool) -> void:
	if mesh == null:
		mesh = ArrayMesh.new()
	st.commit(mesh)
	_update_stats()


## Replaces the mesh entirely with a new ArrayMesh.
func set_mesh(new_mesh: ArrayMesh) -> void:
	mesh = new_mesh
	_update_stats()


## Clears all surfaces from the mesh.
func clear() -> void:
	if mesh != null:
		mesh.clear_surfaces()
	vertex_count = 0
	bounds = AABB()
	point_attribs.clear()


# ─── Accessors ─────────────────────────────────────────────────────────────────

## Returns true if the mesh has at least one surface with vertices.
func has_geometry() -> bool:
	return mesh != null and mesh.get_surface_count() > 0


## Returns the number of surfaces (sub-meshes) in the mesh.
func get_surface_count() -> int:
	if mesh == null:
		return 0
	return mesh.get_surface_count()


## Returns the raw arrays for a surface (for reading vertex data).
func get_surface_arrays(surface_idx: int = 0) -> Array:
	if mesh == null or surface_idx >= mesh.get_surface_count():
		return []
	return mesh.surface_get_arrays(surface_idx)


## Returns vertex positions for a surface as PackedVector3Array.
func get_positions(surface_idx: int = 0) -> PackedVector3Array:
	var arrays: Array = get_surface_arrays(surface_idx)
	if arrays.is_empty():
		return PackedVector3Array()
	var _ret0 := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	return _ret0


## Returns vertex normals for a surface as PackedVector3Array.
func get_normals(surface_idx: int = 0) -> PackedVector3Array:
	var arrays: Array = get_surface_arrays(surface_idx)
	if arrays.is_empty() or arrays[Mesh.ARRAY_NORMAL] == null:
		return PackedVector3Array()
	var _ret0 := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	return _ret0


## Returns UV coordinates for a surface as PackedVector2Array.
func get_uvs(surface_idx: int = 0) -> PackedVector2Array:
	var arrays: Array = get_surface_arrays(surface_idx)
	if arrays.is_empty() or arrays[Mesh.ARRAY_TEX_UV] == null:
		return PackedVector2Array()
	var _ret0 := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	return _ret0


# ─── Point Attributes (SOP-style) ─────────────────────────────────────────────

## Sets a per-vertex float attribute.
func set_point_attrib(attrib_name: String, values: PackedFloat32Array) -> void:
	point_attribs[attrib_name] = values


## Gets a per-vertex float attribute, or empty array if not found.
func get_point_attrib(attrib_name: String) -> PackedFloat32Array:
	return point_attribs.get(attrib_name, PackedFloat32Array())


## Gets a per-vertex color attribute.  Reads from the mesh COLOR array if
## [param attrib_name] is "Cd" and no explicit attrib exists.  Also handles
## packed float arrays with 3 or 4 floats per vertex (r,g,b or r,g,b,a).
func get_point_attrib_color(attrib_name: String) -> PackedColorArray:
	var stored: Variant = point_attribs.get(attrib_name, null)
	if stored is PackedColorArray:
		var _ret0 := stored as PackedColorArray
		return _ret0
	if stored is PackedFloat32Array:
		var fa := stored as PackedFloat32Array
		var vc: int = vertex_count if vertex_count > 0 else 1
		var result := PackedColorArray()
		if fa.size() >= vc * 4:
			for i in range(vc):
				result.append(Color(fa[i * 4], fa[i * 4 + 1], fa[i * 4 + 2], fa[i * 4 + 3]))
		elif fa.size() >= vc * 3:
			for i in range(vc):
				result.append(Color(fa[i * 3], fa[i * 3 + 1], fa[i * 3 + 2], 1.0))
		return result
	# Fall back to mesh COLOR array for "Cd"
	if attrib_name == "Cd" and mesh != null:
		for s in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(s)
			if arrays.size() > Mesh.ARRAY_COLOR and arrays[Mesh.ARRAY_COLOR] != null:
				var _ret1 := arrays[Mesh.ARRAY_COLOR] as PackedColorArray
				return _ret1
	return PackedColorArray()


# ─── Duplication ───────────────────────────────────────────────────────────────

func invalidate() -> void:
	super.invalidate()
	mesh = null
	vertex_count = 0
	bounds = AABB()
	point_attribs.clear()

# ─── Expression Access ────────────────────────────────────────────────────────────────

func get_expression_value(key: String, _index: int = -1) -> Variant:
	match key:
		"npoints", "vertex_count":
			return vertex_count
		"nprims", "surfaces":
			return get_surface_count()
		"has_geo":
			return 1.0 if has_geometry() else 0.0
		"bounds_size_x":
			return bounds.size.x
		"bounds_size_y":
			return bounds.size.y
		"bounds_size_z":
			return bounds.size.z
		"bounds_center_x":
			return bounds.get_center().x
		"bounds_center_y":
			return bounds.get_center().y
		"bounds_center_z":
			return bounds.get_center().z
		"attrib_count":
			return point_attribs.size()
	return 0.0


func get_expression_info() -> Dictionary:
	return {
		"npoints": vertex_count,
		"nprims": get_surface_count(),
		"has_geo": has_geometry(),
		"bounds_size_x": bounds.size.x,
		"bounds_size_y": bounds.size.y,
		"bounds_size_z": bounds.size.z,
		"bounds_center_x": bounds.get_center().x,
		"bounds_center_y": bounds.get_center().y,
		"bounds_center_z": bounds.get_center().z,
		"attrib_count": point_attribs.size(),
	}


func get_completions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in ["npoints", "nprims", "has_geo",
			"bounds_size_x", "bounds_size_y", "bounds_size_z",
			"bounds_center_x", "bounds_center_y", "bounds_center_z",
			"attrib_count"]:
		result.append({"label": key, "kind": "member"})
	for attrib_name in point_attribs:
		result.append({"label": attrib_name, "kind": "member"})
	return result

func duplicate_data() -> GNData:
	var copy := GNGeoData.new()
	copy.valid = valid
	copy.timestamp = timestamp
	copy.metadata = metadata.duplicate(true)
	copy.transform = transform
	copy.bounds = bounds
	copy.vertex_count = vertex_count
	# Duplicate mesh (Godot Resource.duplicate handles this)
	if mesh != null:
		copy.mesh = mesh.duplicate() as ArrayMesh
	# Deep copy point attribs
	for key in point_attribs:
		copy.point_attribs[key] = point_attribs[key].duplicate()
	return copy


func get_export_filters() -> Array[Dictionary]:
	return [
		{"filter": "*.glb", "description": "glTF Binary (mesh only)"},
	]


func export_to_file(path: String) -> Error:
	if mesh == null:
		return ERR_INVALID_DATA
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = mesh
	mesh_inst.transform = transform
	var tmp_root := Node3D.new()
	tmp_root.name = "ExportRoot"
	tmp_root.add_child(mesh_inst)
	mesh_inst.owner = tmp_root
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(tmp_root, state)
	if err == OK:
		err = doc.write_to_filesystem(state, path)
	tmp_root.remove_child(mesh_inst)
	mesh_inst.free()
	tmp_root.free()
	return err


# ─── Internal ──────────────────────────────────────────────────────────────────

## Updates vertex count and bounding box from the current mesh.
func _update_stats() -> void:
	if mesh == null:
		vertex_count = 0
		bounds = AABB()
		return
	bounds = mesh.get_aabb()
	vertex_count = 0
	for i in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(i)
		if not arrays.is_empty() and arrays[Mesh.ARRAY_VERTEX] != null:
			vertex_count += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
