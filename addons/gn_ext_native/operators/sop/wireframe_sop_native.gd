class_name WireframeSOPNative
extends GNSopBase
## Native-accelerated wireframe extraction — delegates to GNNativeWireframeSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "wireframe"
	node_description = "Extract triangle edges as line pairs — native C++ accelerated."
	if ClassDB.class_exists("GNNativeWireframeSop"):
		_processor = ClassDB.instantiate("GNNativeWireframeSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Wireframe line geometry")


func _init_parameters() -> void:
	pass  # No parameters


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = _get_input_sop(inputs, 0)
	if in_geo == null or not in_geo.has_geometry():
		return null

	var positions := PackedVector3Array()
	var indices := PackedInt32Array()
	for s in range(in_geo.get_surface_count()):
		var arrays: Array = in_geo.get_surface_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			positions = arrays[Mesh.ARRAY_VERTEX]
			if arrays[Mesh.ARRAY_INDEX] != null:
				indices = arrays[Mesh.ARRAY_INDEX]
			break

	if positions.is_empty() or not _processor:
		return null

	var line_verts: PackedVector3Array = _processor.process(positions, indices)
	if line_verts.is_empty():
		return null

	var out := _prepare_geo()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = line_verts
	out.mesh = ArrayMesh.new()
	out.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return out
