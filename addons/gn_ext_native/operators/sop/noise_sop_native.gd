class_name NoiseSOPNative
extends GNSopBase
## Native-accelerated noise displacement — delegates to GNNativeNoiseSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "noise_native"
	node_description = "Displace vertices with 3D noise — native C++ accelerated."
	if ClassDB.class_exists("GNNativeNoiseSop"):
		_processor = ClassDB.instantiate("GNNativeNoiseSop")


func update_time_dependency() -> void:
	time_dependent = float(get_param_value("speed")) > 0.0 \
			or param_expression_uses_time("speed")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry", "In")
	add_output("out", GNFamily.Type.SOP, "Displaced geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("amplitude", 0.2, 0.0, 100.0, 0.01, "Amplitude", ""))
	add_parameter(GNParameter.create_float("frequency", 2.0, 0.01, 100.0, 0.1, "Frequency", ""))
	add_parameter(GNParameter.create_float("offset_x", 0.0, null, null, 0.1, "Offset X", ""))
	add_parameter(GNParameter.create_float("offset_y", 0.0, null, null, 0.1, "Offset Y", ""))
	add_parameter(GNParameter.create_float("offset_z", 0.0, null, null, 0.1, "Offset Z", ""))
	add_parameter(GNParameter.create_float("speed", 1.0, 0.0, 10.0, 0.01, "Speed", ""))
	add_parameter(GNParameter.create_enum("noise_type",
		PackedStringArray(["Simplex", "Perlin", "Cellular", "Value"]), 0, "Noise Type", ""))
	add_parameter(GNParameter.create_enum("displace_axis",
		PackedStringArray(["Normal", "X", "Y", "Z"]), 0, "Displace Along", ""))
	add_parameter(GNParameter.create_int("seed", 0, 0, 9999, "Seed", ""))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo_in: GNGeoData = _get_input_sop(inputs, 0)
	if geo_in == null or not geo_in.has_geometry():
		return _prepare_geo()

	var amp: float = get_param_value("amplitude")
	var freq: float = get_param_value("frequency")
	var ox: float = get_param_value("offset_x")
	var oy: float = get_param_value("offset_y")
	var oz: float = get_param_value("offset_z")
	var spd: float = get_param_value("speed")
	var axis_mode: int = get_param_value("displace_axis")
	var seed_val: int = get_param_value("seed")
	var time_off: float = elapsed_time * spd

	var geo := _prepare_geo()
	var new_mesh := ArrayMesh.new()

	for s in range(geo_in.mesh.get_surface_count()):
		var arrays: Array = geo_in.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = geo_in.mesh.surface_get_primitive_type(s)
		if arrays[Mesh.ARRAY_VERTEX] == null:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()

		if _processor != null and positions.size() > 0:
			var result: PackedVector3Array = _processor.process(positions, normals,
				amp, freq, ox, oy, oz, time_off, axis_mode, seed_val)
			arrays[Mesh.ARRAY_VERTEX] = result
		new_mesh.add_surface_from_arrays(prim, arrays)

	geo.set_mesh(new_mesh)
	return geo
