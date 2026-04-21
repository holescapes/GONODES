class_name ProjectSOPNative
extends GNSopBase
## Native-accelerated orthographic projection — delegates to GNNativeProjectSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "project"
	if ClassDB.class_exists("GNNativeProjectSop"):
		_processor = ClassDB.instantiate("GNNativeProjectSop")


func _init_ports() -> void:
	add_input("source", GNFamily.Type.SOP, false, "Geometry to project")
	add_input("target", GNFamily.Type.SOP, true, "Target surface")
	add_output("out", GNFamily.Type.SOP, "Projected geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("axis",
		PackedStringArray(["X", "Y", "Z", "-X", "-Y", "-Z"]), 2,
		"Axis", "Projection axis"))
	add_parameter(GNParameter.create_float("offset", 0.0, -100.0, 100.0, 0.01,
		"Offset", "Offset along projection axis after projection"))
	add_parameter(GNParameter.create_bool("recompute_normals", true,
		"Recompute Normals", "Recompute normals after projection"))


func _cook(inputs: Array[GNData]) -> GNData:
	var source_geo := _require_input_geo(inputs)
	if not source_geo or not _processor:
		return null

	var src_mesh: ArrayMesh = source_geo.mesh
	if not src_mesh or src_mesh.get_surface_count() == 0:
		return source_geo

	var src_arrays: Array = src_mesh.surface_get_arrays(0)
	var src_verts: PackedVector3Array = src_arrays[Mesh.ARRAY_VERTEX]

	var axis_param: int = get_param_value("axis")
	var axis: int = axis_param % 3

	var target_geo = inputs[1] as GNGeoData if inputs.size() > 1 else null
	var tgt_verts := PackedVector3Array()
	var tgt_indices := PackedInt32Array()

	if target_geo and target_geo.mesh and target_geo.mesh.get_surface_count() > 0:
		var tgt_arrays: Array = target_geo.mesh.surface_get_arrays(0)
		tgt_verts = tgt_arrays[Mesh.ARRAY_VERTEX]
		tgt_indices = tgt_arrays[Mesh.ARRAY_INDEX] if tgt_arrays[Mesh.ARRAY_INDEX] else PackedInt32Array()

	var new_verts: PackedVector3Array = _processor.process(src_verts, tgt_verts, tgt_indices, axis)

	# Apply offset
	var offset: float = get_param_value("offset")
	if offset != 0.0:
		for i in range(new_verts.size()):
			var v: Vector3 = new_verts[i]
			match axis:
				0: v.x += offset
				1: v.y += offset
				2: v.z += offset
			new_verts[i] = v

	var out := _prepare_geo()
	var new_arrays: Array = src_arrays.duplicate()
	new_arrays[Mesh.ARRAY_VERTEX] = new_verts
	var new_mesh := ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_arrays)

	if get_param_value("recompute_normals"):
		var st := SurfaceTool.new()
		st.create_from(new_mesh, 0)
		st.generate_normals()
		out.mesh = st.commit()
	else:
		out.mesh = new_mesh
	return out
