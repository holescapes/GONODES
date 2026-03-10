class_name MountainSOP
extends GNSopBase
## Noise-based vertex displacement ("Mountain" deformer).
##
## Displaces each vertex along its normal by a noise-driven amount.
## Uses Godot's FastNoiseLite for procedural noise generation.
## Great for terrain generation, organic surface variation, etc.

func _init() -> void:
	node_type = "mountain"
	node_description = "Noise-based vertex displacement along normals."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry to displace")
	add_output("out", GNFamily.Type.SOP, "Displaced geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("height", 0.5, 0.0, 100.0, 0.01,
		"Height", "Maximum displacement amplitude"))
	add_parameter(GNParameter.create_float("frequency", 2.0, 0.01, 50.0, 0.01,
		"Frequency", "Noise spatial frequency"))
	add_parameter(GNParameter.create_int("octaves", 4, 1, 8, "Octaves", "Fractal noise octaves"))
	add_parameter(GNParameter.create_float("lacunarity", 2.0, 0.1, 10.0, 0.01,
		"Lacunarity", "Frequency multiplier per octave"))
	add_parameter(GNParameter.create_float("persistence", 0.5, 0.0, 1.0, 0.01,
		"Persistence", "Amplitude multiplier per octave (gain)"))
	add_parameter(GNParameter.create_int("seed", 0, 0, 9999, "Seed", "Noise seed"))
	add_parameter(GNParameter.create_enum("noise_type",
		PackedStringArray(["Simplex", "Perlin", "Cellular", "Value"]), 0,
		"Noise Type", "Underlying noise algorithm"))
	add_parameter(GNParameter.create_float("offset_x", 0.0, -1000.0, 1000.0, 0.01, "Offset X", "Noise offset X"))
	add_parameter(GNParameter.create_float("offset_y", 0.0, -1000.0, 1000.0, 0.01, "Offset Y", "Noise offset Y"))
	add_parameter(GNParameter.create_float("offset_z", 0.0, -1000.0, 1000.0, 0.01, "Offset Z", "Noise offset Z"))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo: GNGeoData = _require_input_geo(inputs)
	if geo == null:
		return null

	var height_val: float = get_param_value("height")
	var freq: float = get_param_value("frequency")
	var octaves_val: int = get_param_value("octaves")
	var lac: float = get_param_value("lacunarity")
	var persist: float = get_param_value("persistence")
	var noise_seed: int = get_param_value("seed")
	var noise_type_idx: int = get_param_value("noise_type")
	var off_x: float = get_param_value("offset_x")
	var off_y: float = get_param_value("offset_y")
	var off_z: float = get_param_value("offset_z")

	# Configure noise
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = freq
	noise.fractal_octaves = octaves_val
	noise.fractal_lacunarity = lac
	noise.fractal_gain = persist
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM

	match noise_type_idx:
		0: noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		1: noise.noise_type = FastNoiseLite.TYPE_PERLIN
		2: noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		3: noise.noise_type = FastNoiseLite.TYPE_VALUE

	var offset := Vector3(off_x, off_y, off_z)

	# Process geometry
	var output: GNGeoData = _prepare_geo()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for surf_idx in range(geo.get_surface_count()):
		var arrays: Array = geo.get_surface_arrays(surf_idx)
		if arrays.is_empty():
			continue

		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals = arrays[Mesh.ARRAY_NORMAL]
		var uvs = arrays[Mesh.ARRAY_TEX_UV]

		# If no normals, we'll use UP as fallback
		var has_normals: bool = normals != null and normals.size() == positions.size()

		for i in range(positions.size()):
			var p: Vector3 = positions[i]
			var n: Vector3 = normals[i] if has_normals else Vector3.UP

			# Sample noise at vertex position + offset
			var sample_pos: Vector3 = p + offset
			var noise_val: float = noise.get_noise_3d(sample_pos.x, sample_pos.y, sample_pos.z)
			# noise_val is in [-1, 1], map to [0, height]
			var displacement: float = (noise_val * 0.5 + 0.5) * height_val

			var new_pos: Vector3 = p + n * displacement

			st.set_normal(n)
			if uvs != null and i < uvs.size():
				st.set_uv(uvs[i])
			st.add_vertex(new_pos)

	st.generate_normals()
	output.set_from_surface_tool(st)
	return output
