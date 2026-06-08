class_name TwistSOPNative
extends GNSopBase
## Native-accelerated twist deformation — delegates to GNNativeTwistSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "twist_native"
	node_description = "Twist geometry around an axis — native C++ accelerated."
	if ClassDB.class_exists("GNNativeTwistSop"):
		_processor = ClassDB.instantiate("GNNativeTwistSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry", "In")
	add_output("out", GNFamily.Type.SOP, "Twisted geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("angle", 0.0, -720.0, 720.0, 0.1, "Twist Angle", "degrees"))
	add_parameter(GNParameter.create_enum("axis", PackedStringArray(["X", "Y", "Z"]), 1, "Axis", ""))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo_in: GNGeoData = _get_input_sop(inputs, 0)
	if geo_in == null or not geo_in.has_geometry():
		return _prepare_geo()

	var angle_deg: float = get_param_value("angle")
	var axis_idx: int = get_param_value("axis")
	var angle_rad: float = deg_to_rad(angle_deg)

	var geo := _prepare_geo()
	var new_mesh := ArrayMesh.new()

	for s in range(geo_in.mesh.get_surface_count()):
		var arrays: Array = geo_in.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = geo_in.mesh.surface_get_primitive_type(s)
		if arrays[Mesh.ARRAY_VERTEX] == null:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]

		var min_e: float = INF
		var max_e: float = -INF
		for v in positions:
			min_e = minf(min_e, v[axis_idx])
			max_e = maxf(max_e, v[axis_idx])

		if _processor != null and absf(angle_rad) > 0.0001:
			var result: PackedVector3Array = _processor.process(positions, angle_rad, axis_idx, min_e, max_e)
			arrays[Mesh.ARRAY_VERTEX] = result
		new_mesh.add_surface_from_arrays(prim, arrays)

	geo.set_mesh(new_mesh)
	return geo
