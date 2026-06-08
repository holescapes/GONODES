class_name CreepSOPNative
extends GNSopBase
## Native-accelerated surface creeping — delegates to GNNativeCreepSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "creep_native"
	if ClassDB.class_exists("GNNativeCreepSop"):
		_processor = ClassDB.instantiate("GNNativeCreepSop")


func _init_ports() -> void:
	add_input("source", GNFamily.Type.SOP, false, "Points to creep along surface", "Source")
	add_input("surface", GNFamily.Type.SOP, false, "Target surface to creep on", "Surface")
	add_output("out", GNFamily.Type.SOP, "Displaced points", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("distance", 0.1, -10.0, 10.0, 0.01,
		"Distance", "Displacement distance along surface"))
	add_parameter(GNParameter.create_enum("direction",
		PackedStringArray(["Normal", "Tangent U", "Tangent V", "Random"]), 0,
		"Direction", "Direction of displacement"))
	add_parameter(GNParameter.create_int("seed", 0, 0, 99999,
		"Seed", "Random seed for random direction mode"))


func _cook(inputs: Array[GNData]) -> GNData:
	var source_geo := _get_input_sop(inputs, 0)
	var surface_geo := _get_input_sop(inputs, 1)
	if not source_geo or not source_geo.has_geometry() or not surface_geo or not surface_geo.has_geometry() or not _processor:
		return null

	var src_mesh: ArrayMesh = source_geo.mesh
	var tgt_mesh: ArrayMesh = surface_geo.mesh
	if not src_mesh or not tgt_mesh:
		return null
	if src_mesh.get_surface_count() == 0 or tgt_mesh.get_surface_count() == 0:
		return source_geo

	var src_arrays: Array = src_mesh.surface_get_arrays(0)
	var src_verts: PackedVector3Array = src_arrays[Mesh.ARRAY_VERTEX]

	var tgt_arrays: Array = tgt_mesh.surface_get_arrays(0)
	var tgt_verts: PackedVector3Array = tgt_arrays[Mesh.ARRAY_VERTEX]
	var tgt_indices: PackedInt32Array = tgt_arrays[Mesh.ARRAY_INDEX] if tgt_arrays[Mesh.ARRAY_INDEX] else PackedInt32Array()
	var tgt_normals: PackedVector3Array = tgt_arrays[Mesh.ARRAY_NORMAL] if tgt_arrays[Mesh.ARRAY_NORMAL] else PackedVector3Array()

	var direction: int = get_param_value("direction")
	var distance: float = get_param_value("distance")
	var seed_val: int = get_param_value("seed")

	var new_verts: PackedVector3Array = _processor.process(src_verts, tgt_verts,
		tgt_indices, tgt_normals, direction, distance, seed_val)

	var out := _prepare_geo()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_POINTS)
	for v in new_verts:
		st.add_vertex(v)
	out.mesh = st.commit()
	return out
