class_name HeightfieldSOP
extends GNSopBase
## Procedural terrain generator via layered noise heightfield.
##
## Outputs a subdivided grid mesh displaced vertically by configurable
## noise layers (FBM). Supports thermal erosion for natural-looking terrain.

func _init() -> void:
	node_type = "heightfield"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.SOP, "Terrain mesh")


func _init_parameters() -> void:
	# Grid
	add_parameter(GNParameter.create_float("size_x", 10.0, 0.1, 1000.0, 0.1,
		"Size X", "Terrain width in world units"))
	add_parameter(GNParameter.create_float("size_z", 10.0, 0.1, 1000.0, 0.1,
		"Size Z", "Terrain depth in world units"))
	add_parameter(GNParameter.create_int("subdivisions", 128, 4, 512,
		"Subdivisions", "Grid resolution (rows and columns)"))

	# Noise layers
	add_parameter(GNParameter.create_float("height", 2.0, 0.0, 100.0, 0.1,
		"Height", "Maximum terrain height"))
	add_parameter(GNParameter.create_int("octaves", 6, 1, 12,
		"Octaves", "Noise layers (more = more detail)"))
	add_parameter(GNParameter.create_float("frequency", 1.0, 0.01, 20.0, 0.01,
		"Frequency", "Base noise frequency"))
	add_parameter(GNParameter.create_float("lacunarity", 2.0, 1.0, 4.0, 0.1,
		"Lacunarity", "Frequency multiplier per octave"))
	add_parameter(GNParameter.create_float("persistence", 0.5, 0.0, 1.0, 0.01,
		"Persistence", "Amplitude multiplier per octave"))
	add_parameter(GNParameter.create_int("seed", 0, 0, 99999,
		"Seed", "Random seed for terrain variation"))
	add_parameter(GNParameter.create_float("offset_x", 0.0, null, null, 0.1,
		"Offset X", "Noise X offset for panning"))
	add_parameter(GNParameter.create_float("offset_z", 0.0, null, null, 0.1,
		"Offset Z", "Noise Z offset for panning"))

	# Noise type
	add_parameter(GNParameter.create_enum("noise_type",
		PackedStringArray(["Simplex", "Perlin", "Cellular", "Value"]),
		0, "Noise Type", "Underlying noise algorithm"))

	# Erosion
	add_parameter(GNParameter.create_int("erosion_iters", 0, 0, 100,
		"Erosion Iterations", "Thermal erosion passes (0 = disabled)"))
	add_parameter(GNParameter.create_float("erosion_strength", 0.05, 0.001, 0.5, 0.001,
		"Erosion Strength", "Material transfer rate per iteration"))
	add_parameter(GNParameter.create_float("talus_angle", 0.6, 0.01, 2.0, 0.01,
		"Talus Angle", "Maximum stable slope (higher = steeper terrain survives)"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var size_x: float = get_param_value("size_x")
	var size_z: float = get_param_value("size_z")
	var subdivs: int = get_param_value("subdivisions")
	var max_height: float = get_param_value("height")
	var octaves_val: int = get_param_value("octaves")
	var freq: float = get_param_value("frequency")
	var lac: float = get_param_value("lacunarity")
	var persist: float = get_param_value("persistence")
	var seed_val: int = get_param_value("seed")
	var off_x: float = get_param_value("offset_x")
	var off_z: float = get_param_value("offset_z")
	var noise_type_idx: int = get_param_value("noise_type")
	var erosion_iters: int = get_param_value("erosion_iters")
	var erosion_str: float = get_param_value("erosion_strength")
	var talus: float = get_param_value("talus_angle")

	var rows: int = subdivs + 1
	var cols: int = subdivs + 1

	# Configure noise
	var noise := FastNoiseLite.new()
	noise.seed = seed_val
	match noise_type_idx:
		0: noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		1: noise.noise_type = FastNoiseLite.TYPE_PERLIN
		2: noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		3: noise.noise_type = FastNoiseLite.TYPE_VALUE
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves_val
	noise.fractal_lacunarity = lac
	noise.fractal_gain = persist
	noise.frequency = freq

	# Generate heightmap
	var heights := PackedFloat32Array()
	heights.resize(rows * cols)
	for z in range(rows):
		for x in range(cols):
			var world_x: float = (float(x) / float(cols - 1)) * size_x - size_x * 0.5
			var world_z: float = (float(z) / float(rows - 1)) * size_z - size_z * 0.5
			var n: float = noise.get_noise_2d(world_x + off_x, world_z + off_z)
			# FastNoiseLite returns [-1, 1] — remap to [0, 1]
			heights[z * cols + x] = (n * 0.5 + 0.5) * max_height

	# Thermal erosion
	if erosion_iters > 0:
		_thermal_erosion(heights, rows, cols, erosion_iters, erosion_str, talus)

	# Build mesh with SurfaceTool
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Add vertices with UVs
	for z in range(rows):
		for x in range(cols):
			var px: float = (float(x) / float(cols - 1)) * size_x - size_x * 0.5
			var pz: float = (float(z) / float(rows - 1)) * size_z - size_z * 0.5
			var py: float = heights[z * cols + x]
			var uv := Vector2(float(x) / float(cols - 1), float(z) / float(rows - 1))
			st.set_uv(uv)
			st.add_vertex(Vector3(px, py, pz))

	# Generate triangle indices
	for z in range(rows - 1):
		for x in range(cols - 1):
			var tl: int = z * cols + x
			var tr: int = tl + 1
			var bl: int = (z + 1) * cols + x
			var br: int = bl + 1
			# Triangle 1
			st.add_index(tl)
			st.add_index(bl)
			st.add_index(tr)
			# Triangle 2
			st.add_index(tr)
			st.add_index(bl)
			st.add_index(br)

	st.generate_normals()
	st.generate_tangents()

	var geo := _prepare_geo()
	geo.set_from_surface_tool(st)
	geo.valid = true
	geo.timestamp = current_frame
	return geo


## Simple thermal erosion: redistribute material from steep slopes to neighbors.
func _thermal_erosion(heights: PackedFloat32Array, rows: int, cols: int,
		iterations: int, strength: float, talus_angle: float) -> void:
	for _iter in range(iterations):
		for z in range(1, rows - 1):
			for x in range(1, cols - 1):
				var idx: int = z * cols + x
				var h: float = heights[idx]
				var max_diff: float = 0.0
				var max_idx: int = -1

				# Check 4-connected neighbors
				var neighbors := [
					idx - 1, idx + 1,
					idx - cols, idx + cols
				]
				for ni in neighbors:
					var diff: float = h - heights[ni]
					if diff > max_diff:
						max_diff = diff
						max_idx = ni

				# Transfer material if slope exceeds talus angle
				if max_diff > talus_angle and max_idx >= 0:
					var transfer: float = strength * (max_diff - talus_angle) * 0.5
					heights[idx] -= transfer
					heights[max_idx] += transfer
