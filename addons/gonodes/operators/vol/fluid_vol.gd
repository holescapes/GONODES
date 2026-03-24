class_name FluidVOL
extends GNVolBase
## Navier-Stokes fluid simulation on a 3D volume.
## Time-dependent: maintains velocity + density fields across frames.

var _velocity: GNVolumeData = null   # RGBA32F velocity field
var _density: GNVolumeData = null    # R32F density field
var _pressure_a: GNVolumeData = null # Ping-pong pressure A
var _pressure_b: GNVolumeData = null # Ping-pong pressure B
var _divergence: GNVolumeData = null # Divergence field
var _last_res: Vector3i = Vector3i.ZERO


func _init() -> void:
	super._init()
	node_type = "fluid"
	time_dependent = true


func _init_ports() -> void:
	add_input("density_in", GNFamily.Type.VOL, false, "Density source (added each frame)", "Density")
	add_input("vel_in", GNFamily.Type.VOL, false, "External velocity force (optional)", "Velocity")
	add_input("obstacle", GNFamily.Type.VOL, true, "Obstacle mask volume (R > 0.5 = solid)")
	add_output("density_out", GNFamily.Type.VOL, "Simulated density field", "Density")
	add_output("velocity_out", GNFamily.Type.VOL, "Simulated velocity field", "Velocity")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("res_x", 64, 8, 256, "Resolution X", "Grid width"))
	add_parameter(GNParameter.create_int("res_y", 64, 8, 256, "Resolution Y", "Grid height"))
	add_parameter(GNParameter.create_int("res_z", 64, 8, 256, "Resolution Z", "Grid depth"))
	add_parameter(GNParameter.create_float("dissipation", 0.98,
		0.8, 1.0, 0.01, "Dissipation", "Density decay per step (0.99=slow, 0.9=fast)"))
	add_parameter(GNParameter.create_int("pressure_iters", 20,
		5, 50, "Pressure Iterations", "Jacobi solver iterations"))
	add_parameter(GNParameter.create_float("density_add", 1.0,
		0.0, 10.0, 0.1, "Density Add", "Scale factor for density injection"))
	add_parameter(GNParameter.create_float("vorticity", 0.3,
		0.0, 5.0, 0.01, "Vorticity", "Vorticity confinement strength (0 = off)"))
	add_parameter(GNParameter.create_bool("reset", false, "Reset", "Clear simulation"))


