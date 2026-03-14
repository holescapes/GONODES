class_name CollisionPOP
extends GNPopBase
## Ground plane collision with bounce and friction.
## Processor: modifies the incoming SSBO in-place.

func _init() -> void:
	super._init()
	node_type = "collision"
	node_description = "Ground plane collision with bounce and friction."
	time_dependent = true


func _init_ports() -> void:
	add_input("pop_in", GNFamily.Type.POP, false, "Particle input")
	add_output("out", GNFamily.Type.POP, "Particle data output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("ground_y", 0.0,
		-100.0, 100.0, 0.1, "Ground Y", "Ground plane Y position"))
	add_parameter(GNParameter.create_float("bounce", 0.3,
		0.0, 1.0, 0.01, "Bounce", "Restitution coefficient (0=absorb, 1=full bounce)"))
	add_parameter(GNParameter.create_float("friction", 0.1,
		0.0, 1.0, 0.01, "Friction", "Tangential velocity reduction on bounce"))
	add_parameter(GNParameter.create_float("kill_below", -1000.0,
		-10000.0, 100.0, 1.0, "Kill Below Y", "Kill particles below this Y (set very low to disable)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var pd := _get_input_pop(inputs)
	if pd == null or not pd.has_particles():
		return null

	var ctx := _get_ctx()
	if ctx.rd == null:
		return pd

	var shader: RID = ctx.get_shader("res://addons/gonodes/shaders/pop/collision_pop.glsl")
	if not shader.is_valid():
		return pd

	var pc := PackedByteArray()
	pc.resize(32)
	pc.encode_s32(0, pd.particle_count)
	pc.encode_float(4, current_delta)
	pc.encode_float(8, get_param_value("ground_y"))
	pc.encode_float(12, get_param_value("bounce"))
	pc.encode_float(16, get_param_value("friction"))
	pc.encode_float(20, get_param_value("kill_below"))
	pc.encode_float(24, 0.0)
	pc.encode_float(28, 0.0)

	var uniform_set: RID = ctx.rd.uniform_set_create([
		ctx.uniform_buffer(0, pd.rd_buffer),
	], shader, 0)

	ctx.dispatch(shader, uniform_set, _workgroups(pd.particle_count), 1, 1, pc)
	ctx.rd.free_rid(uniform_set)

	return pd
