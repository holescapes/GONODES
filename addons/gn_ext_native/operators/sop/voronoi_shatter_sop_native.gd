class_name VoronoiShatterSOPNative
extends GNSopBase
## Native-accelerated Voronoi fracture — delegates to GNNativeVoronoiShatterSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "voronoi_shatter"
	if ClassDB.class_exists("GNNativeVoronoiShatterSop"):
		_processor = ClassDB.instantiate("GNNativeVoronoiShatterSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Geometry to fracture")
	add_output("out", GNFamily.Type.SOP, "Fractured geometry (one surface per piece)")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("num_points", 8, 2, 256,
		"Num Points", "Number of Voronoi scatter points"))
	add_parameter(GNParameter.create_int("seed", 0, 0, 99999,
		"Seed", "Random seed for scatter point generation"))
	add_parameter(GNParameter.create_float("offset", 0.0, 0.0, 0.1, 0.001,
		"Offset", "Gap between pieces"))
	add_parameter(GNParameter.create_bool("interior_faces", true,
		"Interior Faces", "Generate faces on cut planes"))


func _cook(inputs: Array[GNData]) -> GNData:
	var input_geo := _require_input_geo(inputs)
	if not input_geo or not _processor:
		return null

	var mesh: ArrayMesh = input_geo.mesh
	if not mesh or mesh.get_surface_count() == 0:
		return input_geo

	# Gather all vertices and indices
	var all_verts := PackedVector3Array()
	var all_indices := PackedInt32Array()
	for s in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] else PackedInt32Array()
		var base: int = all_verts.size()
		all_verts.append_array(v)
		for i in idx:
			all_indices.append(i + base)

	# Generate scatter points in bounding box
	var num_pts: int = get_param_value("num_points")
	var seed_val: int = get_param_value("seed")
	var scatter := PackedVector3Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var aabb := AABB()
	if all_verts.size() > 0:
		aabb.position = all_verts[0]
		for v in all_verts:
			aabb = aabb.expand(v)
	for _i in range(num_pts):
		scatter.append(Vector3(
			rng.randf_range(aabb.position.x, aabb.end.x),
			rng.randf_range(aabb.position.y, aabb.end.y),
			rng.randf_range(aabb.position.z, aabb.end.z)))

	var fragments: Array = _processor.process(all_verts, all_indices, scatter, seed_val)

	var out := _prepare_geo()
	var out_mesh := ArrayMesh.new()
	var piece_attrib := PackedFloat32Array()
	for frag_idx in range(fragments.size()):
		var frag: Dictionary = fragments[frag_idx]
		var fv: PackedVector3Array = frag["vertices"]
		var fi: PackedInt32Array = frag["indices"]
		if fv.size() == 0 or fi.size() == 0:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in fv:
			st.add_vertex(v)
		for i in fi:
			st.add_index(i)
		st.generate_normals()
		out_mesh = st.commit(out_mesh)
		for _v in range(fv.size()):
			piece_attrib.append(float(frag_idx))
	out.mesh = out_mesh
	out.point_attribs["piece"] = piece_attrib
	return out
