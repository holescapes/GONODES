class_name PolyLoftSOPNative
extends GNSopBase
## Native-accelerated poly loft — delegates to GNNativePolyLoftSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "polyloft_native"
	node_description = "Loft polygon surface between cross-sections — native C++ accelerated."
	if ClassDB.class_exists("GNNativePolyLoftSop"):
		_processor = ClassDB.instantiate("GNNativePolyLoftSop")


func _init_ports() -> void:
	add_input("section1", GNFamily.Type.SOP, false, "First cross-section")
	add_input("section2", GNFamily.Type.SOP, false, "Second cross-section (optional)")
	add_output("out", GNFamily.Type.SOP, "Lofted surface")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("loft_distance", 1.0, 0.0, 100.0, 0.01, "Loft Distance", ""))
	add_parameter(GNParameter.create_enum("loft_axis", PackedStringArray(["Y", "X", "Z"]), 0, "Axis", ""))
	add_parameter(GNParameter.create_int("subdivisions", 1, 1, 64, "Subdivisions", ""))
	add_parameter(GNParameter.create_bool("close_caps", false, "Close Caps", ""))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo_a: GNGeoData = _get_input_sop(inputs, 0)
	if geo_a == null or not geo_a.has_geometry():
		return _prepare_geo()

	var ring_a := _extract_ring(geo_a)
	if ring_a.is_empty():
		return _prepare_geo()

	var geo_b: GNGeoData = _get_input_sop(inputs, 1)
	var ring_b: PackedVector3Array
	if geo_b != null and geo_b.has_geometry():
		ring_b = _extract_ring(geo_b)
	else:
		# Auto-generate by offsetting along axis
		var dist: float = get_param_value("loft_distance")
		var axis_idx: int = get_param_value("loft_axis")
		var axis_map := [Vector3.UP, Vector3.RIGHT, Vector3(0, 0, 1)]
		ring_b = ring_a.duplicate()
		var offset: Vector3 = axis_map[axis_idx] * dist
		for i in range(ring_b.size()):
			ring_b[i] += offset

	var sections := Array()
	var subdivs: int = get_param_value("subdivisions")
	sections.append(ring_a)
	if subdivs > 1:
		for s in range(1, subdivs):
			var t: float = float(s) / float(subdivs)
			var interp := PackedVector3Array()
			var count: int = mini(ring_a.size(), ring_b.size())
			interp.resize(count)
			for i in range(count):
				interp[i] = ring_a[i].lerp(ring_b[i], t)
			sections.append(interp)
	sections.append(ring_b)

	if _processor != null:
		var close: bool = get_param_value("close_caps")
		var result: Dictionary = _processor.process(sections, close)

		var geo := _prepare_geo()
		var new_mesh := ArrayMesh.new()
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = result.get("positions", PackedVector3Array())
		if result.has("normals"):
			arrays[Mesh.ARRAY_NORMAL] = result["normals"]
		if result.has("uvs"):
			arrays[Mesh.ARRAY_TEX_UV] = result["uvs"]
		if result.has("indices"):
			arrays[Mesh.ARRAY_INDEX] = result["indices"]
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		geo.set_mesh(new_mesh)
		return geo
	else:
		return _prepare_geo()


func _extract_ring(geo: GNGeoData) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for s in range(geo.mesh.get_surface_count()):
		var arrays: Array = geo.mesh.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			pts.append_array(arrays[Mesh.ARRAY_VERTEX])
	return pts
