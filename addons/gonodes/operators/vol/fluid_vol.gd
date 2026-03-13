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
	node_description = "Navier-Stokes fluid simulation (advection, pressure solve, projection)."
	time_dependent = true


func _init_ports() -> void:
	add_input("density_in", GNFamily.Type.VOL, false, "Density source (added each frame)")
	add_input("vel_in", GNFamily.Type.VOL, false, "External velocity force (optional)")
	add_output("density_out", GNFamily.Type.VOL, "Simulated density field")
	add_output("velocity_out", GNFamily.Type.VOL, "Simulated velocity field")


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
