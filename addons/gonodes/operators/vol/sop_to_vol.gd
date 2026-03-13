class_name SOPtoVOL
extends GNVolBase
## Rasterizes SOP point cloud / mesh vertices into a 3D density volume.
## Each vertex splatted as a smooth sphere with configurable radius.
## Uses GPU compute shader for fast parallel voxelization.

func _init() -> void:
	super._init()
	node_type = "soptovol"
	node_description = "Rasterize SOP geometry into a density volume."


func _init_ports() -> void:
	add_input("geo", GNFamily.Type.SOP, true, "Source geometry (points/vertices)")
	add_output("out", GNFamily.Type.VOL, "Density volume")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("res_x", 64, 8, 256, "Resolution X", "Grid width"))
	add_parameter(GNParameter.create_int("res_y", 64, 8, 256, "Resolution Y", "Grid height"))
	add_parameter(GNParameter.create_int("res_z", 64, 8, 256, "Resolution Z", "Grid depth"))
	add_parameter(GNParameter.create_float("radius", 0.05,
		0.001, 1.0, 0.001, "Radius", "Splat radius per point (world space)"))
	add_parameter(GNParameter.create_float("strength", 1.0,
		0.01, 10.0, 0.01, "Strength", "Density multiplier"))
	add_parameter(GNParameter.create_float("padding", 0.1,
		0.0, 2.0, 0.01, "Padding", "Extra padding around geometry bounds"))


func _cook(inputs: Array[GNData]) -> GNData:
	if inputs.size() == 0 or not (inputs[0] is GNGeoData):
		return null
	var geo: GNGeoData = inputs[0] as GNGeoData
	if not geo.has_geometry():
		return null

	var ctx := _get_ctx()
	if ctx.rd == null:
		return null

	# Collect all vertex positions
	var positions := PackedVector3Array()
	for s in range(geo.mesh.get_surface_count()):
		var arrays: Array = geo.mesh.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			positions.append_array(arrays[Mesh.ARRAY_VERTEX])

	if positions.is_empty():
		return null

	# Compute bounds from geometry + padding
	var pad: float = get_param_value("padding")
	var bmin := Vector3(INF, INF, INF)
	var bmax := Vector3(-INF, -INF, -INF)
	for p in positions:
		bmin = Vector3(minf(bmin.x, p.x), minf(bmin.y, p.y), minf(bmin.z, p.z))
		bmax = Vector3(maxf(bmax.x, p.x), maxf(bmax.y, p.y), maxf(bmax.z, p.z))
	bmin -= Vector3(pad, pad, pad)
	bmax += Vector3(pad, pad, pad)
	var bsize: Vector3 = bmax - bmin
	# Ensure non-zero size
	if bsize.x < 0.001: bsize.x = 1.0
	if bsize.y < 0.001: bsize.y = 1.0
	if bsize.z < 0.001: bsize.z = 1.0

	var res := Vector3i(get_param_value("res_x"), get_param_value("res_y"), get_param_value("res_z"))
	var radius: float = get_param_value("radius")
	var strength: float = get_param_value("strength")

	# Upload positions as SSBO (vec4 per point: xyz + weight=1.0)
	var pts_bytes := PackedByteArray()
	pts_bytes.resize(positions.size() * 16)
	for i in range(positions.size()):
		var off: int = i * 16
		pts_bytes.encode_float(off, positions[i].x)
		pts_bytes.encode_float(off + 4, positions[i].y)
		pts_bytes.encode_float(off + 8, positions[i].z)
		pts_bytes.encode_float(off + 12, 1.0)  # weight
	var pts_buf: RID = ctx.create_buffer(pts_bytes.size())
	ctx.rd.buffer_update(pts_buf, 0, pts_bytes.size(), pts_bytes)

	# Create output volume
	var out_vol := _create_volume(res, RenderingDevice.DATA_FORMAT_R32_SFLOAT, "density")
	out_vol.bounds = AABB(bmin, bsize)

	# Load and dispatch shader
	var shader: RID = ctx.get_shader("res://addons/gonodes/shaders/vol/sop_to_vol.glsl")
	if not shader.is_valid():
		ctx.free_rid(pts_buf)
		out_vol.free_gpu()
		return null

	# Push constants: 4 ints + 8 floats = 48 bytes
	var pc := PackedByteArray()
	pc.resize(48)
	pc.encode_s32(0, res.x)
	pc.encode_s32(4, res.y)
	pc.encode_s32(8, res.z)
	pc.encode_s32(12, positions.size())
	pc.encode_float(16, radius)
	pc.encode_float(20, strength)
	pc.encode_float(24, bmin.x)
	pc.encode_float(28, bmin.y)
	pc.encode_float(32, bmin.z)
	pc.encode_float(36, bsize.x)
	pc.encode_float(40, bsize.y)
	pc.encode_float(44, bsize.z)

	var us: RID = ctx.rd.uniform_set_create([
		ctx.uniform_image(0, out_vol.rd_texture),
		ctx.uniform_buffer(1, pts_buf),
	], shader, 0)

	var wg := _workgroups_3d(res)
	ctx.dispatch(shader, us, wg.x, wg.y, wg.z, pc)
	ctx.rd.free_rid(us)
	ctx.free_rid(pts_buf)

	return out_vol
