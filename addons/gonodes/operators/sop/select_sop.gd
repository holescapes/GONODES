class_name SelectSOP
extends GNSopBase
## Selects geometry from a SOP — by wire OR by wireless name reference.
##
## When the 'sop' parameter names a remote SOP, its output is used as
## the source (no wire needed).  When 'sop' is empty, the wired input is
## used instead.  Geometry filtering (range, bounding box, expression,
## every-Nth) applies in both modes.
##
## Matches TouchDesigner's Select SOP: remote reference + element filter.
##
## The complement of DeleteSOP — SelectSOP keeps matching geometry and
## discards the rest.
##
## Expression variables (per-element GDScript):
##   i     — element index (face or point)
##   x, y, z  — centroid (triangles) or vertex position (points)
##   count — total element count in the input
##
## Set "Invert" to discard matching elements and keep the rest.

var _network_cache: GNNetwork = null


func _init() -> void:
	node_type = "select"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry (used when 'sop' is empty)", "In")
	add_output("out", GNFamily.Type.SOP, "Selected geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_node_ref("sop", GNFamily.Type.SOP,
		"SOP", "Name (id) of a remote SOP to reference (empty = use wired input)"))
	add_parameter(GNParameter.create_enum("entity",
		PackedStringArray(["Triangles (Faces)", "Points"]), 0, "",
		"Select triangles or individual points"))
	add_parameter(GNParameter.create_enum("method",
		PackedStringArray(["By Range", "By Bounding Box", "By Expression", "Every Nth"]),
		0, "", "Selection criterion"))
	# Range params
	add_parameter(GNParameter.create_int("start", 0, 0, 999999, "Start Index",
		"First element index to keep (Range mode)"))
	add_parameter(GNParameter.create_int("end", 50, 0, 999999, "End Index",
		"Last element index to keep, inclusive (Range mode)"))
	# Bounding-box params
	add_parameter(GNParameter.create_float("bmin_x", -0.5, null, null, 0.01, "Box Min X", "The bmin x value"))
	add_parameter(GNParameter.create_float("bmin_y", -0.5, null, null, 0.01, "Box Min Y", "The bmin y value"))
	add_parameter(GNParameter.create_float("bmin_z", -0.5, null, null, 0.01, "Box Min Z", "The bmin z value"))
	add_parameter(GNParameter.create_float("bmax_x",  0.5, null, null, 0.01, "Box Max X", "The bmax x value"))
	add_parameter(GNParameter.create_float("bmax_y",  0.5, null, null, 0.01, "Box Max Y", "The bmax y value"))
	add_parameter(GNParameter.create_float("bmax_z",  0.5, null, null, 0.01, "Box Max Z", "The bmax z value"))
	# Expression param
	add_parameter(GNParameter.create_string("expression", "i % 2 == 0",
		"Expression", "GDScript expression returning bool. Variables: i, x, y, z, count"))
	# Every-Nth params
	add_parameter(GNParameter.create_int("step", 2, 1, 100,
		"Step (N)", "Keep every Nth element"))
	add_parameter(GNParameter.create_int("offset", 0, 0, 99,
		"Offset", "Starting offset within step cycle"))
	# Invert
	add_parameter(GNParameter.create_bool("invert", false, "Invert the output",
		"Invert selection (discard matching, keep non-matching)"))
	# Transform (remote reference only)
	add_parameter(GNParameter.create_bool("apply_transform", false,
		"Apply Transform", "Apply the source node's transform to output geometry (remote reference only)"))


