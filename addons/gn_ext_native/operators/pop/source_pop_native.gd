class_name SourcePOPNative
extends GNPopBase
## Native-accelerated particle emitter — delegates to GNNativeSourcePop (C++).

var _processor: RefCounted = null
var _cpu_data: GNParticleData = null


func _init() -> void:
	super._init()
	node_type = "source_native"
	time_dependent = true
	node_description = "Emit particles with age/kill/pscale — native C++ accelerated."
	if ClassDB.class_exists("GNNativeSourcePop"):
		_processor = ClassDB.instantiate("GNNativeSourcePop")


func _init_ports() -> void:
	add_input("geo_in", GNFamily.Type.SOP, false, "Emitter geometry (optional)")
	add_output("out", GNFamily.Type.POP, "Particle data output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("max_particles", 100000,
		1000, 1000000, "Max Particles", "Maximum particle pool size"))
	add_parameter(GNParameter.create_float("rate", 1000.0,
		0.0, 100000.0, 0.01, "Emit Rate", "Particles emitted per second"))
	add_parameter(GNParameter.create_float("life_min", 1.0,
		0.01, 60.0, 0.01, "Life Min", "Minimum particle lifespan"))
	add_parameter(GNParameter.create_float("life_max", 3.0,
		0.01, 60.0, 0.01, "Life Max", "Maximum particle lifespan"))
	add_parameter(GNParameter.create_float("init_speed", 1.0,
		0.0, 100.0, 0.01, "Initial Speed", "Speed at emission"))
	add_parameter(GNParameter.create_float("pscale", 0.05,
		0.001, 10.0, 0.01, "Point Scale", "Initial pscale"))
	add_parameter(GNParameter.create_bool("reset", false, "Reset",
		"Pulse to clear all particles"))


func _cook_cpu(inputs: Array[GNData]) -> GNData:
	if not _processor:
		return null

	var max_p: int = get_param_value("max_particles")
	var rate: float = get_param_value("rate")
	var dt: float = current_delta

	# Reset
	if get_param_value("reset") or _cpu_data == null or _cpu_data.max_particles != max_p:
		_cpu_data = _allocate_particles_cpu(max_p)
		set_param_value("reset", false)

	# Emit points from SOP or origin
	var emit_points := PackedVector3Array()
	if inputs.size() > 0 and inputs[0] is GNGeoData:
		var geo: GNGeoData = inputs[0] as GNGeoData
		if geo.has_geometry() and geo.mesh != null:
			var arrays: Array = geo.mesh.surface_get_arrays(0)
			if arrays[Mesh.ARRAY_VERTEX] != null:
				emit_points = arrays[Mesh.ARRAY_VERTEX]
	if emit_points.is_empty():
		emit_points.append(Vector3.ZERO)

	var emit_count: int = mini(int(rate * dt), max_p - _cpu_data.particle_count)
	if emit_count < 0:
		emit_count = 0

	var result: Dictionary = _processor.process(
		_cpu_data.cpu_positions, _cpu_data.cpu_velocities,
		_cpu_data.cpu_ages, _cpu_data.cpu_lives, _cpu_data.cpu_pscales,
		_cpu_data.particle_count, max_p, emit_points, emit_count,
		get_param_value("life_min"), get_param_value("life_max"),
		get_param_value("init_speed"), get_param_value("pscale"),
		dt, elapsed_time)

	_cpu_data.cpu_positions = result.get("positions", _cpu_data.cpu_positions)
	_cpu_data.cpu_velocities = result.get("velocities", _cpu_data.cpu_velocities)
	_cpu_data.cpu_ages = result.get("ages", _cpu_data.cpu_ages)
	_cpu_data.cpu_lives = result.get("lives", _cpu_data.cpu_lives)
	_cpu_data.cpu_pscales = result.get("pscales", _cpu_data.cpu_pscales)
	_cpu_data.particle_count = result.get("count", _cpu_data.particle_count)
	return _cpu_data
