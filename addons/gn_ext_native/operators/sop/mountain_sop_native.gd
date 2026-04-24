class_name MountainSOPNative
extends GNSopBase
## Native-accelerated fractal displacement — delegates to GNNativeMountainSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "mountain_native"
	node_description = "Fractal noise displacement along normals — native C++ accelerated."
	if ClassDB.class_exists("GNNativeMountainSop"):
		_processor = ClassDB.instantiate("GNNativeMountainSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Displaced geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("height", 0.5, 0.0, 100.0, 0.01, "Height", ""))
	add_parameter(GNParameter.create_float("frequency", 2.0, 0.01, 50.0, 0.01, "Frequency", ""))
	add_parameter(GNParameter.create_int("octaves", 4, 1, 8, "Octaves", ""))
	add_parameter(GNParameter.create_float("lacunarity", 2.0, 0.1, 10.0, 0.01, "Lacunarity", ""))
	add_parameter(GNParameter.create_float("persistence", 0.5, 0.0, 1.0, 0.01, "Persistence", ""))
	add_parameter(GNParameter.create_int("seed", 0, 0, 9999, "Seed", ""))
	add_parameter(GNParameter.create_enum("noise_type",
		PackedStringArray(["Simplex", "Perlin", "Cellular", "Value"]), 0, "Noise Type", ""))
	add_parameter(GNParameter.create_float("offset_x", 0.0, -1000.0, 1000.0, 0.01, "Offset X", ""))
	add_parameter(GNParameter.create_float("offset_y", 0.0, -1000.0, 1000.0, 0.01, "Offset Y", ""))
	add_parameter(GNParameter.create_float("offset_z", 0.0, -1000.0, 1000.0, 0.01, "Offset Z", ""))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo_in: GNGeoData = _get_input_sop(inputs, 0)
	if geo_in == null or not geo_in.has_geometry():
		return _prepare_geo()

	var height: float = get_param_value("height")
	var freq: float = get_param_value("frequency")
	var octaves: int = get_param_value("octaves")
	var roughness: float = get_param_value("persistence")
	var seed_val: int = get_param_value("seed")

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
				height, freq, octaves, roughness, seed_val)
			arrays[Mesh.ARRAY_VERTEX] = result
		new_mesh.add_surface_from_arrays(prim, arrays)

	geo.set_mesh(new_mesh)
	return geo
