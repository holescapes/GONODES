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
	add_input("geo", GNFamily.Type.SOP, true, "Source geometry (points/vertices)", "Geometry")
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


func _cook_cpu(inputs: Array[GNData]) -> GNData:
	if inputs.size() == 0 or not (inputs[0] is GNGeoData):
		return null
	var geo: GNGeoData = inputs[0] as GNGeoData
	if not geo.has_geometry():
		return null

	var positions := PackedVector3Array()
	for s in range(geo.mesh.get_surface_count()):
		var arrays: Array = geo.mesh.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			positions.append_array(arrays[Mesh.ARRAY_VERTEX])
	if positions.is_empty():
		return null

	var pad: float = get_param_value("padding")
	var bmin := Vector3(INF, INF, INF)
	var bmax := Vector3(-INF, -INF, -INF)
	for p in positions:
		bmin = Vector3(minf(bmin.x, p.x), minf(bmin.y, p.y), minf(bmin.z, p.z))
		bmax = Vector3(maxf(bmax.x, p.x), maxf(bmax.y, p.y), maxf(bmax.z, p.z))
	bmin -= Vector3(pad, pad, pad)
	bmax += Vector3(pad, pad, pad)
	var bsize: Vector3 = bmax - bmin
	if bsize.x < 0.001: bsize.x = 1.0
	if bsize.y < 0.001: bsize.y = 1.0
	if bsize.z < 0.001: bsize.z = 1.0

	var res := Vector3i(get_param_value("res_x"), get_param_value("res_y"), get_param_value("res_z"))
	var radius: float = get_param_value("radius")
	var strength: float = get_param_value("strength")

	var out := _create_volume_cpu(res, 1, "density")
	out.bounds = AABB(bmin, bsize)

	# CPU splatting — smooth sphere at each vertex position
	var inv_size := Vector3(1.0 / bsize.x, 1.0 / bsize.y, 1.0 / bsize.z)
	var rad_voxels := Vector3i(
		ceili(radius * inv_size.x * res.x),
		ceili(radius * inv_size.y * res.y),
		ceili(radius * inv_size.z * res.z))

	for pt in positions:
		# Map world position to grid coords
		var gf := Vector3(
			(pt.x - bmin.x) * inv_size.x * float(res.x),
			(pt.y - bmin.y) * inv_size.y * float(res.y),
			(pt.z - bmin.z) * inv_size.z * float(res.z))
		var gc := Vector3i(int(gf.x), int(gf.y), int(gf.z))
		# Splat within radius
		for dz in range(-rad_voxels.z, rad_voxels.z + 1):
			var vz: int = gc.z + dz
			if vz < 0 or vz >= res.z: continue
			for dy in range(-rad_voxels.y, rad_voxels.y + 1):
				var vy: int = gc.y + dy
				if vy < 0 or vy >= res.y: continue
				for dx in range(-rad_voxels.x, rad_voxels.x + 1):
					var vx: int = gc.x + dx
					if vx < 0 or vx >= res.x: continue
					# World-space distance
					var wp := Vector3(
						bmin.x + (float(vx) + 0.5) / float(res.x) * bsize.x,
						bmin.y + (float(vy) + 0.5) / float(res.y) * bsize.y,
						bmin.z + (float(vz) + 0.5) / float(res.z) * bsize.z)
					var dist: float = pt.distance_to(wp)
					if dist < radius:
						var falloff: float = 1.0 - (dist / radius)
						out.cpu_data[_vol_idx(vx, vy, vz, res)] += strength * falloff

	return out
