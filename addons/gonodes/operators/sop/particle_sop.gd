class_name ParticleSOP
extends GNSopBase
## CPU particle system that emits points from an input SOP surface.
##
## Emits particles over time, each with position, velocity, age, and life.
## Particles are born on the input mesh surface (area-weighted random),
## inherit surface normal as initial velocity direction, and move under
## configurable gravity and drag.  Output is a point cloud (PRIMITIVE_POINTS)
## with point attributes: age, life, id.
##
## This is a CPU implementation suitable for later porting to C++.
## For GPU particles, chain the output through InstanceCOMP.
##
## Inputs:
##   0 — SOP emitter surface (triangles)
##   1 — SOP attractor (optional — particles pulled toward surface centroid)

## Particle storage
var _positions := PackedVector3Array()
var _velocities := PackedVector3Array()
var _ages := PackedFloat32Array()
var _lives := PackedFloat32Array()
var _ids := PackedInt32Array()
var _next_id: int = 0
var _emit_accum: float = 0.0

## Emitter triangle data (cached when emitter changes)
var _tri_verts: Array[PackedVector3Array] = []
var _tri_normals: Array[PackedVector3Array] = []
var _tri_cdf := PackedFloat32Array()
var _tri_total_area: float = 0.0
var _last_emitter_hash: int = 0

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	node_type = "particle"
	time_dependent = true


func _init_ports() -> void:
	add_input("emitter", GNFamily.Type.SOP, false, "Emitter surface geometry")
	add_input("attractor", GNFamily.Type.SOP, false, "Attractor surface (optional)")
	add_output("out", GNFamily.Type.SOP, "Particle point cloud")


func _init_parameters() -> void:
	# Emission
	add_parameter(GNParameter.create_float("rate", 100.0, 0.0, 100000.0, 1.0,
		"Emit Rate", "Particles emitted per second"))
	add_parameter(GNParameter.create_int("max_particles", 10000, 1, 500000,
		"Max Particles", "Maximum alive particles (ring buffer)"))
	add_parameter(GNParameter.create_int("seed", 42, 0, 99999, "Seed", "Random seed"))

	# Life
	add_parameter(GNParameter.create_float("life", 2.0, 0.01, 60.0, 0.1,
		"Life", "Particle lifespan (seconds)"))
	add_parameter(GNParameter.create_float("life_rand", 0.0, 0.0, 1.0, 0.01,
		"Life Randomize", "Random life variation (0-1)"))

	# Initial velocity
	add_parameter(GNParameter.create_float("emit_speed", 1.0, 0.0, 100.0, 0.1,
		"Emit Speed", "Initial velocity along surface normal"))
	add_parameter(GNParameter.create_float("speed_rand", 0.0, 0.0, 1.0, 0.01,
		"Speed Randomize", "Random speed variation"))
	add_parameter(GNParameter.create_float("spread", 0.0, 0.0, 180.0, 1.0,
		"Spread", "Cone angle deviation from normal (degrees)"))

	# Physics
	add_parameter(GNParameter.create_float("gravity", -9.8, -100.0, 100.0, 0.1,
		"Gravity Y", "Gravity acceleration on Y axis"))
	add_parameter(GNParameter.create_float("drag", 0.0, 0.0, 10.0, 0.01,
		"Drag", "Velocity damping per second"))
	add_parameter(GNParameter.create_float("turbulence", 0.0, 0.0, 50.0, 0.1,
		"Turbulence", "Random force added each frame"))
	add_parameter(GNParameter.create_float("attract_force", 0.0, -50.0, 50.0, 0.1,
		"Attract Force", "Pull toward attractor input (0 = none)"))

	# Floor collision
	add_parameter(GNParameter.create_bool("floor_enabled", false,
		"Floor Collision", "Kill or bounce particles at Y=floor_y"))
	add_parameter(GNParameter.create_float("floor_y", 0.0, -100.0, 100.0, 0.1,
		"Floor Y", "Floor plane Y position"))
	add_parameter(GNParameter.create_float("bounce", 0.3, 0.0, 1.0, 0.01,
		"Bounce", "Velocity preserved on bounce (0 = absorb, 1 = elastic)"))

	# State
	add_parameter(GNParameter.create_bool("reset", false,
		"Reset", "Toggle to clear all particles"))