func _cook(inputs: Array[GNData]) -> GNData:
	var ctx := _get_ctx()
	if ctx.rd == null:
		return null

	var res := Vector3i(get_param_value("res_x"), get_param_value("res_y"), get_param_value("res_z"))
	var dt: float = current_delta

	# Allocate or reset
	if get_param_value("reset") or _velocity == null or _last_res != res:
		_free_fields()
		_velocity = _create_volume(res, RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT, "velocity")
		_density = _create_volume(res, RenderingDevice.DATA_FORMAT_R32_SFLOAT, "density")
		_pressure_a = _create_volume(res, RenderingDevice.DATA_FORMAT_R32_SFLOAT, "pressure")
		_pressure_b = _create_volume(res, RenderingDevice.DATA_FORMAT_R32_SFLOAT, "pressure")
		_divergence = _create_volume(res, RenderingDevice.DATA_FORMAT_R32_SFLOAT, "divergence")
		_last_res = res
		set_param_value("reset", false)

	var sampler: RID = ctx.create_linear_sampler()
	var wg := _workgroups_3d(res)
	var res_pc := PackedByteArray()
	res_pc.resize(16)
	res_pc.encode_s32(0, res.x)
	res_pc.encode_s32(4, res.y)
	res_pc.encode_s32(8, res.z)
	res_pc.encode_float(12, 0.0)

	# --- Step 1: Inject density source ---
	var den_in := _get_input_vol(inputs, 0)
	if den_in != null and den_in.has_volume():
		var blend_shader: RID = ctx.get_shader("res://addons/gonodes/shaders/vol/blend_vol.glsl")
		if blend_shader.is_valid():
			var blend_pc := PackedByteArray()
			blend_pc.resize(32)
			blend_pc.encode_s32(0, res.x)
			blend_pc.encode_s32(4, res.y)
			blend_pc.encode_s32(8, res.z)
			blend_pc.encode_s32(12, 0)  # add
			blend_pc.encode_float(16, 0.0)
			blend_pc.encode_float(20, 1.0)
			blend_pc.encode_float(24, get_param_value("density_add") * dt)
			blend_pc.encode_float(28, 0.0)
			var temp := _acquire_volume(res, _density.data_format, "density")
			var us: RID = ctx.rd.uniform_set_create([
				ctx.uniform_image(0, _density.rd_texture),
				ctx.uniform_image(1, den_in.rd_texture),
				ctx.uniform_image(2, temp.rd_texture),
			], blend_shader, 0)
			ctx.dispatch(blend_shader, us, wg.x, wg.y, wg.z, blend_pc)
			ctx.rd.free_rid(us)
			# Swap temp → density
			var old_tex: RID = _density.rd_texture
			_density.rd_texture = temp.rd_texture
			ctx.free_rid(old_tex)

	# --- Step 2: Advect density by velocity ---
	var advect_shader: RID = ctx.get_shader("res://addons/gonodes/shaders/vol/fluid_advect.glsl")
	if advect_shader.is_valid():
		var adv_out := _acquire_volume(res, _density.data_format, "density")
		var adv_pc := PackedByteArray()
		adv_pc.resize(32)
		adv_pc.encode_s32(0, res.x)
		adv_pc.encode_s32(4, res.y)
		adv_pc.encode_s32(8, res.z)
		adv_pc.encode_float(12, dt)
		adv_pc.encode_float(16, get_param_value("dissipation"))
		adv_pc.encode_float(20, 0.0)
		adv_pc.encode_float(24, 0.0)
		adv_pc.encode_float(28, 0.0)
		var us: RID = ctx.rd.uniform_set_create([
			ctx.uniform_sampler(0, sampler, _velocity.rd_texture),
			ctx.uniform_sampler(1, sampler, _density.rd_texture),
			ctx.uniform_image(2, adv_out.rd_texture),
		], advect_shader, 0)
		ctx.dispatch(advect_shader, us, wg.x, wg.y, wg.z, adv_pc)
		ctx.rd.free_rid(us)
		var old: RID = _density.rd_texture
		_density.rd_texture = adv_out.rd_texture
		ctx.free_rid(old)

	# --- Step 2b: Vorticity confinement ---
	var vort_str: float = get_param_value("vorticity")
	if vort_str > 0.0:
		var vort_shader: RID = ctx.get_shader("res://addons/gonodes/shaders/vol/fluid_vorticity.glsl")
		if vort_shader.is_valid():
			var vel_out := _acquire_volume(res, _velocity.data_format, "velocity")
			var vort_pc := PackedByteArray()
			vort_pc.resize(32)
			vort_pc.encode_s32(0, res.x)
			vort_pc.encode_s32(4, res.y)
			vort_pc.encode_s32(8, res.z)
			vort_pc.encode_float(12, vort_str)
			vort_pc.encode_float(16, dt)
			vort_pc.encode_float(20, 0.0)
			vort_pc.encode_float(24, 0.0)
			vort_pc.encode_float(28, 0.0)
			var us: RID = ctx.rd.uniform_set_create([
				ctx.uniform_sampler(0, sampler, _velocity.rd_texture),
				ctx.uniform_image(1, vel_out.rd_texture),
			], vort_shader, 0)
			ctx.dispatch(vort_shader, us, wg.x, wg.y, wg.z, vort_pc)
			ctx.rd.free_rid(us)
			var old_vel: RID = _velocity.rd_texture
			_velocity.rd_texture = vel_out.rd_texture
			ctx.free_rid(old_vel)

	# --- Step 3: Compute divergence ---
	var div_shader: RID = ctx.get_shader("res://addons/gonodes/shaders/vol/fluid_divergence.glsl")
	if div_shader.is_valid():
		var us: RID = ctx.rd.uniform_set_create([
			ctx.uniform_sampler(0, sampler, _velocity.rd_texture),
			ctx.uniform_image(1, _divergence.rd_texture),
		], div_shader, 0)
		ctx.dispatch(div_shader, us, wg.x, wg.y, wg.z, res_pc)
		ctx.rd.free_rid(us)

	# --- Step 4: Jacobi pressure solve ---
	var pres_shader: RID = ctx.get_shader("res://addons/gonodes/shaders/vol/fluid_pressure.glsl")
	if pres_shader.is_valid():
		var iters: int = get_param_value("pressure_iters")
		for _i in range(iters):
			var us: RID = ctx.rd.uniform_set_create([
				ctx.uniform_sampler(0, sampler, _pressure_a.rd_texture),
				ctx.uniform_sampler(1, sampler, _divergence.rd_texture),
				ctx.uniform_image(2, _pressure_b.rd_texture),
			], pres_shader, 0)
			ctx.dispatch(pres_shader, us, wg.x, wg.y, wg.z, res_pc)
			ctx.rd.free_rid(us)
			# Swap
			var tmp: RID = _pressure_a.rd_texture
			_pressure_a.rd_texture = _pressure_b.rd_texture
			_pressure_b.rd_texture = tmp

	# --- Step 5: Project (subtract pressure gradient from velocity) ---
	var proj_shader: RID = ctx.get_shader("res://addons/gonodes/shaders/vol/fluid_project.glsl")
	if proj_shader.is_valid():
		var us: RID = ctx.rd.uniform_set_create([
			ctx.uniform_sampler(0, sampler, _pressure_a.rd_texture),
			ctx.uniform_image(1, _velocity.rd_texture),
		], proj_shader, 0)
		ctx.dispatch(proj_shader, us, wg.x, wg.y, wg.z, res_pc)
		ctx.rd.free_rid(us)

	# --- Step 6: Apply obstacle mask ---
	var obs_in := _get_input_vol(inputs, 2)
	if obs_in != null and obs_in.has_volume():
		var obs_shader: RID = ctx.get_shader("res://addons/gonodes/shaders/vol/fluid_obstacle.glsl")
		if obs_shader.is_valid():
			var obs_pc := PackedByteArray()
			obs_pc.resize(16)
			obs_pc.encode_s32(0, res.x)
			obs_pc.encode_s32(4, res.y)
			obs_pc.encode_s32(8, res.z)
			obs_pc.encode_float(12, 0.0)  # obstacle_velocity_scale
			var us: RID = ctx.rd.uniform_set_create([
				ctx.uniform_sampler(0, sampler, obs_in.rd_texture),
				ctx.uniform_image(1, _velocity.rd_texture),
				ctx.uniform_image(2, _density.rd_texture),
			], obs_shader, 0)
			ctx.dispatch(obs_shader, us, wg.x, wg.y, wg.z, obs_pc)
			ctx.rd.free_rid(us)

	ctx.rd.free_rid(sampler)

	# Output density (primary output)
	return _density


