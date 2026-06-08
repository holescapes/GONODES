class_name PolyReduceSOPNative
extends GNSopBase
## Native-accelerated mesh decimation — delegates to GNNativePolyReduce (C++ QEM)
## when available, falls back to returning input unchanged otherwise.

var _processor: RefCounted = null


func _init() -> void:
	node_type = "polyreduce_native"
	node_description = "Mesh decimation via QEM edge collapse (native C++ accelerated)."
	if ClassDB.class_exists("GNNativePolyReduce"):
		_processor = ClassDB.instantiate("GNNativePolyReduce")


func _init_ports() -> void:
	add_input("geo", GNFamily.Type.SOP, true, "Geometry to simplify", "Geometry")
	add_output("out", GNFamily.Type.SOP, "Reduced geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("target_percent", 50.0, 1.0, 100.0, 1.0,
		"Target %", "Percentage of original triangles to keep"))
	add_parameter(GNParameter.create_bool("preserve_boundary", true,
		"Preserve Boundary", "Add extra cost to boundary edges to preserve silhouette"))
	add_parameter(GNParameter.create_float("boundary_weight", 10.0, 0.1, 1000.0, 1.0,
		"Boundary Weight", "Extra penalty multiplier for boundary edges"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = _require_input_geo(inputs)
	if in_geo == null:
		return null
	if in_geo.mesh.get_surface_count() == 0:
		return in_geo

	var target_pct: float = get_param_value("target_percent")
	var preserve_boundary: bool = get_param_value("preserve_boundary")
	var boundary_weight: float = get_param_value("boundary_weight")

	var arrays: Array = in_geo.mesh.surface_get_arrays(0)
	if arrays[Mesh.ARRAY_VERTEX] == null:
		return in_geo

	var src_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_indices: Variant = arrays[Mesh.ARRAY_INDEX]

	var positions: PackedVector3Array = src_verts
	var indices := PackedInt32Array()
	if src_indices != null and src_indices is PackedInt32Array and src_indices.size() > 0:
		indices = src_indices

	if _processor == null:
		return in_geo  # No native lib — pass through unchanged

	var result: Dictionary = _processor.process(positions, indices,
		target_pct, preserve_boundary, boundary_weight)

	var out_verts: PackedVector3Array = result.get("positions", PackedVector3Array())
	var out_normals: PackedVector3Array = result.get("normals", PackedVector3Array())
	var out_indices: PackedInt32Array = result.get("indices", PackedInt32Array())

	if out_verts.is_empty():
		return in_geo

	var out := _prepare_geo()
	var out_arrays: Array = []
	out_arrays.resize(Mesh.ARRAY_MAX)
	out_arrays[Mesh.ARRAY_VERTEX] = out_verts
	out_arrays[Mesh.ARRAY_NORMAL] = out_normals
	if out_indices.size() > 0:
		out_arrays[Mesh.ARRAY_INDEX] = out_indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out_arrays)
	out.set_mesh(mesh)
	return out
