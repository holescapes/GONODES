class_name RaySOPNative
extends GNSopBase
## Native-accelerated ray projection — delegates to GNNativeRay (C++) when
## available, falls back to pure GDScript otherwise.

var _processor: RefCounted = null


func _init() -> void:
	node_type = "ray_native"
	node_description = "Project vertices onto surface via raycasting (native C++ accelerated)."
	if ClassDB.class_exists("GNNativeRay"):
		_processor = ClassDB.instantiate("GNNativeRay")


func _init_ports() -> void:
	add_input("source", GNFamily.Type.SOP, false, "Source geometry (vertices to project)")
	add_input("target", GNFamily.Type.SOP, false, "Target surface")
	add_output("out", GNFamily.Type.SOP, "Projected geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("direction",
		PackedStringArray(["Along Normal", "-Y (Down)", "+Y (Up)", "-Z (Forward)",
			"+Z (Back)", "-X (Left)", "+X (Right)"]),
		0, "Direction", "Ray cast direction per vertex"))
	add_parameter(GNParameter.create_float("max_dist", 100.0, 0.1, 10000.0, 0.1,
		"Max Distance", "Maximum ray length"))
	add_parameter(GNParameter.create_float("offset", 0.0, -10.0, 10.0, 0.001,
		"Offset", "Distance above hit surface along hit normal"))
	add_parameter(GNParameter.create_bool("use_hit_normal", true,
		"Use Hit Normal", "Replace vertex normals with surface hit normal"))


func _cook(inputs: Array[GNData]) -> GNData:
	var src_geo: GNGeoData = _get_input_sop(inputs, 0)
	var tgt_geo: GNGeoData = _get_input_sop(inputs, 1)
	if src_geo == null or not src_geo.has_geometry():
		return null
	if tgt_geo == null or not tgt_geo.has_geometry():
		return src_geo

	var dir_mode: int = get_param_value("direction")
	var max_dist: float = get_param_value("max_dist")
	var offset_val: float = get_param_value("offset")
	var use_hit_n: bool = get_param_value("use_hit_normal")

	# Extract source arrays
	var src_positions := PackedVector3Array()
	var src_normals := PackedVector3Array()
	for s in range(src_geo.get_surface_count()):
		var arrays: Array = src_geo.get_surface_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			src_positions.append_array(arrays[Mesh.ARRAY_VERTEX])
			if arrays[Mesh.ARRAY_NORMAL] != null:
				src_normals.append_array(arrays[Mesh.ARRAY_NORMAL])

	# Extract target faces as flat triangle list
	var tgt_faces := PackedVector3Array()
	for s in range(tgt_geo.get_surface_count()):
		var arrays: Array = tgt_geo.get_surface_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			tgt_faces.append_array(verts)
		else:
			for i in range(indices.size()):
				tgt_faces.append(verts[indices[i]])

	if src_positions.is_empty() or tgt_faces.is_empty():
		return src_geo

	if _processor != null:
		var result: Dictionary = _processor.process(src_positions, src_normals,
			tgt_faces, dir_mode, max_dist, offset_val, use_hit_n)
		var out_pos: PackedVector3Array = result.get("positions", PackedVector3Array())
		var out_nrm: PackedVector3Array = result.get("normals", PackedVector3Array())
		if out_pos.is_empty():
			return null
		var out := _prepare_geo()
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = out_pos
		arrays[Mesh.ARRAY_NORMAL] = out_nrm
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.set_mesh(mesh)
		return out
	else:
		return null  # Fallback handled by core RaySOP
