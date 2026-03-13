class_name TurbulencePOP
extends GNPopBase
## Applies curl noise turbulence to particle velocities.
## Processor: modifies the incoming SSBO in-place.

func _init() -> void:
	super._init()
	node_type = "turbulence"
	node_description = "Apply curl noise turbulence to particle velocities."


func _init_ports() -> void:
	add_input("pop_in", GNFamily.Type.POP, false, "Particle input")
	add_output("out", GNFamily.Type.POP, "Particle data output")


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
