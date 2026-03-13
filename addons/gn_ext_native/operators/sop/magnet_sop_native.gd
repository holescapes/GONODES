class_name MagnetSOPNative
extends GNSopBase
## Native-accelerated magnet deformation — delegates to GNNativeMagnetSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "magnet"
	node_description = "Attract/repel vertices toward points — native C++ accelerated."
	if ClassDB.class_exists("GNNativeMagnetSop"):
		_processor = ClassDB.instantiate("GNNativeMagnetSop")


func _init_ports() -> void:
	add_input("geo", GNFamily.Type.SOP, true, "Geometry to deform")
	add_input("attractors", GNFamily.Type.SOP, false, "Attractor point cloud (optional)")
	add_output("out", GNFamily.Type.SOP, "Deformed geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("strength", 1.0, -10.0, 10.0, 0.05, "Strength", ""))
	add_parameter(GNParameter.create_float("radius", 2.0, 0.01, 100.0, 0.1, "Radius", ""))
	add_parameter(GNParameter.create_enum("falloff",
		PackedStringArray(["Linear", "Smooth", "Inverse Square", "Gaussian"]), 1, "Falloff", ""))
	add_parameter(GNParameter.create_float("exponent", 2.0, 0.1, 10.0, 0.1, "Exponent", ""))
	add_parameter(GNParameter.create_bool("affect_normals", true, "Affect Normals", ""))
	add_parameter(GNParameter.create_float("att_x", 0.0, -100.0, 100.0, 0.1, "Attractor X", ""))
	add_parameter(GNParameter.create_float("att_y", 0.0, -100.0, 100.0, 0.1, "Attractor Y", ""))
	add_parameter(GNParameter.create_float("att_z", 0.0, -100.0, 100.0, 0.1, "Attractor Z", ""))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo_in: GNGeoData = _get_input_sop(inputs, 0)
	if geo_in == null or not geo_in.has_geometry():
		return _prepare_geo()

	var strength_val: float = get_param_value("strength")
	var radius_val: float = get_param_value("radius")
	var falloff_type: int = get_param_value("falloff")
	var magnet_pos := Vector3(get_param_value("att_x"), get_param_value("att_y"), get_param_value("att_z"))

	var geo := _prepare_geo()
	var new_mesh := ArrayMesh.new()

	for s in range(geo_in.mesh.get_surface_count()):
		var arrays: Array = geo_in.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = geo_in.mesh.surface_get_primitive_type(s)
		if arrays[Mesh.ARRAY_VERTEX] == null:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]

		if _processor != null:
			var result: PackedVector3Array = _processor.process(positions, magnet_pos,
				radius_val, strength_val, falloff_type)
			arrays[Mesh.ARRAY_VERTEX] = result
		new_mesh.add_surface_from_arrays(prim, arrays)

	geo.set_mesh(new_mesh)
	return geo