func _cook(inputs: Array[GNData]) -> GNData:
	# Resolve source: wireless reference takes priority over wired input
	var in_geo: GNGeoData = null
	var remote_id: String = get_param_value("sop")

	if not remote_id.is_empty():
		in_geo = _resolve_remote_sop(remote_id)
	else:
		in_geo = _require_input_geo(inputs)

	if in_geo == null:
		if not remote_id.is_empty():
			node_warning = "Remote SOP '%s' not found or has no output" % remote_id
		return null

	node_warning = ""

	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var entity: int   = get_param_value("entity")
	var method: int   = get_param_value("method")
	var invert: bool  = get_param_value("invert")
	var new_mesh := ArrayMesh.new()

	for s in range(in_geo.mesh.get_surface_count()):
		var arrays = in_geo.mesh.surface_get_arrays(s)
		var prim   = in_geo.mesh.surface_get_primitive_type(s)

		if prim != Mesh.PRIMITIVE_TRIANGLES or arrays[Mesh.ARRAY_VERTEX] == null:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		if entity == 0:
			_select_faces(arrays, new_mesh, method, invert)
		else:
			_select_points(arrays, new_mesh, method, invert)

	_cached_geo.set_mesh(new_mesh)

	# Apply source transform if enabled and using remote reference
	if not remote_id.is_empty() and get_param_value("apply_transform"):
		_apply_source_transform(in_geo)

	return _cached_geo


## Returns true if element i at position pos should be KEPT (before invert).
func _should_keep(i: int, pos: Vector3, count: int, method: int) -> bool:
	match method:
		0:  # Range
			var s: int = get_param_value("start")
			var e: int = get_param_value("end")
			return i >= s and i <= e
		1:  # Bounding Box
			var bmin := Vector3(
				get_param_value("bmin_x"),
				get_param_value("bmin_y"),
				get_param_value("bmin_z"))
			var bmax := Vector3(
				get_param_value("bmax_x"),
				get_param_value("bmax_y"),
				get_param_value("bmax_z"))
			return (pos.x >= bmin.x and pos.x <= bmax.x and
					pos.y >= bmin.y and pos.y <= bmax.y and
					pos.z >= bmin.z and pos.z <= bmax.z)
		2:  # Expression
			var expr_str: String = get_param_value("expression")
			var expr := Expression.new()
			if expr.parse(expr_str, PackedStringArray(["i", "x", "y", "z", "count"])) == OK:
				var result = expr.execute([i, pos.x, pos.y, pos.z, count])
				if not expr.has_execute_failed():
					return bool(result)
			return false
		3:  # Every Nth
			var step: int   = maxi(1, get_param_value("step"))
			var offset: int = get_param_value("offset")
			return (i - offset) % step == 0
	return false


func _select_faces(arrays: Array, out_mesh: ArrayMesh, method: int, invert: bool) -> void:
	var verts:   PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]  if arrays[Mesh.ARRAY_NORMAL]  != null else PackedVector3Array()
	var uvs:     PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]  if arrays[Mesh.ARRAY_TEX_UV]  != null else PackedVector2Array()
	var indices: PackedInt32Array   = arrays[Mesh.ARRAY_INDEX]   if arrays[Mesh.ARRAY_INDEX]   != null else PackedInt32Array()

	if indices.is_empty():
		indices.resize(verts.size())
		for i in verts.size():
			indices[i] = i

	var tri_count: int = indices.size() / 3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for tri in range(tri_count):
		var i0: int = indices[tri * 3]
		var i1: int = indices[tri * 3 + 1]
		var i2: int = indices[tri * 3 + 2]
		var center: Vector3 = (verts[i0] + verts[i1] + verts[i2]) / 3.0

		var keep: bool = _should_keep(tri, center, tri_count, method)
		if invert:
			keep = not keep
		if not keep:
			continue

		for ci: int in [i0, i1, i2]:
			if normals.size() > ci:
				st.set_normal(normals[ci])
			if uvs.size() > ci:
				st.set_uv(uvs[ci])
			st.add_vertex(verts[ci])

	var mesh: ArrayMesh = st.commit()
	if mesh and mesh.get_surface_count() > 0:
		out_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
			mesh.surface_get_arrays(0))


