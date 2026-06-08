class_name SubdivideSOPNative
extends GNSopBase
## Native-accelerated triangle subdivision — delegates to GNNativeSubdivide
## (C++) when available, falls back to pure GDScript otherwise.

var _processor: RefCounted = null


func _init() -> void:
	node_type = "subdivide_native"
	node_description = "Subdivide triangles into 4 sub-triangles (native C++ accelerated)."
	if ClassDB.class_exists("GNNativeSubdivide"):
		_processor = ClassDB.instantiate("GNNativeSubdivide")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry", "In")
	add_output("out", GNFamily.Type.SOP, "Subdivided geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("iterations", 1, 1, 4, "Iterations",
		"Number of subdivision passes"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = _get_input_sop(inputs, 0)
	if in_geo == null or not in_geo.has_geometry():
		return null

	var iterations: int = get_param_value("iterations")

	# Extract first surface
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
		var result: Dictionary = _processor.process(positions, uvs, indices, iterations)
		var out_pos: PackedVector3Array = result.get("positions", PackedVector3Array())
		var out_uvs: PackedVector2Array = result.get("uvs", PackedVector2Array())

		if out_pos.is_empty():
			return null

		var out := _prepare_geo()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

		for i in range(out_pos.size()):
			if i < out_uvs.size():
				st.set_uv(out_uvs[i])
			st.add_vertex(out_pos[i])

		st.generate_normals()
		st.generate_tangents()
		out.set_from_surface_tool(st)
		return out
	else:
		return null  # Fallback handled by core SubdivideSOP
