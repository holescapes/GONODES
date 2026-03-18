class_name PyroVOL
extends GNVolBase
## Pyro-style fire/smoke simulation on a 3D volume.
##
## Extends the Navier-Stokes pattern with combustion: fuel burns → temperature
## rises → buoyancy drives upward velocity → smoke density produced.
## Time-dependent: maintains velocity, density, temperature, and fuel fields.
##
## Inputs: fuel_in (VOL), vel_in (VOL, optional), obstacle (VOL, optional)
## Outputs: density (smoke), temperature (heat), velocity

var _velocity: GNVolumeData = null     # RGBA32F
var _density: GNVolumeData = null      # R32F (smoke)
var _temperature: GNVolumeData = null  # R32F
var _fuel: GNVolumeData = null         # R32F
var _pressure_a: GNVolumeData = null   # R32F ping-pong
var _pressure_b: GNVolumeData = null   # R32F ping-pong
var _divergence: GNVolumeData = null   # R32F
var _last_res: Vector3i = Vector3i.ZERO


func _init() -> void:
	super._init()
	node_type = "pyro"
	node_description = "Pyro fire/smoke simulation — combustion, buoyancy, and turbulence."
	time_dependent = true


func _init_ports() -> void:
	add_input("fuel_in", GNFamily.Type.VOL, false, "Fuel source volume (injected each frame)", "Fuel")
	add_input("vel_in", GNFamily.Type.VOL, false, "External velocity force (optional)", "Velocity")
	add_input("obstacle", GNFamily.Type.VOL, true, "Obstacle mask (R > 0.5 = solid)")
	add_output("density_out", GNFamily.Type.VOL, "Smoke density field", "Smoke")
	add_output("temp_out", GNFamily.Type.VOL, "Temperature field", "Temperature")
	add_output("velocity_out", GNFamily.Type.VOL, "Velocity field", "Velocity")


func _init_parameters() -> void:
	# Resolution
	add_parameter(GNParameter.create_int("res_x", 64, 8, 256, "Resolution X", "Grid width"))
	add_parameter(GNParameter.create_int("res_y", 64, 8, 256, "Resolution Y", "Grid height"))
	add_parameter(GNParameter.create_int("res_z", 64, 8, 256, "Resolution Z", "Grid depth"))

	# Combustion
	add_parameter(GNParameter.create_float("burn_rate", 1.5, 0.1, 10.0, 0.1,
		"Burn Rate", "Fuel consumed per second"))
	add_parameter(GNParameter.create_float("heat_output", 3.0, 0.1, 20.0, 0.1,
		"Heat Output", "Temperature generated per unit fuel burned"))
	add_parameter(GNParameter.create_float("smoke_output", 1.0, 0.0, 5.0, 0.1,
		"Smoke Output", "Smoke density per unit fuel burned"))
	add_parameter(GNParameter.create_float("ignition_temp", 0.2, 0.0, 5.0, 0.01,
		"Ignition Temp", "Minimum temperature to sustain combustion"))
	add_parameter(GNParameter.create_float("fuel_inject", 1.0, 0.0, 10.0, 0.1,
		"Fuel Inject", "Scale of fuel injection from input"))

	# Buoyancy & cooling
	add_parameter(GNParameter.create_float("buoyancy", 2.0, 0.0, 20.0, 0.1,
		"Buoyancy", "Upward force per unit temperature"))
	add_parameter(GNParameter.create_float("cooling", 0.96, 0.8, 1.0, 0.005,
		"Cooling", "Temperature decay per frame (0.96 = moderate)"))

	# Fluid dynamics
	add_parameter(GNParameter.create_float("dissipation", 0.985, 0.8, 1.0, 0.005,
		"Dissipation", "Smoke density decay per step"))
	add_parameter(GNParameter.create_int("pressure_iters", 20, 5, 50,
		"Pressure Iters", "Jacobi solver iterations"))
	add_parameter(GNParameter.create_float("vorticity", 0.5, 0.0, 5.0, 0.01,
		"Vorticity", "Turbulence / swirl strength"))

	add_parameter(GNParameter.create_bool("reset", false, "Reset", "Clear simulation"))


