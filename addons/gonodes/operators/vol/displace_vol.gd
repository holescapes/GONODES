class_name DisplaceVOL
extends GNVolBase
## Warps a density volume by a velocity field.

func _init() -> void:
	super._init()
	node_type = "displace"


func _init_ports() -> void:
	add_input("vol_in", GNFamily.Type.VOL, false, "Density volume", "Volume")
	add_input("vel_in", GNFamily.Type.VOL, false, "Velocity field (RGBA)", "Velocity")
	add_output("out", GNFamily.Type.VOL, "Displaced volume", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("strength", 1.0,
		0.0, 100.0, 0.1, "Strength", "Displacement multiplier"))


func _cook(inputs: Array[GNData]) -> GNData:
	var vol_in := _get_input_vol(inputs, 0)
	if vol_in == null or not vol_in.has_volume():
		return null

	var vel_in := _get_input_vol(inputs, 1)
	if vel_in == null or not vel_in.has_volume():
		return vol_in  # Pass through

	var ctx := _get_ctx()
	if ctx.rd == null:
		return null

	var shader: RID = ctx.get_shader("res://addons/gonodes/shaders/vol/displace_vol.glsl")
	if not shader.is_valid():
		return null

	var res: Vector3i = vol_in.resolution
	var out_vol := _create_volume(res, vol_in.data_format, vol_in.field_name)
	var sampler: RID = ctx.create_linear_sampler()

	var pc := PackedByteArray()
	pc.resize(32)
	pc.encode_s32(0, res.x)
	pc.encode_s32(4, res.y)
	pc.encode_s32(8, res.z)
	pc.encode_float(12, get_param_value("strength"))
	pc.encode_float(16, 0.0)
	pc.encode_float(20, 0.0)
	pc.encode_float(24, 0.0)
	pc.encode_float(28, 0.0)

	var uniform_set: RID = ctx.rd.uniform_set_create([
		ctx.uniform_sampler(0, sampler, vol_in.rd_texture),
		ctx.uniform_sampler(1, sampler, vel_in.rd_texture),
		ctx.uniform_image(2, out_vol.rd_texture),
	], shader, 0)

	var wg := _workgroups_3d(res)
	ctx.dispatch(shader, uniform_set, wg.x, wg.y, wg.z, pc)
	ctx.rd.free_rid(uniform_set)
	ctx.rd.free_rid(sampler)

	return out_vol


func _cook_cpu(inputs: Array[GNData]) -> GNData:
	var vol_in := _get_input_vol_cpu(inputs, 0)
	if vol_in == null or not vol_in.has_volume():
		return null

	var vel_in := _get_input_vol_cpu(inputs, 1)
	if vel_in == null or not vel_in.has_volume():
		return vol_in  # Pass through

	var strength: float = get_param_value("strength")
	var res: Vector3i = vol_in.resolution
	var ch: int = vol_in.channel_count
	var out := _create_volume_cpu(res, ch, vol_in.field_name)

	for z in range(res.z):
		for y in range(res.y):
			for x in range(res.x):
				# Read velocity at this voxel
				var vidx: int = (z * res.y * res.x + y * res.x + x) * vel_in.channel_count
				var vx: float = vel_in.cpu_data[vidx] if vidx < vel_in.cpu_data.size() else 0.0
				var vy: float = vel_in.cpu_data[vidx + 1] if vidx + 1 < vel_in.cpu_data.size() else 0.0
				var vz: float = vel_in.cpu_data[vidx + 2] if vidx + 2 < vel_in.cpu_data.size() else 0.0
				# Sample source at displaced position
				var uvw := Vector3(
					float(x) / float(res.x) - vx * strength,
					float(y) / float(res.y) - vy * strength,
					float(z) / float(res.z) - vz * strength)
				out.cpu_data[_vol_idx(x, y, z, res, ch)] = _vol_sample_trilinear(
					vol_in.cpu_data, uvw, res, ch)

	return out
