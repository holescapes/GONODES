class_name ParticleSOPNative
extends GNSopBase
## Native-accelerated CPU particle system — delegates simulation to
## GNNativeParticle (C++) when available, falls back to GDScript otherwise.

var _processor: RefCounted = null  # GNNativeParticle when available

# GDScript fallback state
var _positions := PackedVector3Array()
var _velocities := PackedVector3Array()
var _ages := PackedFloat32Array()
var _lives := PackedFloat32Array()
var _next_id: int = 0
var _emit_accum: float = 0.0
var _last_emitter_hash: int = 0
var _rng := RandomNumberGenerator.new()

# Emitter cache (shared by native + fallback)
var _cached_verts := PackedVector3Array()
var _cached_normals := PackedVector3Array()
var _cached_indices := PackedInt32Array()


func _init() -> void:
	node_type = "particle_native"
	node_description = "CPU particle emitter from SOP surface (native C++ accelerated)."
	time_dependent = true
	if ClassDB.class_exists("GNNativeParticle"):
		_processor = ClassDB.instantiate("GNNativeParticle")


func _init_ports() -> void:
	add_input("emitter", GNFamily.Type.SOP, false, "Emitter surface geometry")
	add_input("attractor", GNFamily.Type.SOP, false, "Attractor surface (optional)")
	add_output("out", GNFamily.Type.SOP, "Particle point cloud")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("rate", 100.0, 0.0, 100000.0, 1.0,
		"Emit Rate", "Particles emitted per second"))
	add_parameter(GNParameter.create_int("max_particles", 10000, 1, 500000,
		"Max Particles", "Maximum alive particles"))
	add_parameter(GNParameter.create_int("seed", 42, 0, 99999, "Seed", "Random seed"))
	add_parameter(GNParameter.create_float("life", 2.0, 0.01, 60.0, 0.1,
		"Life", "Particle lifespan (seconds)"))
	add_parameter(GNParameter.create_float("life_rand", 0.0, 0.0, 1.0, 0.01,
		"Life Randomize", "Random life variation (0-1)"))
	add_parameter(GNParameter.create_float("emit_speed", 1.0, 0.0, 100.0, 0.1,
		"Emit Speed", "Initial velocity along surface normal"))
	add_parameter(GNParameter.create_float("speed_rand", 0.0, 0.0, 1.0, 0.01,
		"Speed Randomize", "Random speed variation"))
	add_parameter(GNParameter.create_float("spread", 0.0, 0.0, 180.0, 1.0,
		"Spread", "Cone angle deviation from normal (degrees)"))
	add_parameter(GNParameter.create_float("gravity", -9.8, -100.0, 100.0, 0.1,
		"Gravity Y", "Gravity acceleration on Y axis"))
	add_parameter(GNParameter.create_float("drag", 0.0, 0.0, 10.0, 0.01,
		"Drag", "Velocity damping per second"))
	add_parameter(GNParameter.create_float("turbulence", 0.0, 0.0, 50.0, 0.1,
		"Turbulence", "Random force added each frame"))
	add_parameter(GNParameter.create_float("attract_force", 0.0, -50.0, 50.0, 0.1,
		"Attract Force", "Pull toward attractor input"))
	add_parameter(GNParameter.create_bool("floor_enabled", false,
		"Floor Collision", "Bounce or absorb particles at floor_y"))
	add_parameter(GNParameter.create_float("floor_y", 0.0, -100.0, 100.0, 0.1,
		"Floor Y", "Floor plane Y position"))
	add_parameter(GNParameter.create_float("bounce", 0.3, 0.0, 1.0, 0.01,
		"Bounce", "Velocity preserved on bounce"))
	add_parameter(GNParameter.create_bool("reset", false,
		"Reset", "Toggle to clear all particles"))


func _cook(inputs: Array[GNData]) -> GNData:
	var emitter: GNGeoData = _get_input_sop(inputs, 0)
	var attractor: GNGeoData = _get_input_sop(inputs, 1)

	if get_param_value("reset"):
		if _processor != null:
			_processor.reset()
		else:
			_positions.clear(); _velocities.clear(); _ages.clear(); _lives.clear()
			_next_id = 0; _emit_accum = 0.0
		return null

	if emitter == null or not emitter.has_geometry():
		return null

	# Rebuild emitter cache if source changed
	var emitter_hash: int = emitter.vertex_count * 31 + emitter.mesh.get_surface_count()
	if emitter_hash != _last_emitter_hash:
		_rebuild_emitter_cache(emitter)
		_last_emitter_hash = emitter_hash

	if _cached_verts.is_empty():
		return null

	var dt: float = current_delta
	if dt <= 0.0:
		dt = 1.0 / 60.0

	var attractor_pos := Vector3.ZERO
	if attractor != null and attractor.has_geometry():
		attractor_pos = attractor.bounds.get_center()

	# Gather params
	var rate: float = get_param_value("rate")
	var max_p: int = get_param_value("max_particles")
	var seed_val: int = get_param_value("seed")
	var life: float = get_param_value("life")
	var life_rand: float = get_param_value("life_rand")
	var emit_speed: float = get_param_value("emit_speed")
	var speed_rand: float = get_param_value("speed_rand")
	var spread: float = get_param_value("spread")
	var gravity: float = get_param_value("gravity")
	var drag: float = get_param_value("drag")
	var turbulence: float = get_param_value("turbulence")
	var attract_f: float = get_param_value("attract_force")
	var floor_on: bool = get_param_value("floor_enabled")
	var floor_y: float = get_param_value("floor_y")
	var bounce: float = get_param_value("bounce")

	var result_positions: PackedVector3Array
	var result_ages: PackedFloat32Array
	var result_lives: PackedFloat32Array
	var result_age_norm: PackedFloat32Array

	if _processor != null:
		var result: Dictionary = _processor.step(dt, rate, max_p,
			life, life_rand, emit_speed, speed_rand, spread,
			gravity, drag, turbulence, attract_f, attractor_pos,
			floor_on, floor_y, bounce, seed_val)
		result_positions = result.get("positions", PackedVector3Array())
		result_ages = result.get("ages", PackedFloat32Array())
		result_lives = result.get("lives", PackedFloat32Array())
		result_age_norm = result.get("age_norm", PackedFloat32Array())
	else:
		_step_gdscript(dt, rate, max_p, life, life_rand, emit_speed,
			speed_rand, spread, gravity, drag, turbulence, attract_f,
			attractor_pos, floor_on, floor_y, bounce)
		result_positions = _positions.duplicate()
		result_ages = _ages.duplicate()
		result_lives = _lives.duplicate()
		result_age_norm = PackedFloat32Array()
		result_age_norm.resize(result_ages.size())
		for i in range(result_ages.size()):
			result_age_norm[i] = result_ages[i] / maxf(result_lives[i], 0.001)

	if result_positions.is_empty():
		return null

	var out := _prepare_geo()
	var out_arrays: Array = []
	out_arrays.resize(Mesh.ARRAY_MAX)
	out_arrays[Mesh.ARRAY_VERTEX] = result_positions
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, out_arrays)
	out.set_mesh(mesh)
	out.set_point_attrib("age", result_ages)
	out.set_point_attrib("life", result_lives)
	out.set_point_attrib("age_norm", result_age_norm)
	return out


