class_name CollisionPOPNative
extends GNPopBase
## Native-accelerated ground plane collision — delegates to GNNativeCollisionPop (C++).

var _processor: RefCounted = null


func _init() -> void:
	super._init()
	node_type = "collision_native"
	time_dependent = true
	node_description = "Ground plane collision with bounce and kill — native C++ accelerated."
	if ClassDB.class_exists("GNNativeCollisionPop"):
		_processor = ClassDB.instantiate("GNNativeCollisionPop")


func _init_ports() -> void:
	add_input("pop_in", GNFamily.Type.POP, false, "Particle input")
	add_output("out", GNFamily.Type.POP, "Particle data output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("ground_y", 0.0, -100.0, 100.0, 0.1,
		"Ground Y", "Ground plane height"))
	add_parameter(GNParameter.create_float("bounce", 0.3, 0.0, 1.0, 0.01,
		"Bounce", "Restitution coefficient"))
	add_parameter(GNParameter.create_float("friction", 0.1, 0.0, 1.0, 0.01,
		"Friction", "Horizontal velocity damping on contact"))
	add_parameter(GNParameter.create_float("kill_below", -1000.0, -10000.0, 100.0, 1.0,
		"Kill Below", "Kill particles below this Y"))


func _cook_cpu(inputs: Array[GNData]) -> GNData:
	var pd := _get_input_pop_cpu(inputs)
	if pd == null or not pd.has_particles() or not _processor:
		return null

	var result: Dictionary = _processor.process(pd.cpu_positions, pd.cpu_velocities,
		pd.cpu_ages, pd.cpu_lives, pd.particle_count,
		get_param_value("ground_y"), get_param_value("bounce"),
		get_param_value("friction"), get_param_value("kill_below"))

	pd.cpu_positions = result.get("positions", pd.cpu_positions)
	pd.cpu_velocities = result.get("velocities", pd.cpu_velocities)
	pd.cpu_ages = result.get("ages", pd.cpu_ages)
	pd.cpu_lives = result.get("lives", pd.cpu_lives)
	pd.particle_count = result.get("count", pd.particle_count)
	return pd