## Multi-output support: port 0 = density, port 1 = velocity
func get_output_data(port_index: int) -> GNData:
	if port_index == 1:
		return _velocity
	return _density


func _free_fields() -> void:
	if _velocity != null: _velocity.free_gpu()
	if _density != null: _density.free_gpu()
	if _pressure_a != null: _pressure_a.free_gpu()
	if _pressure_b != null: _pressure_b.free_gpu()
	if _divergence != null: _divergence.free_gpu()
	_velocity = null
	_density = null
	_pressure_a = null
	_pressure_b = null
	_divergence = null


# ═══════════════════════════════════════════════════════════════════════════════
# CPU Fallback — Navier-Stokes on PackedFloat32Array
# ═══════════════════════════════════════════════════════════════════════════════

var _cpu_velocity: PackedFloat32Array = PackedFloat32Array()  # RGBA (xyz + padding)
var _cpu_density: PackedFloat32Array = PackedFloat32Array()   # scalar
var _cpu_res: Vector3i = Vector3i.ZERO


func _cook_cpu(inputs: Array[GNData]) -> GNData:
	var res := Vector3i(get_param_value("res_x"), get_param_value("res_y"), get_param_value("res_z"))
	var dt: float = current_delta
	var dissipation: float = get_param_value("dissipation")
	var pressure_iters: int = get_param_value("pressure_iters")
	var density_add: float = get_param_value("density_add")
	var total: int = res.x * res.y * res.z

	# Allocate or reset
	if get_param_value("reset") or _cpu_res != res or _cpu_density.size() != total:
		_cpu_velocity.resize(total * 4)
		_cpu_velocity.fill(0.0)
		_cpu_density.resize(total)
		_cpu_density.fill(0.0)
		_cpu_res = res
		set_param_value("reset", false)

	# Step 1: Inject density source
	var den_in := _get_input_vol_cpu(inputs, 0)
	if den_in != null and den_in.has_volume():
		for i in range(mini(total, den_in.cpu_data.size())):
			_cpu_density[i] += den_in.cpu_data[i] * density_add * dt

	# Step 2: Advect density by velocity (semi-Lagrangian)
	var adv_den := PackedFloat32Array()
	adv_den.resize(total)
	for z in range(res.z):
		for y in range(res.y):
			for x in range(res.x):
				var idx4: int = (z * res.y * res.x + y * res.x + x) * 4
				var vx: float = _cpu_velocity[idx4]
				var vy: float = _cpu_velocity[idx4 + 1]
				var vz: float = _cpu_velocity[idx4 + 2]
				# Trace back
				var bx: float = (float(x) / float(res.x)) - vx * dt
				var by: float = (float(y) / float(res.y)) - vy * dt
				var bz: float = (float(z) / float(res.z)) - vz * dt
				adv_den[z * res.y * res.x + y * res.x + x] = \
					_vol_sample_trilinear(_cpu_density, Vector3(bx, by, bz), res) * dissipation
	_cpu_density = adv_den

	# Step 3: Compute divergence
	var divergence := PackedFloat32Array()
	divergence.resize(total)
	for z in range(res.z):
		for y in range(res.y):
			for x in range(res.x):
				var idx: int = z * res.y * res.x + y * res.x + x
				var dx: float = _vel_at(x + 1, y, z, res, 0) - _vel_at(x - 1, y, z, res, 0)
				var dy: float = _vel_at(x, y + 1, z, res, 1) - _vel_at(x, y - 1, z, res, 1)
				var dz: float = _vel_at(x, y, z + 1, res, 2) - _vel_at(x, y, z - 1, res, 2)
				divergence[idx] = (dx + dy + dz) * -0.5

	# Step 4: Jacobi pressure solve
	var pressure := PackedFloat32Array()
	pressure.resize(total)
	pressure.fill(0.0)
	var pressure_b := PackedFloat32Array()
	pressure_b.resize(total)
	for _iter in range(pressure_iters):
		pressure_b.fill(0.0)
		for z in range(res.z):
			for y in range(res.y):
				for x in range(res.x):
					var idx: int = z * res.y * res.x + y * res.x + x
					var sum: float = _pres_at(pressure, x - 1, y, z, res) \
						+ _pres_at(pressure, x + 1, y, z, res) \
						+ _pres_at(pressure, x, y - 1, z, res) \
						+ _pres_at(pressure, x, y + 1, z, res) \
						+ _pres_at(pressure, x, y, z - 1, res) \
						+ _pres_at(pressure, x, y, z + 1, res)
					pressure_b[idx] = (sum + divergence[idx]) / 6.0
		var tmp: PackedFloat32Array = pressure
		pressure = pressure_b
		pressure_b = tmp

	# Step 5: Project (subtract pressure gradient from velocity)
	for z in range(res.z):
		for y in range(res.y):
			for x in range(res.x):
				var idx4: int = (z * res.y * res.x + y * res.x + x) * 4
				_cpu_velocity[idx4] -= (_pres_at(pressure, x + 1, y, z, res) - _pres_at(pressure, x - 1, y, z, res)) * 0.5
				_cpu_velocity[idx4 + 1] -= (_pres_at(pressure, x, y + 1, z, res) - _pres_at(pressure, x, y - 1, z, res)) * 0.5
				_cpu_velocity[idx4 + 2] -= (_pres_at(pressure, x, y, z + 1, res) - _pres_at(pressure, x, y, z - 1, res)) * 0.5

	# Step 5b: Vorticity confinement (CPU)
	var vort_str: float = get_param_value("vorticity")
	if vort_str > 0.0:
		var curl_mag := PackedFloat32Array()
		curl_mag.resize(total)
		var curl_vec := PackedFloat32Array()
		curl_vec.resize(total * 3)
		# Compute curl at each voxel
		for z in range(res.z):
			for y in range(res.y):
				for x in range(res.x):
					var idx: int = z * res.y * res.x + y * res.x + x
					var dvz_dy: float = _vel_at(x, y + 1, z, res, 2) - _vel_at(x, y - 1, z, res, 2)
					var dvy_dz: float = _vel_at(x, y, z + 1, res, 1) - _vel_at(x, y, z - 1, res, 1)
					var dvx_dz: float = _vel_at(x, y, z + 1, res, 0) - _vel_at(x, y, z - 1, res, 0)
					var dvz_dx: float = _vel_at(x + 1, y, z, res, 2) - _vel_at(x - 1, y, z, res, 2)
					var dvy_dx: float = _vel_at(x + 1, y, z, res, 1) - _vel_at(x - 1, y, z, res, 1)
					var dvx_dy: float = _vel_at(x, y + 1, z, res, 0) - _vel_at(x, y - 1, z, res, 0)
					var cx: float = (dvz_dy - dvy_dz) * 0.5
					var cy: float = (dvx_dz - dvz_dx) * 0.5
					var cz: float = (dvy_dx - dvx_dy) * 0.5
					curl_vec[idx * 3] = cx
					curl_vec[idx * 3 + 1] = cy
					curl_vec[idx * 3 + 2] = cz
					curl_mag[idx] = sqrt(cx * cx + cy * cy + cz * cz)
		# Apply confinement force
		for z in range(1, res.z - 1):
			for y in range(1, res.y - 1):
				for x in range(1, res.x - 1):
					var idx: int = z * res.y * res.x + y * res.x + x
					var idx4: int = idx * 4
					var grad_x: float = curl_mag[idx + 1] - curl_mag[idx - 1]
					var grad_y: float = curl_mag[idx + res.x] - curl_mag[idx - res.x]
					var grad_z: float = curl_mag[idx + res.x * res.y] - curl_mag[idx - res.x * res.y]
					var glen: float = sqrt(grad_x * grad_x + grad_y * grad_y + grad_z * grad_z)
					if glen > 1e-5:
						grad_x /= glen
						grad_y /= glen
						grad_z /= glen
						# Cross product: eta × curl
						var fx: float = grad_y * curl_vec[idx * 3 + 2] - grad_z * curl_vec[idx * 3 + 1]
						var fy: float = grad_z * curl_vec[idx * 3] - grad_x * curl_vec[idx * 3 + 2]
						var fz: float = grad_x * curl_vec[idx * 3 + 1] - grad_y * curl_vec[idx * 3]
						_cpu_velocity[idx4] += fx * vort_str * dt
						_cpu_velocity[idx4 + 1] += fy * vort_str * dt
						_cpu_velocity[idx4 + 2] += fz * vort_str * dt

	# Step 6: Apply obstacle mask (CPU)
	var obs_in := _get_input_vol_cpu(inputs, 2)
	if obs_in != null and obs_in.has_volume():
		for i in range(mini(total, obs_in.cpu_data.size())):
			if obs_in.cpu_data[i] > 0.5:
				_cpu_velocity[i * 4] = 0.0
				_cpu_velocity[i * 4 + 1] = 0.0
				_cpu_velocity[i * 4 + 2] = 0.0
				_cpu_density[i] = 0.0

	# Output density
	var out := _create_volume_cpu(res, 1, "density")
	out.cpu_data = _cpu_density.duplicate()
	return out


## Reads velocity component at clamped coords.
func _vel_at(x: int, y: int, z: int, res: Vector3i, comp: int) -> float:
	x = clampi(x, 0, res.x - 1)
	y = clampi(y, 0, res.y - 1)
	z = clampi(z, 0, res.z - 1)
	return _cpu_velocity[(z * res.y * res.x + y * res.x + x) * 4 + comp]


## Reads pressure at clamped coords.
func _pres_at(p: PackedFloat32Array, x: int, y: int, z: int, res: Vector3i) -> float:
	x = clampi(x, 0, res.x - 1)
	y = clampi(y, 0, res.y - 1)
	z = clampi(z, 0, res.z - 1)
	return p[z * res.y * res.x + y * res.x + x]
