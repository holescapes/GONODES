class_name NoiseSOP
extends GNSopBase
## Displaces vertex positions of input geometry using 3D noise.
## Great for terrain generation, organic deformation, and wave effects.

var _noise: FastNoiseLite = null


func _init() -> void:
	node_type = "noise"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry", "In")
	add_output("out", GNFamily.Type.SOP, "Displaced geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("amplitude", 0.2, 0.0, 100.0, 0.01, "Amplitude", "Displacement strength"))
	add_parameter(GNParameter.create_float("frequency", 2.0, 0.01, 100.0, 0.1, "Frequency", "Noise frequency (detail)"))
	add_parameter(GNParameter.create_float("offset_x", 0.0, null, null, 0.1, "Offset X", "Noise offset along X"))
	add_parameter(GNParameter.create_float("offset_y", 0.0, null, null, 0.1, "Offset Y", "Noise offset along Y"))
	add_parameter(GNParameter.create_float("offset_z", 0.0, null, null, 0.1, "Offset Z", "Noise offset along Z"))
	add_parameter(GNParameter.create_float("speed", 1.0, 0.0, 10.0, 0.01, "Speed", "Animation speed"))
	add_parameter(GNParameter.create_enum("noise_type",
		PackedStringArray(["Simplex", "Perlin", "Cellular", "Value"]), 0, "Noise Type", "Noise algorithm"))
	add_parameter(GNParameter.create_enum("displace_axis",
		PackedStringArray(["Normal", "X", "Y", "Z"]), 0, "Displace Along", "Displacement direction"))
	add_parameter(GNParameter.create_int("seed", 0, 0, 9999, "Seed", "Random seed"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = _get_input_sop(inputs, 0)
	if in_geo == null or not in_geo.has_geometry():
		return null

	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	if _noise == null:
		_noise = FastNoiseLite.new()

	# Configure noise
	var noise_type_idx: int = get_param_value("noise_type")
	match noise_type_idx:
		0: _noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		1: _noise.noise_type = FastNoiseLite.TYPE_PERLIN
		2: _noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		3: _noise.noise_type = FastNoiseLite.TYPE_VALUE

	_noise.seed = get_param_value("seed")
	_noise.frequency = get_param_value("frequency")

	var amplitude: float = get_param_value("amplitude")
	var offset := Vector3(
		get_param_value("offset_x"),
		get_param_value("offset_y"),
		get_param_value("offset_z")
	)
	var time_offset: float = elapsed_time * get_param_value("speed")
	var axis_mode: int = get_param_value("displace_axis")

	# Process each surface
	var new_mesh := ArrayMesh.new()
	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)

		if arrays[Mesh.ARRAY_VERTEX] == null:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var new_verts := PackedVector3Array()
		new_verts.resize(verts.size())

		for i in range(verts.size()):
			var p: Vector3 = verts[i]
			var sample_pos: Vector3 = p + offset + Vector3(time_offset, 0.0, 0.0)
			var n: float = _noise.get_noise_3d(sample_pos.x, sample_pos.y, sample_pos.z) * amplitude

			match axis_mode:
				0:  # Normal
					if i < normals.size():
						new_verts[i] = p + normals[i] * n
					else:
						new_verts[i] = p + Vector3.UP * n
				1:  # X
					new_verts[i] = p + Vector3(n, 0.0, 0.0)
				2:  # Y
					new_verts[i] = p + Vector3(0.0, n, 0.0)
				3:  # Z
					new_verts[i] = p + Vector3(0.0, 0.0, n)

		arrays[Mesh.ARRAY_VERTEX] = new_verts
		new_mesh.add_surface_from_arrays(prim, arrays)

	_cached_geo.set_mesh(new_mesh)
	return _cached_geo
