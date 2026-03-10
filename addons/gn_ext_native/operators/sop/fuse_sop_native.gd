class_name FuseSOPNative
extends GNSopBase
## Native-accelerated vertex fusing — delegates to GNNativeFuse (C++) when
## available, falls back to pure GDScript otherwise.

var _processor: RefCounted = null


func _init() -> void:
	node_type = "fuse"
	node_description = "Merge coincident vertices (native C++ accelerated)."
	if ClassDB.class_exists("GNNativeFuse"):
		_processor = ClassDB.instantiate("GNNativeFuse")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Fused geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("threshold", 0.001, 0.0, 1.0, 0.0001,
		"Distance", "Max distance to merge vertices"))
	add_parameter(GNParameter.create_bool("recompute_normals", true,
		"Recompute Normals", "Regenerate smooth normals after fusing"))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo: GNGeoData = _require_input_geo(inputs)
	if geo == null:
		return null

	var threshold: float = get_param_value("threshold")
	var recompute: bool = get_param_value("recompute_normals")

	# Extract first surface
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for s in range(geo.get_surface_count()):
		var arrays: Array = geo.get_surface_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			positions = arrays[Mesh.ARRAY_VERTEX]
			if arrays[Mesh.ARRAY_NORMAL] != null:
				normals = arrays[Mesh.ARRAY_NORMAL]
			if arrays[Mesh.ARRAY_TEX_UV] != null:
				uvs = arrays[Mesh.ARRAY_TEX_UV]
			if arrays[Mesh.ARRAY_INDEX] != null:
				indices = arrays[Mesh.ARRAY_INDEX]
			break

	if positions.is_empty():
		return null

	if _processor != null:
		var result: Dictionary = _processor.process(positions, normals, uvs, indices, threshold)
		var out_pos: PackedVector3Array = result.get("positions", PackedVector3Array())
		var out_uvs: PackedVector2Array = result.get("uvs", PackedVector2Array())
		var out_idx: PackedInt32Array = result.get("indices", PackedInt32Array())

		if out_pos.is_empty():
			return null

		var out := _prepare_geo()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

		if out_idx.is_empty():
			for i in range(out_pos.size()):
				if i < out_uvs.size():
					st.set_uv(out_uvs[i])
				st.add_vertex(out_pos[i])
		else:
			for i in range(out_idx.size()):
				var vi: int = out_idx[i]
				if vi < out_uvs.size():
					st.set_uv(out_uvs[vi])
				st.add_vertex(out_pos[vi])

		if recompute:
			st.generate_normals()
		st.generate_tangents()
		out.set_from_surface_tool(st)
		return out
	else:
		return null  # Fallback handled by core FuseSOP
