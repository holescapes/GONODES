class_name BoidsPOP
extends GNPopBase
## Flocking / boids simulation on GPU particles using Reynolds rules:
## separation, alignment, cohesion.  Brute-force O(n²) neighbor search
## in a compute shader — performant up to ~50k particles on modern GPUs.

func _init() -> void:
	super._init()
	node_type = "boids"
	node_description = "Flocking boids simulation — separation, alignment, cohesion."
	time_dependent = true


func _init_ports() -> void:
	add_input("pop_in", GNFamily.Type.POP, false, "Particle input", "Pop")
	add_output("out", GNFamily.Type.POP, "Particle data output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("perception_radius", 2.0,
		0.1, 50.0, 0.01, "Perception Radius", "Neighbor search radius"))
	add_parameter(GNParameter.create_float("avoid_radius", 0.5,
		0.01, 10.0, 0.01, "Avoid Radius", "Minimum separation distance"))
	add_parameter(GNParameter.create_float("separation", 1.5,
		0.0, 10.0, 0.01, "Separation", "Separation weight"))
	add_parameter(GNParameter.create_float("alignment", 1.0,
		0.0, 10.0, 0.01, "Alignment", "Alignment weight"))
	add_parameter(GNParameter.create_float("cohesion", 1.0,
		0.0, 10.0, 0.01, "Cohesion", "Cohesion weight"))
	add_parameter(GNParameter.create_float("max_speed", 5.0,
		0.1, 100.0, 0.01, "Max Speed", "Maximum velocity magnitude"))
	add_parameter(GNParameter.create_float("max_force", 3.0,
		0.1, 100.0, 0.01, "Max Force", "Maximum steering force"))
	add_parameter(GNParameter.create_float("bounds_radius", 10.0,
		0.0, 1000.0, 0.1, "Bounds Radius", "Spherical boundary (0 = none)"))
	add_parameter(GNParameter.create_float("bounds_force", 5.0,
		0.0, 50.0, 0.1, "Bounds Force", "Boundary containment strength"))


func _cook(inputs: Array[GNData]) -> GNData:
	var pd := _get_input_pop(inputs)
	if pd == null or not pd.has_particles():
		return null

	var ctx := _get_ctx()
	if ctx.rd == null:
		return _cook_cpu_fallback(pd)

	var shader: RID = ctx.get_shader("res://addons/gonodes/shaders/pop/boids_pop.glsl")
	if not shader.is_valid():
		return _cook_cpu_fallback(pd)

	# Push constants: 12 values × 4 bytes = 48 bytes
	var pc := PackedByteArray()
	pc.resize(48)
	pc.encode_s32(0, pd.particle_count)
	pc.encode_float(4, current_delta)
	pc.encode_float(8, get_param_value("perception_radius"))
	pc.encode_float(12, get_param_value("separation"))
	pc.encode_float(16, get_param_value("alignment"))
	pc.encode_float(20, get_param_value("cohesion"))
	pc.encode_float(24, get_param_value("max_speed"))
	pc.encode_float(28, get_param_value("max_force"))
	pc.encode_float(32, get_param_value("avoid_radius"))
	pc.encode_float(36, get_param_value("bounds_radius"))
	pc.encode_float(40, get_param_value("bounds_force"))
	pc.encode_float(44, elapsed_time)

	var uniform_set: RID = ctx.rd.uniform_set_create([
		ctx.uniform_buffer(0, pd.rd_buffer),
	], shader, 0)

	ctx.dispatch(shader, uniform_set, _workgroups(pd.particle_count), 1, 1, pc)
	ctx.rd.free_rid(uniform_set)

	return pd  # Modified in-place


func _cook_cpu(inputs: Array[GNData]) -> GNData:
	var pd := _get_input_pop_cpu(inputs)
	if pd == null or not pd.has_particles():
		return null
	return _cook_cpu_fallback(pd)


func _cook_cpu_fallback(pd: GNParticleData) -> GNParticleData:
	var dt: float = current_delta
	var percep_r: float = get_param_value("perception_radius")
	var avoid_r: float = get_param_value("avoid_radius")
	var sep_w: float = get_param_value("separation")
	var ali_w: float = get_param_value("alignment")
	var coh_w: float = get_param_value("cohesion")
	var max_spd: float = get_param_value("max_speed")
	var max_frc: float = get_param_value("max_force")
	var bounds_r: float = get_param_value("bounds_radius")
	var bounds_f: float = get_param_value("bounds_force")

	var r2: float = percep_r * percep_r
	var avoid_r2: float = avoid_r * avoid_r
	var n: int = pd.particle_count

	for i in range(n):
		if pd.cpu_ages[i] >= pd.cpu_lives[i]:
			continue

		var my_pos: Vector3 = pd.cpu_positions[i]
		var my_vel: Vector3 = pd.cpu_velocities[i]

		var sep_sum := Vector3.ZERO
		var ali_sum := Vector3.ZERO
		var coh_sum := Vector3.ZERO
		var sep_count: int = 0
		var ali_count: int = 0
		var coh_count: int = 0

		for j in range(n):
			if j == i:
				continue
			if pd.cpu_ages[j] >= pd.cpu_lives[j]:
				continue
			var diff: Vector3 = my_pos - pd.cpu_positions[j]
			var d2: float = diff.length_squared()
			if d2 > r2 or d2 < 0.0001:
				continue

			if d2 < avoid_r2:
				sep_sum += diff / maxf(d2, 0.0001)
				sep_count += 1

			ali_sum += pd.cpu_velocities[j]
			ali_count += 1
			coh_sum += pd.cpu_positions[j]
			coh_count += 1

		var steer := Vector3.ZERO

		if sep_count > 0:
			var desired: Vector3 = (sep_sum / float(sep_count)).normalized() * max_spd
			steer += _clamp_vec(desired - my_vel, max_frc) * sep_w

		if ali_count > 0:
			var avg_vel: Vector3 = ali_sum / float(ali_count)
			var desired: Vector3 = avg_vel.normalized() * max_spd
			steer += _clamp_vec(desired - my_vel, max_frc) * ali_w

		if coh_count > 0:
			var center: Vector3 = coh_sum / float(coh_count)
			var desired: Vector3 = (center - my_pos).normalized() * max_spd
			steer += _clamp_vec(desired - my_vel, max_frc) * coh_w

		if bounds_r > 0.0:
			var dist: float = my_pos.length()
			if dist > bounds_r * 0.8:
				var to_center: Vector3 = -my_pos.normalized()
				var urgency: float = smoothstep(bounds_r * 0.8, bounds_r, dist)
				steer += to_center * urgency * bounds_f

		var new_vel: Vector3 = my_vel + steer * dt
		if new_vel.length() > max_spd:
			new_vel = new_vel.normalized() * max_spd

		pd.cpu_velocities[i] = new_vel
		pd.cpu_positions[i] += new_vel * dt
		pd.cpu_ages[i] += dt

	return pd


static func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t: float = clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _clamp_vec(v: Vector3, max_len: float) -> Vector3:
	var len: float = v.length()
	return v * (max_len / len) if len > max_len else v
