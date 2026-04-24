class_name FacetSOPNative
extends GNSopBase
## Native-accelerated facet (unique/consolidate) — delegates to GNNativeFacet
## (C++) when available, falls back to pure GDScript otherwise.

var _processor: RefCounted = null


func _init() -> void:
	node_type = "facet_native"
	node_description = "Unique / consolidate vertices (native C++ accelerated)."
	if ClassDB.class_exists("GNNativeFacet"):
		_processor = ClassDB.instantiate("GNNativeFacet")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Faceted geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Unique Points (Flat)", "Consolidate (Merge Close)"]),
		0, "", "Faceting mode"))
	add_parameter(GNParameter.create_float("distance", 0.001, 0.0, 1.0, 0.0001,
		"Merge Distance", "Distance threshold for consolidation"))
	add_parameter(GNParameter.create_bool("recompute_normals", true, "",
		"Recompute normals after operation"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = _require_input_geo(inputs)
	if in_geo == null:
		return null

	var mode: int = get_param_value("mode")
	var merge_dist: float = get_param_value("distance")
	var recompute: bool = get_param_value("recompute_normals")

	# Extract first surface arrays
	var positions := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for s in range(in_geo.get_surface_count()):
		var arrays: Array = in_geo.get_surface_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			positions = arrays[Mesh.ARRAY_VERTEX]
			if arrays[Mesh.ARRAY_TEX_UV] != null:
				uvs = arrays[Mesh.ARRAY_TEX_UV]
			if arrays[Mesh.ARRAY_INDEX] != null:
				indices = arrays[Mesh.ARRAY_INDEX]
			break

	if positions.is_empty():
		return null

	if _processor != null:
		var result: Dictionary = _processor.process(positions, uvs, indices, mode, merge_dist)
		var out_pos: PackedVector3Array = result.get("positions", PackedVector3Array())
		var out_uvs: PackedVector2Array = result.get("uvs", PackedVector2Array())
		var out_idx: PackedInt32Array = result.get("indices", PackedInt32Array())

		if out_pos.is_empty():
			return null

		var out := _prepare_geo()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

		if out_idx.is_empty():
			# Non-indexed (unique mode)
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
		return null  # Fallback handled by core FacetSOP