func _cook(inputs: Array[GNData]) -> GNData:
	var ctx := _get_ctx()
	if ctx.rd == null:
		return null

	var res := Vector3i(get_param_value("res_x"), get_param_value("res_y"), get_param_value("res_z"))
	var dt: float = current_delta

	# Allocate or reset fields
	if get_param_value("reset") or _velocity == null or _last_res != res:
		_free_fields()
		_velocity = _create_volume(res, RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT, "velocity")
		_density = _create_volume(res, RenderingDevice.DATA_FORMAT_R32_SFLOAT, "density")
		_temperature = _create_volume(res, RenderingDevice.DATA_FORMAT_R32_SFLOAT, "temperature")
		_fuel = _create_volume(res, RenderingDevice.DATA_FORMAT_R32_SFLOAT, "fuel")
		_pressure_a = _create_volume(res, RenderingDevice.DATA_FORMAT_R32_SFLOAT, "pressure")
		_pressure_b = _create_volume(res, RenderingDevice.DATA_FORMAT_R32_SFLOAT, "pressure")
		_divergence = _create_volume(res, RenderingDevice.DATA_FORMAT_R32_SFLOAT, "divergence")
		_last_res = res
		set_param_value("reset", false)

	var sampler: RID = ctx.create_linear_sampler()
	var wg := _workgroups_3d(res)

	# Shared push constants for fluid steps
	var res_pc := PackedByteArray()
	res_pc.resize(16)
	res_pc.encode_s32(0, res.x)
	res_pc.encode_s32(4, res.y)
	res_pc.encode_s32(8, res.z)
	res_pc.encode_float(12, 0.0)

	# --- Step 1: Inject fuel from input ---
	var fuel_in := _get_input_vol(inputs, 0)
	if fuel_in != null and fuel_in.has_volume():
		var blend_shader: RID = ctx.get_shader("res://addons/gonodes/shaders/vol/blend_vol.glsl")
		if blend_shader.is_valid():
			var blend_pc := PackedByteArray()
			blend_pc.resize(32)
			blend_pc.encode_s32(0, res.x)
			blend_pc.encode_s32(4, res.y)
			blend_pc.encode_s32(8, res.z)
			blend_pc.encode_s32(12, 0)  # add mode
			blend_pc.encode_float(16, 0.0)
			blend_pc.encode_float(20, 1.0)
			blend_pc.encode_float(24, get_param_value("fuel_inject") * dt)
			blend_pc.encode_float(28, 0.0)
			var temp := _acquire_volume(res, _fuel.data_format, "fuel")
			var us: RID = ctx.rd.uniform_set_create([
				ctx.uniform_image(0, _fuel.rd_texture),
				ctx.uniform_image(1, fuel_in.rd_texture),
				ctx.uniform_image(2, temp.rd_texture),
			], blend_shader, 0)
			ctx.dispatch(blend_shader, us, wg.x, wg.y, wg.z, blend_pc)
			ctx.rd.free_rid(us)
			var old: RID = _fuel.rd_texture
			_fuel.rd_texture = temp.rd_texture
			ctx.free_rid(old)

	# --- Step 2: Combustion (fuel → heat + smoke) ---
	var combust_shader: RID = ctx.get_shader("res://addons/gonodes/shaders/vol/pyro_combustion.glsl")
	if combust_shader.is_valid():
		var cpc := PackedByteArray()
		cpc.resize(32)
		cpc.encode_s32(0, res.x)
		cpc.encode_s32(4, res.y)
		cpc.encode_s32(8, res.z)
		cpc.encode_float(12, dt)
		cpc.encode_float(16, get_param_value("burn_rate"))
		cpc.encode_float(20, get_param_value("heat_output"))
		cpc.encode_float(24, get_param_value("smoke_output"))
		cpc.encode_float(28, get_param_value("ignition_temp"))
		var us: RID = ctx.rd.uniform_set_create([
			ctx.uniform_image(0, _fuel.rd_texture),
			ctx.uniform_image(1, _temperature.rd_texture),
			ctx.uniform_image(2, _density.rd_texture),
		], combust_shader, 0)
		ctx.dispatch(combust_shader, us, wg.x, wg.y, wg.z, cpc)
		ctx.rd.free_rid(us)

	# --- Step 3: Buoyancy (temperature → upward velocity) ---
	var buoy_shader: RID = ctx.get_shader("res://addons/gonodes/shaders/vol/pyro_buoyancy.glsl")
	if buoy_shader.is_valid():
		var bpc := PackedByteArray()
		bpc.resize(32)
		bpc.encode_s32(0, res.x)
		bpc.encode_s32(4, res.y)
		bpc.encode_s32(8, res.z)
		bpc.encode_float(12, dt)
		bpc.encode_float(16, get_param_value("buoyancy"))
		bpc.encode_float(20, get_param_value("cooling"))
		bpc.encode_float(24, 0.0)
		bpc.encode_float(28, 0.0)
		var us: RID = ctx.rd.uniform_set_create([
			ctx.uniform_sampler(0, sampler, _temperature.rd_texture),
			ctx.uniform_image(1, _velocity.rd_texture),
		], buoy_shader, 0)
		ctx.dispatch(buoy_shader, us, wg.x, wg.y, wg.z, bpc)
		ctx.rd.free_rid(us)

	# --- Step 4: Cooling (temperature decay) ---
	var cool_shader: RID = ctx.get_shader("res://addons/gonodes/shaders/vol/pyro_cooling.glsl")
	if cool_shader.is_valid():
		var cool_pc := PackedByteArray()
		cool_pc.resize(16)
		cool_pc.encode_s32(0, res.x)
		cool_pc.encode_s32(4, res.y)
		cool_pc.encode_s32(8, res.z)
		cool_pc.encode_float(12, get_param_value("cooling"))
		var us: RID = ctx.rd.uniform_set_create([
			ctx.uniform_image(0, _temperature.rd_texture),
		], cool_shader, 0)
		ctx.dispatch(cool_shader, us, wg.x, wg.y, wg.z, cool_pc)
		ctx.rd.free_rid(us)

	# --- Step 5: Vorticity confinement ---
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

	# --- Step 6: Advect density (smoke) ---
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
		var old_d: RID = _density.rd_texture
		_density.rd_texture = adv_out.rd_texture
		ctx.free_rid(old_d)

	# --- Step 7: Advect temperature ---
	if advect_shader.is_valid():
		var adv_t := _acquire_volume(res, _temperature.data_format, "temperature")
		var adv_pc := PackedByteArray()
		adv_pc.resize(32)
		adv_pc.encode_s32(0, res.x)
		adv_pc.encode_s32(4, res.y)
		adv_pc.encode_s32(8, res.z)
		adv_pc.encode_float(12, dt)
		adv_pc.encode_float(16, 0.99)  # temperature dissipation (separate from smoke)
		adv_pc.encode_float(20, 0.0)
		adv_pc.encode_float(24, 0.0)
		adv_pc.encode_float(28, 0.0)
		var us: RID = ctx.rd.uniform_set_create([
			ctx.uniform_sampler(0, sampler, _velocity.rd_texture),
			ctx.uniform_sampler(1, sampler, _temperature.rd_texture),
			ctx.uniform_image(2, adv_t.rd_texture),
		], advect_shader, 0)
		ctx.dispatch(advect_shader, us, wg.x, wg.y, wg.z, adv_pc)
		ctx.rd.free_rid(us)
		var old_t: RID = _temperature.rd_texture
		_temperature.rd_texture = adv_t.rd_texture
		ctx.free_rid(old_t)

	# --- Step 8: Divergence ---
	var div_shader: RID = ctx.get_shader("res://addons/gonodes/shaders/vol/fluid_divergence.glsl")
	if div_shader.is_valid():
		var us: RID = ctx.rd.uniform_set_create([
			ctx.uniform_sampler(0, sampler, _velocity.rd_texture),
			ctx.uniform_image(1, _divergence.rd_texture),
		], div_shader, 0)
		ctx.dispatch(div_shader, us, wg.x, wg.y, wg.z, res_pc)
		ctx.rd.free_rid(us)

	# --- Step 9: Pressure solve ---
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
			var tmp: RID = _pressure_a.rd_texture
			_pressure_a.rd_texture = _pressure_b.rd_texture
			_pressure_b.rd_texture = tmp

	# --- Step 10: Velocity projection ---
	var proj_shader: RID = ctx.get_shader("res://addons/gonodes/shaders/vol/fluid_project.glsl")
	if proj_shader.is_valid():
		var us: RID = ctx.rd.uniform_set_create([
			ctx.uniform_sampler(0, sampler, _pressure_a.rd_texture),
			ctx.uniform_image(1, _velocity.rd_texture),
		], proj_shader, 0)
		ctx.dispatch(proj_shader, us, wg.x, wg.y, wg.z, res_pc)
		ctx.rd.free_rid(us)

	# --- Step 11: Obstacle masking ---
	var obs_in := _get_input_vol(inputs, 2)
	if obs_in != null and obs_in.has_volume():
		var obs_shader: RID = ctx.get_shader("res://addons/gonodes/shaders/vol/fluid_obstacle.glsl")
		if obs_shader.is_valid():
			var obs_pc := PackedByteArray()
			obs_pc.resize(16)
			obs_pc.encode_s32(0, res.x)
			obs_pc.encode_s32(4, res.y)
			obs_pc.encode_s32(8, res.z)
			obs_pc.encode_float(12, 0.0)
			var us: RID = ctx.rd.uniform_set_create([
				ctx.uniform_sampler(0, sampler, obs_in.rd_texture),
				ctx.uniform_image(1, _velocity.rd_texture),
				ctx.uniform_image(2, _density.rd_texture),
			], obs_shader, 0)
			ctx.dispatch(obs_shader, us, wg.x, wg.y, wg.z, obs_pc)
			ctx.rd.free_rid(us)

	ctx.rd.free_rid(sampler)
	return _density


