class_name LimitPOPNative
extends GNPopBase
## Native-accelerated bounding box kill + speed clamp — delegates to GNNativeLimitPop (C++).

var _processor: RefCounted = null


func _init() -> void:
	super._init()
	node_type = "limit_native"
	time_dependent = true
	node_description = "Kill particles outside bbox and clamp speed — native C++ accelerated."
	if ClassDB.class_exists("GNNativeLimitPop"):
		_processor = ClassDB.instantiate("GNNativeLimitPop")


func _init_ports() -> void:
	add_input("pop_in", GNFamily.Type.POP, false, "Particle input", "POP")
	add_output("out", GNFamily.Type.POP, "Particle data output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("bbox_min_x", -10.0, -1000.0, 1000.0, 0.1, "Min X", "Bounding box min X"))
	add_parameter(GNParameter.create_float("bbox_min_y", -10.0, -1000.0, 1000.0, 0.1, "Min Y", "Bounding box min Y"))
	add_parameter(GNParameter.create_float("bbox_min_z", -10.0, -1000.0, 1000.0, 0.1, "Min Z", "Bounding box min Z"))
	add_parameter(GNParameter.create_float("bbox_max_x", 10.0, -1000.0, 1000.0, 0.1, "Max X", "Bounding box max X"))
	add_parameter(GNParameter.create_float("bbox_max_y", 10.0, -1000.0, 1000.0, 0.1, "Max Y", "Bounding box max Y"))
	add_parameter(GNParameter.create_float("bbox_max_z", 10.0, -1000.0, 1000.0, 0.1, "Max Z", "Bounding box max Z"))
	add_parameter(GNParameter.create_float("max_speed", 0.0, 0.0, 1000.0, 0.1,
		"Max Speed", "Speed clamp (0 = unlimited)"))
	add_parameter(GNParameter.create_bool("kill_outside", true, "Kill Outside",
		"Kill particles outside the bounding box"))


func _cook_cpu(inputs: Array[GNData]) -> GNData:
	var pd := _get_input_pop_cpu(inputs)
	if pd == null or not pd.has_particles() or not _processor:
		return null

	var result: Dictionary = _processor.process(pd.cpu_positions, pd.cpu_velocities,
		pd.cpu_ages, pd.cpu_lives, pd.particle_count,
		get_param_value("bbox_min_x"), get_param_value("bbox_min_y"),
		get_param_value("bbox_min_z"), get_param_value("bbox_max_x"),
		get_param_value("bbox_max_y"), get_param_value("bbox_max_z"),
		get_param_value("max_speed"), get_param_value("kill_outside"))

	pd.cpu_positions = result.get("positions", pd.cpu_positions)
	pd.cpu_velocities = result.get("velocities", pd.cpu_velocities)
	pd.cpu_ages = result.get("ages", pd.cpu_ages)
	pd.cpu_lives = result.get("lives", pd.cpu_lives)
	pd.particle_count = result.get("count", pd.particle_count)
	return pd