func _rebuild_emitter_cache(geo: GNGeoData) -> void:
	_cached_verts.clear()
	_cached_normals.clear()
	_cached_indices.clear()
	for s in range(geo.mesh.get_surface_count()):
		var arrays: Array = geo.mesh.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var idx: Variant = arrays[Mesh.ARRAY_INDEX]
		var base: int = _cached_verts.size()
		_cached_verts.append_array(verts)
		if norms.size() == verts.size():
			_cached_normals.append_array(norms)
		if idx != null and idx is PackedInt32Array and idx.size() > 0:
			for i in idx:
				_cached_indices.append(base + i)
	if _processor != null:
		_processor.set_emitter(_cached_verts, _cached_normals, _cached_indices)


# ═══════════════════════════════════════════════════════════════════════════════
# GDScript fallback simulation (simplified)
# ═══════════════════════════════════════════════════════════════════════════════

func _step_gdscript(dt: float, rate: float, max_p: int, life_base: float,
		life_rand_f: float, emit_speed: float, speed_rand_f: float,
		spread: float, gravity: float, drag: float, turbulence: float,
		attract_f: float, attractor_pos: Vector3,
		floor_on: bool, floor_y: float, bounce: float) -> void:
	# Emit
	_emit_accum += rate * dt
	var to_emit: int = int(_emit_accum)
	_emit_accum -= float(to_emit)
	var spread_rad: float = deg_to_rad(spread)
	for _e in range(to_emit):
		if _positions.size() >= max_p:
			_positions.remove_at(0); _velocities.remove_at(0)
			_ages.remove_at(0); _lives.remove_at(0)
		# Random point on emitter (flat triangles)
		if _cached_verts.size() < 3:
			continue
		var tri_idx: int = (_rng.randi() % (_cached_verts.size() / 3)) * 3
		var a := _cached_verts[tri_idx]
		var b := _cached_verts[tri_idx + 1]
		var c := _cached_verts[tri_idx + 2]
		var u: float = _rng.randf()
		var v: float = _rng.randf()
		if u + v > 1.0:
			u = 1.0 - u; v = 1.0 - v
		var pos: Vector3 = a + (b - a) * u + (c - a) * v
		var face_normal: Vector3 = (b - a).cross(c - a).normalized()
		if face_normal.length_squared() < 0.001:
			face_normal = Vector3.UP
		var vel_dir := face_normal
		if spread_rad > 0.0:
			vel_dir = vel_dir.rotated(vel_dir.cross(Vector3.UP).normalized(), _rng.randf_range(-spread_rad, spread_rad))
		var spd: float = emit_speed * (1.0 - speed_rand_f * _rng.randf())
		_positions.append(pos)
		_velocities.append(vel_dir * spd)
		var l: float = life_base * (1.0 - life_rand_f * _rng.randf())
		_ages.append(0.0)
		_lives.append(maxf(l, 0.01))

	# Simulate
	var grav := Vector3(0.0, gravity, 0.0)
	var drag_f: float = maxf(1.0 - drag * dt, 0.0)
	var i := 0
	while i < _positions.size():
		_ages[i] += dt
		if _ages[i] >= _lives[i]:
			_positions.remove_at(i); _velocities.remove_at(i)
			_ages.remove_at(i); _lives.remove_at(i)
			continue
		var accel := grav
		if attract_f != 0.0:
			var to_t: Vector3 = attractor_pos - _positions[i]
			if to_t.length() > 0.01:
				accel += to_t.normalized() * attract_f
		if turbulence > 0.0:
			accel += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1),
				_rng.randf_range(-1, 1)) * turbulence
		_velocities[i] += accel * dt
		_velocities[i] *= drag_f
		_positions[i] += _velocities[i] * dt
		if floor_on and _positions[i].y < floor_y:
			_positions[i].y = floor_y
			if bounce > 0.0:
				_velocities[i].y = absf(_velocities[i].y) * bounce
			else:
				_velocities[i] = Vector3.ZERO
		i += 1
