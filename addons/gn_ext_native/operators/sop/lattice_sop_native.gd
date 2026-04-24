class_name LatticeSOPNative
extends GNSopBase
## Native-accelerated FFD lattice — delegates to GNNativeLatticeSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "lattice_native"
	node_description = "Free-form deformation via control-point lattice — native C++ accelerated."
	if ClassDB.class_exists("GNNativeLatticeSop"):
		_processor = ClassDB.instantiate("GNNativeLatticeSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Geometry to deform")
	add_output("out", GNFamily.Type.SOP, "Deformed geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("div_x", 2, 2, 8, "Divisions X", ""))
	add_parameter(GNParameter.create_int("div_y", 2, 2, 8, "Divisions Y", ""))
	add_parameter(GNParameter.create_int("div_z", 2, 2, 8, "Divisions Z", ""))
	add_parameter(GNParameter.create_float("amplitude", 0.0, 0.0, 10.0, 0.01, "Deform Amplitude", ""))
	add_parameter(GNParameter.create_float("frequency", 1.0, 0.01, 20.0, 0.01, "Noise Frequency", ""))
	add_parameter(GNParameter.create_int("seed", 0, 0, 9999, "Seed", ""))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo_in: GNGeoData = _get_input_sop(inputs, 0)
	if geo_in == null or not geo_in.has_geometry():
		return _prepare_geo()

	var dx: int = get_param_value("div_x")
	var dy: int = get_param_value("div_y")
	var dz: int = get_param_value("div_z")
	var amp: float = get_param_value("amplitude")
	var freq: float = get_param_value("frequency")
	var seed_val: int = get_param_value("seed")

	# Compute AABB
	var bbox_min := Vector3(INF, INF, INF)
	var bbox_max := Vector3(-INF, -INF, -INF)
	for s in range(geo_in.mesh.get_surface_count()):
		var arrays: Array = geo_in.mesh.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			for v in arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				bbox_min = Vector3(minf(bbox_min.x, v.x), minf(bbox_min.y, v.y), minf(bbox_min.z, v.z))
				bbox_max = Vector3(maxf(bbox_max.x, v.x), maxf(bbox_max.y, v.y), maxf(bbox_max.z, v.z))

	# Build lattice control points with noise displacement
	var noise := FastNoiseLite.new()
	noise.seed = seed_val
	noise.frequency = freq
	var lattice := PackedVector3Array()
	var sx: int = dx + 1
	var sy: int = dy + 1
	var sz: int = dz + 1
	for iz in range(sz):
		for iy in range(sy):
			for ix in range(sx):
				var rest := Vector3(
					bbox_min.x + float(ix) / float(dx) * (bbox_max.x - bbox_min.x),
					bbox_min.y + float(iy) / float(dy) * (bbox_max.y - bbox_min.y),
					bbox_min.z + float(iz) / float(dz) * (bbox_max.z - bbox_min.z))
				var disp := Vector3(
					noise.get_noise_3d(rest.x * 100.0, rest.y, rest.z),
					noise.get_noise_3d(rest.x, rest.y * 100.0, rest.z),
					noise.get_noise_3d(rest.x, rest.y, rest.z * 100.0)) * amp
				lattice.append(rest + disp)

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
			var result: PackedVector3Array = _processor.process(positions, lattice,
				sx, sy, sz, bbox_min, bbox_max)
			arrays[Mesh.ARRAY_VERTEX] = result
		new_mesh.add_surface_from_arrays(prim, arrays)

	geo.set_mesh(new_mesh)
	return geo
