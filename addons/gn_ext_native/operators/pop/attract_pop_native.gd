class_name AttractPOPNative
extends GNPopBase
## Native-accelerated point attractor — delegates to GNNativeAttractPop (C++).

var _processor: RefCounted = null


func _init() -> void:
	super._init()
	node_type = "attract_native"
	time_dependent = true
	node_description = "Inverse-square point attractor — native C++ accelerated."
	if ClassDB.class_exists("GNNativeAttractPop"):
		_processor = ClassDB.instantiate("GNNativeAttractPop")


func _init_ports() -> void:
	add_input("pop_in", GNFamily.Type.POP, false, "Particle input", "POP")
	add_output("out", GNFamily.Type.POP, "Particle data output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("target_x", 0.0, -100.0, 100.0, 0.1,
		"Target X", "Attractor X position"))
	add_parameter(GNParameter.create_float("target_y", 1.0, -100.0, 100.0, 0.1,
		"Target Y", "Attractor Y position"))
	add_parameter(GNParameter.create_float("target_z", 0.0, -100.0, 100.0, 0.1,
		"Target Z", "Attractor Z position"))
	add_parameter(GNParameter.create_float("strength", 10.0, -100.0, 100.0, 0.1,
		"Strength", "Attraction force multiplier"))
	add_parameter(GNParameter.create_float("radius", 0.0, 0.0, 1000.0, 0.1,
		"Radius", "Max effect radius (0 = infinite)"))


func _cook_cpu(inputs: Array[GNData]) -> GNData:
	var pd := _get_input_pop_cpu(inputs)
	if pd == null or not pd.has_particles() or not _processor:
		return null

	var new_vel: PackedVector3Array = _processor.process(pd.cpu_positions,
		pd.cpu_velocities,
		get_param_value("target_x"), get_param_value("target_y"),
		get_param_value("target_z"), get_param_value("strength"),
		get_param_value("radius"), current_delta)

	pd.cpu_velocities = new_vel
	return pd
