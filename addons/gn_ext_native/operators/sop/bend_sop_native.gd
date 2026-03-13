class_name BendSOPNative
extends GNSopBase
## Native-accelerated bend deformation — delegates to GNNativeBendSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "bend"
	node_description = "Bend geometry along an axis — native C++ accelerated."
	if ClassDB.class_exists("GNNativeBendSop"):
		_processor = ClassDB.instantiate("GNNativeBendSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Bent geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("angle", 0.0, -360.0, 360.0, 0.1, "Bend Angle", "degrees"))
	add_parameter(GNParameter.create_enum("axis", PackedStringArray(["X", "Y", "Z"]), 1, "Axis", ""))
	add_parameter(GNParameter.create_float("origin", 0.0, -10.0, 10.0, 0.01, "Origin", ""))
	add_parameter(GNParameter.create_float("length_val", 0.0, null, null, 0.01, "Length", "0 = auto"))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo_in: GNGeoData = _get_input_sop(inputs, 0)
	if geo_in == null or not geo_in.has_geometry():
		return _prepare_geo()

	var angle_deg: float = get_param_value("angle")
	var axis_idx: int = get_param_value("axis")
	var origin: float = get_param_value("origin")
	var length_val: float = get_param_value("length_val")
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

		# Compute bounds for auto length
		var min_e: float = INF
		var max_e: float = -INF
		for v in positions:
			var val: float = v[axis_idx]
			min_e = minf(min_e, val)
			max_e = maxf(max_e, val)
		var extent: float = length_val if length_val > 0.0 else (max_e - min_e)

		if _processor != null and absf(angle_rad) > 0.0001:
			var result: PackedVector3Array = _processor.process(positions, angle_rad, axis_idx, min_e, max_e)
			arrays[Mesh.ARRAY_VERTEX] = result
		new_mesh.add_surface_from_arrays(prim, arrays)

	geo.set_mesh(new_mesh)
	return geo
