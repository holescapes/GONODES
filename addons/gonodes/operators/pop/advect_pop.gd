class_name AdvectPOP
extends GNPopBase
## Advects particles using a 3D velocity field from a VOL operator.
## Processor: modifies the incoming SSBO in-place.

func _init() -> void:
	super._init()
	node_type = "advect"
	node_description = "Advect particles through a VOL velocity field."
	time_dependent = true


func _init_ports() -> void:
	add_input("pop_in", GNFamily.Type.POP, false, "Particle input")
	add_input("vol_in", GNFamily.Type.VOL, false, "3D velocity field")
	add_output("out", GNFamily.Type.POP, "Particle data output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("strength", 1.0,
		0.0, 100.0, 0.1, "Strength", "Velocity field influence scale"))
	add_parameter(GNParameter.create_bool("add_mode", true, "Add to Velocity",
		"Add field velocity instead of replacing current velocity"))


func _cook(inputs: Array[GNData]) -> GNData:
	var pd := _get_input_pop(inputs, 0)
	if pd == null or not pd.has_particles():
		return null

	var vol: GNVolumeData = null
	if inputs.size() > 1 and inputs[1] is GNVolumeData:
		vol = inputs[1] as GNVolumeData
	if vol == null or not vol.has_volume():
		return pd  # Pass through without advection

	var ctx := _get_ctx()
	if ctx.rd == null:
		return pd

	var shader: RID = ctx.get_shader("res://addons/gonodes/shaders/pop/advect_pop.glsl")
	if not shader.is_valid():
		return pd

	# Create sampler for trilinear volume read
	var sampler: RID = ctx.create_linear_sampler()

	var pc := PackedByteArray()
	pc.resize(48)  # 10 fields (40 bytes) + padding to 48 (next multiple of 16)
	pc.encode_s32(0, pd.particle_count)
	pc.encode_float(4, current_delta)
	pc.encode_float(8, get_param_value("strength"))
	pc.encode_float(12, vol.bounds.position.x)
	pc.encode_float(16, vol.bounds.position.y)
	pc.encode_float(20, vol.bounds.position.z)
	pc.encode_float(24, vol.bounds.size.x)
	pc.encode_float(28, vol.bounds.size.y)
	pc.encode_float(32, vol.bounds.size.z)
	pc.encode_s32(36, 1 if get_param_value("add_mode") else 0)
	pc.encode_float(40, 0.0)  # padding
	pc.encode_float(44, 0.0)  # padding

	var uniform_set: RID = ctx.rd.uniform_set_create([
		ctx.uniform_buffer(0, pd.rd_buffer),
		ctx.uniform_sampler(1, sampler, vol.rd_texture),
	], shader, 0)

	ctx.dispatch(shader, uniform_set, _workgroups(pd.particle_count), 1, 1, pc)
	ctx.rd.free_rid(uniform_set)
	ctx.rd.free_rid(sampler)

	return pd
