class_name AttractPOP
extends GNPopBase
## Point attractor — pulls particles toward a target position.
## Processor: modifies the incoming SSBO in-place.

func _init() -> void:
	super._init()
	node_type = "attract"
	time_dependent = true


func _init_ports() -> void:
	add_input("pop_in", GNFamily.Type.POP, false, "Particle input", "Pop")
	add_output("out", GNFamily.Type.POP, "Particle data output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("target_x", 0.0, -100.0, 100.0, 0.1, "Target X", "Attractor X"))
	add_parameter(GNParameter.create_float("target_y", 1.0, -100.0, 100.0, 0.1, "Target Y", "Attractor Y"))
	add_parameter(GNParameter.create_float("target_z", 0.0, -100.0, 100.0, 0.1, "Target Z", "Attractor Z"))
	add_parameter(GNParameter.create_float("strength", 10.0,
		-100.0, 100.0, 0.1, "Strength", "Attraction force magnitude"))
	add_parameter(GNParameter.create_float("radius", 0.0,
		0.0, 1000.0, 0.1, "Radius", "Max influence radius (0 = infinite)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var pd := _get_input_pop(inputs)
	if pd == null or not pd.has_particles():
		return null

	pd = _mutable_input(pd) as GNParticleData

	var ctx := _get_ctx()
	if ctx.rd == null:
		return pd

	var shader: RID = ctx.get_shader("res://addons/gonodes/shaders/pop/attract_pop.glsl")
	if not shader.is_valid():
		return pd

	var pc := PackedByteArray()
	pc.resize(32)
	pc.encode_s32(0, pd.particle_count)
	pc.encode_float(4, current_delta)
	pc.encode_float(8, get_param_value("target_x"))
	pc.encode_float(12, get_param_value("target_y"))
	pc.encode_float(16, get_param_value("target_z"))
	pc.encode_float(20, get_param_value("strength"))
	pc.encode_float(24, get_param_value("radius"))
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

	pd = _mutable_input(pd) as GNParticleData

	var target := Vector3(
		get_param_value("target_x"),
		get_param_value("target_y"),
		get_param_value("target_z"))
	var strength: float = get_param_value("strength")
	var radius: float = get_param_value("radius")
	var dt: float = current_delta

	for i in range(pd.particle_count):
		var diff: Vector3 = target - pd.cpu_positions[i]
		var dist: float = diff.length()
		if dist < 0.001:
			continue
		if radius > 0.0 and dist > radius:
			continue
		var force_mag: float = strength / maxf(dist * dist, 0.01)
		pd.cpu_velocities[i] += diff.normalized() * force_mag * dt

	return pd
