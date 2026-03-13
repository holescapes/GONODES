class_name TaperSOPNative
extends GNSopBase
## Native-accelerated taper deformation — delegates to GNNativeTaperSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "taper"
	node_description = "Taper geometry along an axis — native C++ accelerated."
	if ClassDB.class_exists("GNNativeTaperSop"):
		_processor = ClassDB.instantiate("GNNativeTaperSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Tapered geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("scale_start", 1.0, 0.0, 10.0, 0.01, "Scale Start", ""))
	add_parameter(GNParameter.create_float("scale_end", 0.5, 0.0, 10.0, 0.01, "Scale End", ""))
	add_parameter(GNParameter.create_enum("axis", PackedStringArray(["X", "Y", "Z"]), 1, "Axis", ""))
	add_parameter(GNParameter.create_enum("profile", PackedStringArray(["Linear", "Smooth"]), 0, "Profile", ""))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo_in: GNGeoData = _get_input_sop(inputs, 0)
	if geo_in == null or not geo_in.has_geometry():
		return _prepare_geo()

	var taper_start: float = get_param_value("scale_start")
	var taper_end: float = get_param_value("scale_end")
	var axis_idx: int = get_param_value("axis")
	var taper_amount: float = taper_end - taper_start

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

		if _processor != null:
			var result: PackedVector3Array = _processor.process(positions, taper_amount, axis_idx, min_e, max_e)
			arrays[Mesh.ARRAY_VERTEX] = result
		new_mesh.add_surface_from_arrays(prim, arrays)

	geo.set_mesh(new_mesh)
	return geo
