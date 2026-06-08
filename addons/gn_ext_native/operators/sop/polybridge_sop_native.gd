class_name PolyBridgeSOPNative
extends GNSopBase
## Native-accelerated edge loop bridging — delegates to GNNativePolyBridgeSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "polybridge_native"
	if ClassDB.class_exists("GNNativePolyBridgeSop"):
		_processor = ClassDB.instantiate("GNNativePolyBridgeSop")


func _init_ports() -> void:
	add_input("loop_a", GNFamily.Type.SOP, false, "First edge loop", "Loop A")
	add_input("loop_b", GNFamily.Type.SOP, false, "Second edge loop", "Loop B")
	add_output("out", GNFamily.Type.SOP, "Bridged geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("divisions", 4, 1, 64,
		"Divisions", "Bridge subdivisions"))
	add_parameter(GNParameter.create_float("twist", 0.0, -360.0, 360.0, 1.0,
		"Twist", "Twist angle in degrees"))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo_a := _get_input_sop(inputs, 0)
	var geo_b := _get_input_sop(inputs, 1)
	if geo_a == null or not geo_a.has_geometry() or geo_b == null or not geo_b.has_geometry():
		return null
	if _processor == null:
		return null

	var divisions: int = get_param_value("divisions")
	var twist: float = get_param_value("twist")

	var loop_a := PackedVector3Array()
	for s in range(geo_a.mesh.get_surface_count()):
		var arrays: Array = geo_a.mesh.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			loop_a.append_array(arrays[Mesh.ARRAY_VERTEX])
	var loop_b := PackedVector3Array()
	for s in range(geo_b.mesh.get_surface_count()):
		var arrays: Array = geo_b.mesh.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			loop_b.append_array(arrays[Mesh.ARRAY_VERTEX])

	if loop_a.is_empty() or loop_b.is_empty():
		return null

	var result: Dictionary = _processor.process(loop_a, loop_b, divisions, twist)
	var geo := _prepare_geo()
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = result.get("vertices", PackedVector3Array())
	arrays[Mesh.ARRAY_NORMAL] = result.get("normals", PackedVector3Array())
	arrays[Mesh.ARRAY_TEX_UV] = result.get("uvs", PackedVector2Array())
	arrays[Mesh.ARRAY_INDEX] = result.get("indices", PackedInt32Array())
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	geo.set_mesh(mesh)
	return geo
