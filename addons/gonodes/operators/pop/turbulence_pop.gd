class_name TurbulencePOP
extends GNPopBase
## Applies curl noise turbulence to particle velocities.
## Processor: modifies the incoming SSBO in-place.

func _init() -> void:
	super._init()
	node_type = "turbulence"
	time_dependent = true


func _init_ports() -> void:
	add_input("pop_in", GNFamily.Type.POP, false, "Particle input", "Pop")
	add_output("out", GNFamily.Type.POP, "Particle data output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("amplitude", 2.0,
		0.0, 100.0, 0.1, "Amplitude", "Turbulence force strength"))
	add_parameter(GNParameter.create_float("frequency", 1.0,
		0.01, 50.0, 0.01, "Frequency", "Noise spatial frequency"))
	add_parameter(GNParameter.create_float("roughness", 0.5,
		0.0, 1.0, 0.01, "Roughness", "Octave amplitude gain"))
	add_parameter(GNParameter.create_int("octaves", 3,
		1, 8, "Octaves", "Number of noise octaves"))
	add_parameter(GNParameter.create_float("speed", 0.5,
		0.0, 10.0, 0.1, "Time Speed", "Time evolution speed for animated noise"))


func _cook(inputs: Array[GNData]) -> GNData:
	var pd := _get_input_pop(inputs)
	if pd == null or not pd.has_particles():
		return null

	var ctx := _get_ctx()
	if ctx.rd == null:
		return pd

	var shader: RID = ctx.get_shader("res://addons/gonodes/shaders/pop/turbulence_pop.glsl")
	if not shader.is_valid():
		return pd

	var pc := PackedByteArray()
	pc.resize(32)
	pc.encode_s32(0, pd.particle_count)
	pc.encode_float(4, current_delta)
	pc.encode_float(8, get_param_value("amplitude"))
	pc.encode_float(12, get_param_value("frequency"))
	pc.encode_float(16, elapsed_time * get_param_value("speed"))
	pc.encode_float(20, get_param_value("roughness"))
	pc.encode_s32(24, get_param_value("octaves"))
	pc.encode_float(28, 0.0)

	var uniform_set: RID = ctx.rd.uniform_set_create([
		ctx.uniform_buffer(0, pd.rd_buffer),
	], shader, 0)

	ctx.dispatch(shader, uniform_set, _workgroups(pd.particle_count), 1, 1, pc)
	ctx.rd.free_rid(uniform_set)

	return pd


func _cook_cpu(inputs: Array[GNData]) -> GNData:
	var pd := _get_input_pop_cpu(inputs)
	if pd == null or not pd.has_particles():
		return null

	var amplitude: float = get_param_value("amplitude")
	var frequency: float = get_param_value("frequency")
	var roughness: float = get_param_value("roughness")
	var octaves: int = get_param_value("octaves")
	var speed: float = get_param_value("speed")
	var dt: float = current_delta
	var t: float = elapsed_time * speed

	# Use FastNoiseLite for curl noise approximation
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	noise.fractal_gain = roughness

	for i in range(pd.particle_count):
		var pos: Vector3 = pd.cpu_positions[i]
		# Curl noise via finite differences of 3D noise
		var eps: float = 0.01
		var n_x0: float = noise.get_noise_3d(pos.x + eps, pos.y, pos.z + t)
		var n_x1: float = noise.get_noise_3d(pos.x - eps, pos.y, pos.z + t)
		var n_y0: float = noise.get_noise_3d(pos.x, pos.y + eps, pos.z + t)
		var n_y1: float = noise.get_noise_3d(pos.x, pos.y - eps, pos.z + t)
		var n_z0: float = noise.get_noise_3d(pos.x, pos.y, pos.z + eps + t)
		var n_z1: float = noise.get_noise_3d(pos.x, pos.y, pos.z - eps + t)
		var curl := Vector3(
			(n_y0 - n_y1) - (n_z0 - n_z1),
			(n_z0 - n_z1) - (n_x0 - n_x1),
			(n_x0 - n_x1) - (n_y0 - n_y1)
		) / (2.0 * eps)
		pd.cpu_velocities[i] += curl * amplitude * dt

	return pd
