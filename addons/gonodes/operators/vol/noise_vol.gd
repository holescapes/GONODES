class_name NoiseVOL
extends GNVolBase
## Generates a 3D noise density volume.
## Generator: allocates a 3D texture and fills with FBM noise.

func _init() -> void:
	super._init()
	node_type = "noise"
	time_dependent = true  # shader uses elapsed_time * speed


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("res_x", 64, 8, 512, "Resolution X", "Volume width in voxels"))
	add_parameter(GNParameter.create_int("res_y", 64, 8, 512, "Resolution Y", "Volume height in voxels"))
	add_parameter(GNParameter.create_int("res_z", 64, 8, 512, "Resolution Z", "Volume depth in voxels"))
	add_parameter(GNParameter.create_float("frequency", 4.0, 0.01, 100.0, 0.01, "Frequency", "Noise frequency"))
	add_parameter(GNParameter.create_float("amplitude", 1.0, 0.0, 10.0, 0.01, "Amplitude", "Noise amplitude"))
	add_parameter(GNParameter.create_int("octaves", 4, 1, 8, "Octaves", "FBM octaves"))
	add_parameter(GNParameter.create_float("lacunarity", 2.0, 1.0, 4.0, 0.01, "Lacunarity", "Frequency multiplier per octave"))
	add_parameter(GNParameter.create_float("gain", 0.5, 0.0, 1.0, 0.01, "Gain", "Amplitude multiplier per octave"))
	add_parameter(GNParameter.create_float("offset_x", 0.0, -100.0, 100.0, 0.1, "Offset X", "Noise offset X"))
	add_parameter(GNParameter.create_float("offset_y", 0.0, -100.0, 100.0, 0.1, "Offset Y", "Noise offset Y"))
	add_parameter(GNParameter.create_float("offset_z", 0.0, -100.0, 100.0, 0.1, "Offset Z", "Noise offset Z"))
	add_parameter(GNParameter.create_float("speed", 0.0, 0.0, 10.0, 0.1, "Time Speed", "Animate noise over time"))
	add_parameter(GNParameter.create_string("format", "R32F", "Format",
		"Texel format: R16F, R32F"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var ctx := _get_ctx()
	if ctx.rd == null:
		return null

	var res := Vector3i(get_param_value("res_x"), get_param_value("res_y"), get_param_value("res_z"))
	var fmt: int = _parse_format(get_param_value("format"))
	var vol := _create_volume(res, fmt, "density")

	var shader: RID = ctx.get_shader("res://addons/gonodes/shaders/vol/noise_vol.glsl")
	if not shader.is_valid():
		return null

	var pc := PackedByteArray()
	pc.resize(48)
	pc.encode_s32(0, res.x)
	pc.encode_s32(4, res.y)
	pc.encode_s32(8, res.z)
	pc.encode_float(12, get_param_value("frequency"))
	pc.encode_float(16, get_param_value("amplitude"))
	pc.encode_float(20, get_param_value("offset_x"))
	pc.encode_float(24, get_param_value("offset_y"))
	pc.encode_float(28, get_param_value("offset_z"))
	pc.encode_float(32, elapsed_time * get_param_value("speed"))
	pc.encode_float(36, get_param_value("lacunarity"))
	pc.encode_float(40, get_param_value("gain"))
	pc.encode_s32(44, get_param_value("octaves"))

	var uniform_set: RID = ctx.rd.uniform_set_create([
		ctx.uniform_image(0, vol.rd_texture),
	], shader, 0)

	var wg := _workgroups_3d(res)
	ctx.dispatch(shader, uniform_set, wg.x, wg.y, wg.z, pc)
	ctx.rd.free_rid(uniform_set)

	return vol


func _parse_format(fmt_str: String) -> int:
	match fmt_str.to_upper():
		"R16F":  return RenderingDevice.DATA_FORMAT_R16_SFLOAT
		"RGBA16F": return RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
		"RGBA32F": return RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	return RenderingDevice.DATA_FORMAT_R32_SFLOAT


func _cook_cpu(_inputs: Array[GNData]) -> GNData:
	var res := Vector3i(get_param_value("res_x"), get_param_value("res_y"), get_param_value("res_z"))
	var vol := _create_volume_cpu(res, 1, "density")

	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = get_param_value("frequency")
	noise.fractal_octaves = get_param_value("octaves")
	noise.fractal_lacunarity = get_param_value("lacunarity")
	noise.fractal_gain = get_param_value("gain")

	var amplitude: float = get_param_value("amplitude")
	var ox: float = get_param_value("offset_x")
	var oy: float = get_param_value("offset_y")
	var oz: float = get_param_value("offset_z")
	var t: float = elapsed_time * get_param_value("speed")

	for z in range(res.z):
		for y in range(res.y):
			for x in range(res.x):
				var nx: float = float(x) / float(res.x) + ox
				var ny: float = float(y) / float(res.y) + oy
				var nz: float = float(z) / float(res.z) + oz + t
				var v: float = noise.get_noise_3d(nx, ny, nz) * amplitude
				vol.cpu_data[_vol_idx(x, y, z, res)] = v

	return vol
