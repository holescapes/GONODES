class_name HeightfieldSOPNative
extends GNSopBase
## Native-accelerated heightfield generation — delegates to GNNativeHeightfieldSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "heightfield_native"
	if ClassDB.class_exists("GNNativeHeightfieldSop"):
		_processor = ClassDB.instantiate("GNNativeHeightfieldSop")


func _init_ports() -> void:
	add_output("out", GNFamily.Type.SOP, "Terrain mesh")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("size_x", 10.0, 0.1, 1000.0, 0.1,
		"Size X", "Terrain width"))
	add_parameter(GNParameter.create_float("size_z", 10.0, 0.1, 1000.0, 0.1,
		"Size Z", "Terrain depth"))
	add_parameter(GNParameter.create_int("subdivisions", 128, 4, 512,
		"Subdivisions", "Grid resolution"))
	add_parameter(GNParameter.create_float("height", 2.0, 0.0, 100.0, 0.1,
		"Height", "Maximum height"))
	add_parameter(GNParameter.create_int("octaves", 6, 1, 12,
		"Octaves", "Noise octaves"))
	add_parameter(GNParameter.create_float("frequency", 1.0, 0.01, 20.0, 0.01,
		"Frequency", "Noise base frequency"))
	add_parameter(GNParameter.create_float("lacunarity", 2.0, 1.0, 4.0, 0.1,
		"Lacunarity", "Frequency multiplier per octave"))
	add_parameter(GNParameter.create_float("persistence", 0.5, 0.0, 1.0, 0.01,
		"Persistence", "Amplitude decay per octave"))
	add_parameter(GNParameter.create_int("seed", 0, 0, 99999,
		"Seed", "Noise seed"))


func _cook(inputs: Array[GNData]) -> GNData:
	if not _processor:
		return null

	var size_x: float = get_param_value("size_x")
	var size_z: float = get_param_value("size_z")
	var subdiv: int = get_param_value("subdivisions")
	var height_val: float = get_param_value("height")

	# Generate height data using Godot's FastNoiseLite
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.seed = get_param_value("seed")
	noise.fractal_octaves = get_param_value("octaves")
	noise.frequency = get_param_value("frequency")
	noise.fractal_lacunarity = get_param_value("lacunarity")
	noise.fractal_gain = get_param_value("persistence")

	var rows: int = subdiv
	var cols: int = subdiv
	var heights := PackedFloat32Array()
	heights.resize(rows * cols)
	for r in range(rows):
		for c in range(cols):
			var nx: float = float(c) / float(cols - 1) * size_x
			var nz: float = float(r) / float(rows - 1) * size_z
			heights[r * cols + c] = noise.get_noise_2d(nx, nz)

	var result: Dictionary = _processor.process(heights, rows, cols, size_x, size_z, height_val)

	var out := _prepare_geo()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = result["vertices"]
	arrays[Mesh.ARRAY_NORMAL] = result["normals"]
	arrays[Mesh.ARRAY_TEX_UV] = result["uvs"]
	arrays[Mesh.ARRAY_INDEX] = result["indices"]
	var new_mesh := ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	out.mesh = new_mesh
	return out