## Multi-output: port 0 = density (smoke), port 1 = temperature, port 2 = velocity
func get_output_data(port_index: int) -> GNData:
	match port_index:
		1: return _temperature
		2: return _velocity
		_: return _density


func _free_fields() -> void:
	for vol in [_velocity, _density, _temperature, _fuel, _pressure_a, _pressure_b, _divergence]:
		if vol != null:
			vol.free_gpu()
	_velocity = null
	_density = null
	_temperature = null
	_fuel = null
	_pressure_a = null
	_pressure_b = null
	_divergence = null


# ═══════════════════════════════════════════════════════════════════════════════
# CPU Fallback
# ═══════════════════════════════════════════════════════════════════════════════

var _cpu_velocity: PackedFloat32Array = PackedFloat32Array()
var _cpu_density: PackedFloat32Array = PackedFloat32Array()
var _cpu_temperature: PackedFloat32Array = PackedFloat32Array()
var _cpu_fuel: PackedFloat32Array = PackedFloat32Array()
var _cpu_res: Vector3i = Vector3i.ZERO


func _cook_cpu(inputs: Array[GNData]) -> GNData:
	var res := Vector3i(get_param_value("res_x"), get_param_value("res_y"), get_param_value("res_z"))
	var dt: float = current_delta
	var total: int = res.x * res.y * res.z

	if get_param_value("reset") or _cpu_res != res or _cpu_density.size() != total:
		_cpu_velocity.resize(total * 4)
		_cpu_velocity.fill(0.0)
		_cpu_density.resize(total)
		_cpu_density.fill(0.0)
		_cpu_temperature.resize(total)
		_cpu_temperature.fill(0.0)
		_cpu_fuel.resize(total)
		_cpu_fuel.fill(0.0)
		_cpu_res = res
		set_param_value("reset", false)

	var burn_rate: float = get_param_value("burn_rate")
	var heat_out: float = get_param_value("heat_output")
	var smoke_out: float = get_param_value("smoke_output")
	var ignition: float = get_param_value("ignition_temp")
	var fuel_inj: float = get_param_value("fuel_inject")
	var buoyancy_val: float = get_param_value("buoyancy")
	var cooling_val: float = get_param_value("cooling")
	var dissipation_val: float = get_param_value("dissipation")

	# Inject fuel
	var fuel_in := _get_input_vol_cpu(inputs, 0)
	if fuel_in != null and fuel_in.has_volume():
		for i in range(mini(total, fuel_in.cpu_data.size())):
			_cpu_fuel[i] += fuel_in.cpu_data[i] * fuel_inj * dt

	# Combustion
	for i in range(total):
		if _cpu_fuel[i] > 0.001 and _cpu_temperature[i] > ignition:
			var burn: float = minf(_cpu_fuel[i], burn_rate * dt)
			_cpu_fuel[i] -= burn
			_cpu_temperature[i] += burn * heat_out
			_cpu_density[i] += burn * smoke_out

	# Buoyancy (simplified: add upward velocity based on temperature)
	for z in range(res.z):
		for y in range(res.y):
			for x in range(res.x):
				var idx: int = z * res.y * res.x + y * res.x + x
				var idx4: int = idx * 4
				_cpu_velocity[idx4 + 1] += _cpu_temperature[idx] * buoyancy_val * dt

	# Cooling
	for i in range(total):
		_cpu_temperature[i] *= cooling_val

	# Advect density (simplified semi-Lagrangian)
	var adv_den := PackedFloat32Array()
	adv_den.resize(total)
	for z in range(res.z):
		for y in range(res.y):
			for x in range(res.x):
				var idx: int = z * res.y * res.x + y * res.x + x
				var idx4: int = idx * 4
				var bx: float = float(x) / float(res.x) - _cpu_velocity[idx4] * dt
				var by: float = float(y) / float(res.y) - _cpu_velocity[idx4 + 1] * dt
				var bz: float = float(z) / float(res.z) - _cpu_velocity[idx4 + 2] * dt
				adv_den[idx] = _vol_sample_trilinear(_cpu_density, Vector3(bx, by, bz), res) * dissipation_val
	_cpu_density = adv_den

	# Return density as CPU volume
	var out := GNVolumeData.new()
	out.resolution = res
	out.is_cpu = true
	out.cpu_data = _cpu_density.duplicate()
	out.data_format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	out.channel_count = 1
	out.field_name = "density"
	out.valid = true
	out.timestamp = current_frame
	return out
