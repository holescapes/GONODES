class_name BlurVOL
extends GNVolBase
## 3D Gaussian blur on a volume. Ping-pong output (cannot blur in-place).

func _init() -> void:
	super._init()
	node_type = "blur"
	node_description = "3D Gaussian blur on a volume."


func _init_ports() -> void:
	add_input("vol_in", GNFamily.Type.VOL, false, "Volume input")
	add_output("out", GNFamily.Type.VOL, "Blurred volume")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("radius", 1,
		1, 4, "Radius", "Blur radius in voxels"))
	add_parameter(GNParameter.create_int("passes", 1,
		1, 4, "Passes", "Number of blur passes"))


func _cook(inputs: Array[GNData]) -> GNData:
	var vol_in := _get_input_vol(inputs)
	if vol_in == null or not vol_in.has_volume():
		return null

	var ctx := _get_ctx()
	if ctx.rd == null:
		return null

	var shader: RID = ctx.get_shader("res://addons/gonodes/shaders/vol/blur_vol.glsl")
	if not shader.is_valid():
		return null

	var res: Vector3i = vol_in.resolution
	var radius: int = get_param_value("radius")
	var passes: int = get_param_value("passes")
	var sampler: RID = ctx.create_linear_sampler()

	# Ping-pong between two textures
	var src_tex: RID = vol_in.rd_texture
	var dst_vol := _acquire_volume(res, vol_in.data_format, vol_in.field_name)

	var pc := PackedByteArray()
	pc.resize(32)
	pc.encode_s32(0, res.x)
	pc.encode_s32(4, res.y)
	pc.encode_s32(8, res.z)
	pc.encode_s32(12, radius)
	pc.encode_float(16, 0.0)
	pc.encode_float(20, 0.0)
	pc.encode_float(24, 0.0)
	pc.encode_float(28, 0.0)

	var wg := _workgroups_3d(res)
	var temp_vol: GNVolumeData = null

	for p in range(passes):
		var uniform_set: RID = ctx.rd.uniform_set_create([
			ctx.uniform_sampler(0, sampler, src_tex),
			ctx.uniform_image(1, dst_vol.rd_texture),
		], shader, 0)

		ctx.dispatch(shader, uniform_set, wg.x, wg.y, wg.z, pc)
		ctx.rd.free_rid(uniform_set)

		if p < passes - 1:
			# Swap for next pass
			if temp_vol == null:
				temp_vol = _acquire_volume(res, vol_in.data_format, vol_in.field_name)
			src_tex = dst_vol.rd_texture
			var swap := dst_vol
			dst_vol = temp_vol
			temp_vol = swap

	ctx.rd.free_rid(sampler)
	if temp_vol != null:
		temp_vol.release_to_pool()

	return dst_vol
