class_name CurlNoiseTOP
extends GNTopBase
## Generates a 2D curl noise vector field for fluid advection and flow effects.
## Output encodes the vector field as R=X, G=Y (remapped to 0-1), B=0, A=1.
## Use with DisplaceTOP or particle systems for organic, divergence-free motion.


func _init() -> void:
	node_type = "curl_noise"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Curl noise vector field (RG = XY)")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512),
		"Resolution", "Output resolution"))
	add_parameter(GNParameter.create_float("scale", 4.0, 0.1, 100.0, 0.1,
		"Scale", "Noise frequency / zoom level"))
	add_parameter(GNParameter.create_vector2("offset", Vector2.ZERO,
		"Offset", "Spatial offset for panning the noise field"))
	add_parameter(GNParameter.create_float("time_offset", 0.0, null, null, 0.01,
		"Time Offset", "Z-axis offset for animation (drive with LFO)"))
	add_parameter(GNParameter.create_int("seed", 0, 0, 99999,
		"Seed", "Random seed for noise variation"))
	add_parameter(GNParameter.create_int("octaves", 3, 1, 8,
		"Octaves", "FBM octave count (more = finer detail, slower)"))
	add_parameter(GNParameter.create_float("lacunarity", 2.0, 1.0, 4.0, 0.1,
		"Lacunarity", "Frequency multiplier per octave"))
	add_parameter(GNParameter.create_float("gain", 0.5, 0.0, 1.0, 0.01,
		"Gain", "Amplitude multiplier per octave"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var res: Vector2i = get_param_value("resolution")
	_init_shader_viewport("res://addons/gonodes/shaders/top/curl_noise.gdshader", false, false, res)

	if _viewport.size != res:
		_viewport.size = res

	_material.set_shader_parameter("scale", get_param_value("scale"))
	_material.set_shader_parameter("offset", get_param_value("offset"))
	_material.set_shader_parameter("time_offset", get_param_value("time_offset"))
	_material.set_shader_parameter("seed_val", get_param_value("seed"))
	_material.set_shader_parameter("octaves", get_param_value("octaves"))
	_material.set_shader_parameter("lacunarity", get_param_value("lacunarity"))
	_material.set_shader_parameter("gain", get_param_value("gain"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