func _cook(inputs: Array[GNData]) -> GNData:
	var emitter: GNGeoData = _get_input_sop(inputs, 0)
	var attractor: GNGeoData = _get_input_sop(inputs, 1)

	# Reset
	if get_param_value("reset"):
		_clear_particles()
		return null

	if emitter == null or not emitter.has_geometry():
		return null

	# Rebuild emitter cache if source changed
	var emitter_hash: int = emitter.vertex_count * 31 + emitter.mesh.get_surface_count()
	if emitter_hash != _last_emitter_hash:
		_rebuild_emitter_cache(emitter)
		_last_emitter_hash = emitter_hash

	if _tri_verts.is_empty():
		return null

	# Get cook context timing
	var dt: float = current_delta
	if dt <= 0.0:
		dt = 1.0 / 60.0

	var rate: float = get_param_value("rate")
	var max_p: int = get_param_value("max_particles")
	var life_base: float = get_param_value("life")
	var life_rand: float = get_param_value("life_rand")
	var emit_speed: float = get_param_value("emit_speed")
	var speed_rand: float = get_param_value("speed_rand")
	var spread: float = deg_to_rad(get_param_value("spread"))
	var gravity: float = get_param_value("gravity")
	var drag: float = get_param_value("drag")
	var turbulence: float = get_param_value("turbulence")
	var attract_f: float = get_param_value("attract_force")
	var floor_on: bool = get_param_value("floor_enabled")
	var floor_y: float = get_param_value("floor_y")
	var bounce: float = get_param_value("bounce")

	# Attractor centroid
	var attractor_pos := Vector3.ZERO
	if attractor != null and attractor.has_geometry():
		attractor_pos = attractor.bounds.get_center()

	# ── Step 1: Emit new particles ──
	_emit_accum += rate * dt
	var to_emit: int = int(_emit_accum)
	_emit_accum -= float(to_emit)

	for _e in range(to_emit):
		if _positions.size() >= max_p:
			# Kill oldest
			_remove_particle(0)
		_spawn_particle(life_base, life_rand, emit_speed, speed_rand, spread)

	# ── Step 2: Simulate ──
	var grav_vec := Vector3(0.0, gravity, 0.0)
	var drag_factor: float = maxf(1.0 - drag * dt, 0.0)
	var kill_list := PackedInt32Array()

	for i in range(_positions.size()):
		_ages[i] += dt
		if _ages[i] >= _lives[i]:
			kill_list.append(i)
			continue

		# Forces
		var accel := grav_vec

		if attract_f != 0.0 and attractor != null:
			var to_target: Vector3 = attractor_pos - _positions[i]
			var dist: float = to_target.length()
			if dist > 0.01:
				accel += to_target.normalized() * attract_f

		if turbulence > 0.0:
			accel += Vector3(
				_rng.randf_range(-1.0, 1.0),
				_rng.randf_range(-1.0, 1.0),
				_rng.randf_range(-1.0, 1.0)) * turbulence

		_velocities[i] += accel * dt
		_velocities[i] *= drag_factor
		_positions[i] += _velocities[i] * dt

		# Floor collision
		if floor_on and _positions[i].y < floor_y:
			_positions[i].y = floor_y
			if bounce > 0.0:
				_velocities[i].y = absf(_velocities[i].y) * bounce
			else:
				_velocities[i] = Vector3.ZERO

	# Kill dead particles (reverse to keep indices valid)
	for ki in range(kill_list.size() - 1, -1, -1):
		_remove_particle(kill_list[ki])

	# ── Step 3: Build output point cloud ──
	if _positions.is_empty():
		return null

	var out := _prepare_geo()
	var out_arrays: Array = []
	out_arrays.resize(Mesh.ARRAY_MAX)
	out_arrays[Mesh.ARRAY_VERTEX] = _positions.duplicate()

	var new_mesh := ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, out_arrays)
	out.set_mesh(new_mesh)

	# Store age/life as point attributes for downstream use
	out.set_point_attrib("age", _ages.duplicate())
	out.set_point_attrib("life", _lives.duplicate())

	# Normalized age (0..1) useful for color mapping
	var norm_age := PackedFloat32Array()
	norm_age.resize(_ages.size())
	for i in range(_ages.size()):
		norm_age[i] = _ages[i] / maxf(_lives[i], 0.001)
	out.set_point_attrib("age_norm", norm_age)

	return out


