class_name SourcePOP
extends GNPopBase
## Emits particles from SOP geometry points or from origin.
## Generator: allocates the SSBO and emits new particles each frame.

var _particle_data: GNParticleData = null
var _emit_buf: RID = RID()  # SSBO with emit points
var _cpu_particle_data: GNParticleData = null  # CPU fallback storage


func _init() -> void:
	super._init()
	node_type = "source"
	node_description = "Emit particles from SOP geometry or a point."
	time_dependent = true


func _init_ports() -> void:
	add_input("geo_in", GNFamily.Type.SOP, false, "Emitter geometry (optional)")
	add_output("out", GNFamily.Type.POP, "Particle data output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("max_particles", 100000,
		1000, 1000000, "Max Particles", "Maximum particle pool size"))
	add_parameter(GNParameter.create_float("rate", 1000.0,
		0.0, 100000.0, 0.01, "Emit Rate", "Particles emitted per second"))
	add_parameter(GNParameter.create_float("life_min", 1.0,
		0.01, 60.0, 0.01, "Life Min", "Minimum particle lifespan (seconds)"))
	add_parameter(GNParameter.create_float("life_max", 3.0,
		0.01, 60.0, 0.01, "Life Max", "Maximum particle lifespan (seconds)"))
	add_parameter(GNParameter.create_float("init_speed", 1.0,
		0.0, 100.0, 0.01, "Initial Speed", "Speed at emission"))
	add_parameter(GNParameter.create_float("pscale", 0.05,
		0.001, 10.0, 0.01, "Point Scale", "Initial pscale attribute value"))
	add_parameter(GNParameter.create_bool("reset", false, "Reset",
		"Pulse to clear all particles"))


func _cook(inputs: Array[GNData]) -> GNData:
	var ctx := _get_ctx()
	if ctx.rd == null:
		return null

	var max_p: int = get_param_value("max_particles")
	var rate: float = get_param_value("rate")
	var dt: float = current_delta

	# Reset pulse
	if get_param_value("reset") or _particle_data == null or _particle_data.max_particles != max_p:
		if _particle_data != null:
			_particle_data.free_gpu()
		_particle_data = _allocate_particles(max_p)
		set_param_value("reset", false)

	# Build emit points from SOP input or origin
	var emit_points := PackedVector3Array()
	var geo: GNGeoData = null
	if inputs.size() > 0 and inputs[0] is GNGeoData:
		geo = inputs[0] as GNGeoData
	if geo != null and geo.has_geometry() and geo.mesh != null:
		var arrays: Array = geo.mesh.surface_get_arrays(0)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			emit_points = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	if emit_points.is_empty():
		emit_points.append(Vector3.ZERO)

	# Upload emit points to GPU
	var emit_bytes := PackedByteArray()
	emit_bytes.resize(emit_points.size() * 16)  # vec4 per point
	for i in range(emit_points.size()):
		emit_bytes.encode_float(i * 16, emit_points[i].x)
		emit_bytes.encode_float(i * 16 + 4, emit_points[i].y)
		emit_bytes.encode_float(i * 16 + 8, emit_points[i].z)
		emit_bytes.encode_float(i * 16 + 12, 0.0)

	if _emit_buf.is_valid():
		ctx.free_rid(_emit_buf)
	_emit_buf = ctx.rd.storage_buffer_create(emit_bytes.size(), emit_bytes)

	# Calculate emit count this frame
	var emit_count: int = mini(int(rate * dt), max_p - _particle_data.particle_count)
	if emit_count <= 0:
		return _particle_data

	# Compile & dispatch source shader
	var shader: RID = ctx.get_shader("res://addons/gonodes/shaders/pop/source_pop.glsl")
	if not shader.is_valid():
		return _particle_data

	# Push constants
	var pc := PackedByteArray()
	pc.resize(32)
	pc.encode_s32(0, _particle_data.particle_count)
	pc.encode_s32(4, emit_count)
	pc.encode_s32(8, emit_points.size())
	pc.encode_float(12, get_param_value("life_min"))
	pc.encode_float(16, get_param_value("life_max"))
	pc.encode_float(20, get_param_value("init_speed"))
	pc.encode_float(24, get_param_value("pscale"))
	pc.encode_float(28, elapsed_time)

	var uniform_set: RID = ctx.rd.uniform_set_create([
		ctx.uniform_buffer(0, _particle_data.rd_buffer),
		ctx.uniform_buffer(1, _emit_buf),
	], shader, 0)

	ctx.dispatch(shader, uniform_set, _workgroups(emit_count), 1, 1, pc)
	ctx.rd.free_rid(uniform_set)

	_particle_data.particle_count = mini(_particle_data.particle_count + emit_count, max_p)
	return _particle_data


func _cook_cpu(inputs: Array[GNData]) -> GNData:
	var max_p: int = get_param_value("max_particles")
	var rate: float = get_param_value("rate")
	var dt: float = current_delta

	# Reset pulse
	if get_param_value("reset") or _cpu_particle_data == null or _cpu_particle_data.max_particles != max_p:
		_cpu_particle_data = _allocate_particles_cpu(max_p)
		set_param_value("reset", false)

	# Build emit points from SOP input or origin
	var emit_points := PackedVector3Array()
	var geo: GNGeoData = null
	if inputs.size() > 0 and inputs[0] is GNGeoData:
		geo = inputs[0] as GNGeoData
	if geo != null and geo.has_geometry() and geo.mesh != null:
		var arrays: Array = geo.mesh.surface_get_arrays(0)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			emit_points = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	if emit_points.is_empty():
		emit_points.append(Vector3.ZERO)

	# Age existing particles and kill expired ones
	var pd := _cpu_particle_data
	var write_idx: int = 0
	for i in range(pd.particle_count):
		pd.cpu_ages[i] += dt
		if pd.cpu_ages[i] < pd.cpu_lives[i]:
			if write_idx != i:
				pd.cpu_positions[write_idx] = pd.cpu_positions[i]
				pd.cpu_velocities[write_idx] = pd.cpu_velocities[i]
				pd.cpu_colors[write_idx] = pd.cpu_colors[i]
				pd.cpu_ages[write_idx] = pd.cpu_ages[i]
				pd.cpu_lives[write_idx] = pd.cpu_lives[i]
				pd.cpu_masses[write_idx] = pd.cpu_masses[i]
				pd.cpu_pscales[write_idx] = pd.cpu_pscales[i]
			write_idx += 1
	pd.particle_count = write_idx

	# Emit new particles
	var emit_count: int = mini(int(rate * dt), max_p - pd.particle_count)
	var life_min: float = get_param_value("life_min")
	var life_max: float = get_param_value("life_max")
	var init_speed: float = get_param_value("init_speed")
	var pscale: float = get_param_value("pscale")

	for i in range(emit_count):
		var idx: int = pd.particle_count + i
		if idx >= max_p:
			break
		var emit_pt: Vector3 = emit_points[i % emit_points.size()]
		pd.cpu_positions[idx] = emit_pt
		# Random direction for initial velocity
		var dir := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		pd.cpu_velocities[idx] = dir * init_speed
		pd.cpu_colors[idx] = Color.WHITE
		pd.cpu_ages[idx] = 0.0
		pd.cpu_lives[idx] = randf_range(life_min, life_max)
		pd.cpu_masses[idx] = 1.0
		pd.cpu_pscales[idx] = pscale

	pd.particle_count = mini(pd.particle_count + emit_count, max_p)
	return pd
