class_name MirrorSOPNative
extends GNSopBase
## Native-accelerated mirror — delegates to GNNativeMirrorSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "mirror"
	node_description = "Mirror geometry across a plane — native C++ accelerated."
	if ClassDB.class_exists("GNNativeMirrorSop"):
		_processor = ClassDB.instantiate("GNNativeMirrorSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Mirrored geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("plane",
		PackedStringArray(["YZ (Mirror X)", "XZ (Mirror Y)", "XY (Mirror Z)"]), 0, "", ""))
	add_parameter(GNParameter.create_float("origin", 0.0, null, null, 0.01, "Origin", ""))
	add_parameter(GNParameter.create_bool("merge", true, "", "Merge original and mirrored"))
	add_parameter(GNParameter.create_bool("reverse_winding", true, "", "Reverse winding of mirrored"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = inputs[0] as GNGeoData if inputs.size() > 0 and inputs[0] is GNGeoData else null
	if in_geo == null or not in_geo.has_geometry():
		return null

	var geo := _prepare_geo()
	var plane_idx: int = get_param_value("plane")
	var origin_val: float = get_param_value("origin")
	var do_merge: bool = get_param_value("merge")
	var rev_wind: bool = get_param_value("reverse_winding")

	var mirror_axis: Vector3
	match plane_idx:
		0: mirror_axis = Vector3(1, 0, 0)
		1: mirror_axis = Vector3(0, 1, 0)
		_: mirror_axis = Vector3(0, 0, 1)

	var new_mesh := ArrayMesh.new()
	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] if arrays[Mesh.ARRAY_VERTEX] else PackedVector3Array()
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] else PackedVector3Array()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] else PackedInt32Array()

		if verts.is_empty() or not _processor:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		if do_merge:
			var result: Dictionary = _processor.process(verts, normals, indices,
				mirror_axis, origin_val, rev_wind)
			arrays[Mesh.ARRAY_VERTEX] = result.get("positions", verts)
			if result.has("normals"): arrays[Mesh.ARRAY_NORMAL] = result["normals"]
			if result.has("indices"): arrays[Mesh.ARRAY_INDEX] = result["indices"]
		else:
			# Mirror only — C++ returns combined, so just take mirrored half
			var result: Dictionary = _processor.process(verts, normals, indices,
				mirror_axis, origin_val, rev_wind)
			var all_v: PackedVector3Array = result.get("positions", PackedVector3Array())
			var nv: int = verts.size()
			arrays[Mesh.ARRAY_VERTEX] = all_v.slice(nv) if all_v.size() > nv else verts
			if result.has("normals"):
				var all_n: PackedVector3Array = result["normals"]
				arrays[Mesh.ARRAY_NORMAL] = all_n.slice(nv) if all_n.size() > nv else normals
			if result.has("indices"):
				var all_i: PackedInt32Array = result["indices"]
				var ni: int = indices.size()
				var mi: PackedInt32Array = all_i.slice(ni) if all_i.size() > ni else indices
				for i in range(mi.size()):
					mi[i] -= nv
				arrays[Mesh.ARRAY_INDEX] = mi
		new_mesh.add_surface_from_arrays(prim, arrays)

	geo.set_mesh(new_mesh)
	return geo
