class_name BooleanSOPNative
extends GNSopBase
## Native-accelerated boolean mesh operations — delegates to GNNativeBooleanSop (C++).
## BSP-tree CSG: no scene tree required, no frame-delay, fully deterministic.

var _processor: RefCounted = null


func _init() -> void:
	node_type = "boolean_native"
	node_description = "Boolean operations (union, intersect, subtract) — native C++ BSP-tree accelerated."
	if ClassDB.class_exists("GNNativeBooleanSop"):
		_processor = ClassDB.instantiate("GNNativeBooleanSop")


func _init_ports() -> void:
	add_input("a", GNFamily.Type.SOP, false, "Mesh A", "A")
	add_input("b", GNFamily.Type.SOP, false, "Mesh B", "B")
	add_output("out", GNFamily.Type.SOP, "Boolean result", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("operation",
		PackedStringArray(["Union", "Intersection", "Subtraction"]),
		0, "", "Boolean operation type"))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo_a: GNGeoData = _get_input_sop(inputs, 0)
	var geo_b: GNGeoData = _get_input_sop(inputs, 1)

	if geo_a == null or not geo_a.has_geometry():
		return null
	if geo_b == null or not geo_b.has_geometry():
		return geo_a

	if not _processor:
		return null

	var op: int = get_param_value("operation")

	# Extract vertex + index data from both meshes (first surface).
	var positions_a := PackedVector3Array()
	var indices_a := PackedInt32Array()
	var positions_b := PackedVector3Array()
	var indices_b := PackedInt32Array()

	for s in range(geo_a.get_surface_count()):
		var arrays: Array = geo_a.get_surface_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			positions_a = arrays[Mesh.ARRAY_VERTEX]
			if arrays[Mesh.ARRAY_INDEX] != null:
				indices_a = arrays[Mesh.ARRAY_INDEX]
			break

	for s in range(geo_b.get_surface_count()):
		var arrays: Array = geo_b.get_surface_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			positions_b = arrays[Mesh.ARRAY_VERTEX]
			if arrays[Mesh.ARRAY_INDEX] != null:
				indices_b = arrays[Mesh.ARRAY_INDEX]
			break

	if positions_a.is_empty() or positions_b.is_empty():
		return null

	# If no index array, generate trivial sequential indices.
	if indices_a.is_empty():
		indices_a.resize(positions_a.size())
		for i in range(positions_a.size()):
			indices_a[i] = i

	if indices_b.is_empty():
		indices_b.resize(positions_b.size())
		for i in range(positions_b.size()):
			indices_b[i] = i

	var result: Dictionary = _processor.process(
		positions_a, indices_a, positions_b, indices_b, op)

	var out_pos: PackedVector3Array = result.get("positions", PackedVector3Array())
	var out_idx: PackedInt32Array = result.get("indices", PackedInt32Array())
	var out_nrm: PackedVector3Array = result.get("normals", PackedVector3Array())

	if out_pos.is_empty():
		return null

	var out := _prepare_geo()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out_pos
	arrays[Mesh.ARRAY_INDEX] = out_idx
	if out_nrm.size() == out_pos.size():
		arrays[Mesh.ARRAY_NORMAL] = out_nrm
	out.set_from_arrays(arrays)
	return out