func _select_points(arrays: Array, out_mesh: ArrayMesh, method: int, invert: bool) -> void:
	var verts:   PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]  if arrays[Mesh.ARRAY_NORMAL]  != null else PackedVector3Array()
	var uvs:     PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]  if arrays[Mesh.ARRAY_TEX_UV]  != null else PackedVector2Array()
	var indices: PackedInt32Array   = arrays[Mesh.ARRAY_INDEX]   if arrays[Mesh.ARRAY_INDEX]   != null else PackedInt32Array()

	var pt_count: int = verts.size()
	var keep_mask: Array[bool] = []
	keep_mask.resize(pt_count)
	for i in pt_count:
		var k: bool = _should_keep(i, verts[i], pt_count, method)
		keep_mask[i] = not k if invert else k

	# Build compact vertex arrays and a remap table.
	var remap: Array[int] = []
	remap.resize(pt_count)
	remap.fill(-1)
	var out_verts   := PackedVector3Array()
	var out_normals := PackedVector3Array()
	var out_uvs     := PackedVector2Array()

	for i in pt_count:
		if keep_mask[i]:
			remap[i] = out_verts.size()
			out_verts.push_back(verts[i])
			if normals.size() > i:
				out_normals.push_back(normals[i])
			if uvs.size() > i:
				out_uvs.push_back(uvs[i])

	if out_verts.is_empty():
		return

	# Rebuild triangle indices, dropping any face with a deleted vertex.
	var src_idx: PackedInt32Array = indices
	if src_idx.is_empty():
		src_idx.resize(verts.size())
		for i in verts.size():
			src_idx[i] = i

	var out_indices := PackedInt32Array()
	var t := 0
	while t + 2 < src_idx.size():
		var r0: int = remap[src_idx[t]]
		var r1: int = remap[src_idx[t + 1]]
		var r2: int = remap[src_idx[t + 2]]
		if r0 >= 0 and r1 >= 0 and r2 >= 0:
			out_indices.push_back(r0)
			out_indices.push_back(r1)
			out_indices.push_back(r2)
		t += 3

	if out_indices.is_empty():
		return

	var out_arrays: Array = []
	out_arrays.resize(Mesh.ARRAY_MAX)
	out_arrays[Mesh.ARRAY_VERTEX]  = out_verts
	out_arrays[Mesh.ARRAY_NORMAL]  = out_normals if not out_normals.is_empty() else null
	out_arrays[Mesh.ARRAY_TEX_UV]  = out_uvs     if not out_uvs.is_empty()     else null
	out_arrays[Mesh.ARRAY_INDEX]   = out_indices
	out_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out_arrays)


func _apply_source_transform(source_geo: GNGeoData) -> void:
	var xform := source_geo.transform
	if xform == Transform3D.IDENTITY:
		return
	var mesh := _cached_geo.mesh
	var new_mesh := ArrayMesh.new()
	var normal_basis := xform.basis.inverse().transposed()
	for surf_idx in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surf_idx)
		var prim := mesh.surface_get_primitive_type(surf_idx)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if verts.size() > 0:
			var transformed := PackedVector3Array()
			transformed.resize(verts.size())
			for i in range(verts.size()):
				transformed[i] = xform * verts[i]
			arrays[Mesh.ARRAY_VERTEX] = transformed
		if arrays[Mesh.ARRAY_NORMAL] != null:
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var transformed_n := PackedVector3Array()
			transformed_n.resize(normals.size())
			for i in range(normals.size()):
				transformed_n[i] = (normal_basis * normals[i]).normalized()
			arrays[Mesh.ARRAY_NORMAL] = transformed_n
		new_mesh.add_surface_from_arrays(prim, arrays)
	_cached_geo.set_mesh(new_mesh)


func _resolve_remote_sop(target_id: String) -> GNGeoData:
	if _network_cache == null or not is_instance_valid(_network_cache):
		var p = get_parent()
		while p != null and not (p is GNNetwork):
			p = p.get_parent()
		_network_cache = p as GNNetwork
	if _network_cache == null:
		return null
	var target: GNNode = _network_cache.get_node_by_id(target_id)
	if target == null:
		return null
	return target.cached_output as GNGeoData if target.cached_output is GNGeoData else null
