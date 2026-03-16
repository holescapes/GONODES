class_name ForcePOP
extends GNPopBase
## Applies directional forces (gravity, wind) and drag to particles.
## Processor: modifies the incoming SSBO in-place.

func _init() -> void:
	super._init()
	node_type = "force"
	node_description = "Apply gravity, wind, and drag forces to particles."
	time_dependent = true


func _init_ports() -> void:
	add_input("pop_in", GNFamily.Type.POP, false, "Particle input")
	add_output("out", GNFamily.Type.POP, "Particle data output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("gravity_x", 0.0, -100.0, 100.0, 0.01, "Gravity X", "X gravity"))
	add_parameter(GNParameter.create_float("gravity_y", -9.81, -100.0, 100.0, 0.01, "Gravity Y", "Y gravity"))
	add_parameter(GNParameter.create_float("gravity_z", 0.0, -100.0, 100.0, 0.01, "Gravity Z", "Z gravity"))
	add_parameter(GNParameter.create_float("wind_x", 0.0, -100.0, 100.0, 0.01, "Wind X", "X wind force"))
	add_parameter(GNParameter.create_float("wind_y", 0.0, -100.0, 100.0, 0.01, "Wind Y", "Y wind force"))
	add_parameter(GNParameter.create_float("wind_z", 0.0, -100.0, 100.0, 0.01, "Wind Z", "Z wind force"))
	add_parameter(GNParameter.create_float("drag", 0.01, 0.0, 1.0, 0.01, "Drag", "Velocity damping per second"))


func _cook(inputs: Array[GNData]) -> GNData:
	var pd := _get_input_pop(inputs)
	if pd == null or not pd.has_particles():
		return null

	var ctx := _get_ctx()
	if ctx.rd == null:
		return pd

	var shader: RID = ctx.get_shader("res://addons/gonodes/shaders/pop/force_pop.glsl")
	if not shader.is_valid():
		return pd

	var fx: float = get_param_value("gravity_x") + get_param_value("wind_x")
	var fy: float = get_param_value("gravity_y") + get_param_value("wind_y")
	var fz: float = get_param_value("gravity_z") + get_param_value("wind_z")

	var pc := PackedByteArray()
	pc.resize(32)
	pc.encode_s32(0, pd.particle_count)
	pc.encode_float(4, current_delta)
	pc.encode_float(8, fx)
	pc.encode_float(12, fy)
	pc.encode_float(16, fz)
	pc.encode_float(20, get_param_value("drag"))
	pc.encode_float(24, 0.0)
	pc.encode_float(28, 0.0)

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

	var fx: float = get_param_value("gravity_x") + get_param_value("wind_x")
	var fy: float = get_param_value("gravity_y") + get_param_value("wind_y")
	var fz: float = get_param_value("gravity_z") + get_param_value("wind_z")
	var force := Vector3(fx, fy, fz)
	var drag: float = get_param_value("drag")
	var dt: float = current_delta

	for i in range(pd.particle_count):
		var vel: Vector3 = pd.cpu_velocities[i]
		vel += force * dt
		vel *= (1.0 - drag * dt)
		pd.cpu_velocities[i] = vel
		pd.cpu_positions[i] += vel * dt

	return pd