func _spawn_particle(life_base: float, life_rand: float,
		speed: float, speed_rand: float, spread: float) -> void:
	# Pick random triangle from emitter CDF
	var r: float = _rng.randf() * _tri_total_area
	var tidx: int = 0
	var lo: int = 0
	var hi: int = _tri_cdf.size() - 1
	while lo < hi:
		var mid: int = (lo + hi) / 2
		if _tri_cdf[mid] < r:
			lo = mid + 1
		else:
			hi = mid
	tidx = lo

	# Random barycentric coordinates
	var u: float = _rng.randf()
	var v: float = _rng.randf()
	if u + v > 1.0:
		u = 1.0 - u
		v = 1.0 - v
	var w: float = 1.0 - u - v

	var tv: PackedVector3Array = _tri_verts[tidx]
	var pos: Vector3 = tv[0] * w + tv[1] * u + tv[2] * v

	# Normal direction
	var normal := Vector3.UP
	if _tri_normals[tidx].size() == 3:
		var tn: PackedVector3Array = _tri_normals[tidx]
		normal = (tn[0] * w + tn[1] * u + tn[2] * v).normalized()

	# Apply spread
	if spread > 0.0:
		var rand_dir := Vector3(
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-1.0, 1.0)).normalized()
		normal = normal.slerp(rand_dir, _rng.randf() * spread / PI).normalized()

	# Velocity
	var spd: float = speed
	if speed_rand > 0.0:
		spd *= (1.0 + _rng.randf_range(-speed_rand, speed_rand))
	var vel: Vector3 = normal * spd

	# Life
	var life: float = life_base
	if life_rand > 0.0:
		life *= (1.0 + _rng.randf_range(-life_rand, life_rand))
	life = maxf(life, 0.01)

	_positions.append(pos)
	_velocities.append(vel)
	_ages.append(0.0)
	_lives.append(life)
	_ids.append(_next_id)
	_next_id += 1


func _remove_particle(idx: int) -> void:
	_positions.remove_at(idx)
	_velocities.remove_at(idx)
	_ages.remove_at(idx)
	_lives.remove_at(idx)
	_ids.remove_at(idx)


func _clear_particles() -> void:
	_positions.clear()
	_velocities.clear()
	_ages.clear()
	_lives.clear()
	_ids.clear()
	_emit_accum = 0.0
	_next_id = 0


func _rebuild_emitter_cache(geo: GNGeoData) -> void:
	_tri_verts.clear()
	_tri_normals.clear()
	_tri_cdf = PackedFloat32Array()
	_tri_total_area = 0.0
	var areas := PackedFloat32Array()

	for s in range(geo.mesh.get_surface_count()):
		if geo.mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays: Array = geo.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()

		if indices.is_empty():
			indices.resize(verts.size())
			for i in range(verts.size()):
				indices[i] = i

		for tri in range(indices.size() / 3):
			var i0: int = indices[tri * 3]
			var i1: int = indices[tri * 3 + 1]
			var i2: int = indices[tri * 3 + 2]
			var v0: Vector3 = verts[i0]
			var v1: Vector3 = verts[i1]
			var v2: Vector3 = verts[i2]

			_tri_verts.append(PackedVector3Array([v0, v1, v2]))

			var tn := PackedVector3Array()
			if i0 < norms.size() and i1 < norms.size() and i2 < norms.size():
				tn = PackedVector3Array([norms[i0], norms[i1], norms[i2]])
			_tri_normals.append(tn)

			areas.append((v1 - v0).cross(v2 - v0).length() * 0.5)

	if areas.is_empty():
		return

	_tri_cdf.resize(areas.size())
	_tri_cdf[0] = areas[0]
	for i in range(1, areas.size()):
		_tri_cdf[i] = _tri_cdf[i - 1] + areas[i]
	_tri_total_area = _tri_cdf[_tri_cdf.size() - 1]


## Override: particles always need to recook (time-varying).
func is_time_dependent() -> bool:
	return true
