class_name ExtrudeSOPNative
extends GNSopBase
## Native-accelerated extrude — delegates to GNNativeExtrudeSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "extrude_native"
	node_description = "Extrude faces along normals — native C++ accelerated."
	if ClassDB.class_exists("GNNativeExtrudeSop"):
		_processor = ClassDB.instantiate("GNNativeExtrudeSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Extruded geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("distance", 0.2, -10.0, 10.0, 0.01, "Distance", ""))
	add_parameter(GNParameter.create_bool("output_sides", true, "", "Side walls"))
	add_parameter(GNParameter.create_bool("output_front", true, "", "Extruded face"))
	add_parameter(GNParameter.create_bool("output_back", false, "", "Original face"))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo_in: GNGeoData = _get_input_sop(inputs, 0)
	if geo_in == null or not geo_in.has_geometry():
		return _prepare_geo()

	var dist: float = get_param_value("distance")
	var inset: float = 0.0  # Reserved for future inset param

	# Extract first surface
	var arrays: Array = geo_in.mesh.surface_get_arrays(0)
	if arrays[Mesh.ARRAY_VERTEX] == null:
		return _prepare_geo()

	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()

	if _processor != null:
		var result: Dictionary = _processor.process(positions, normals, indices, dist, inset)

		var geo := _prepare_geo()
		var new_mesh := ArrayMesh.new()
		var out_arrays: Array = []
		out_arrays.resize(Mesh.ARRAY_MAX)
		out_arrays[Mesh.ARRAY_VERTEX] = result.get("positions", PackedVector3Array())
		if result.has("normals"):
			out_arrays[Mesh.ARRAY_NORMAL] = result["normals"]
		if result.has("indices"):
			out_arrays[Mesh.ARRAY_INDEX] = result["indices"]
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out_arrays)
		geo.set_mesh(new_mesh)
		return geo
	else:
		return _prepare_geo()
