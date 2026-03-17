class_name ForcePOPNative
extends GNPopBase
## Native-accelerated force integration — delegates to GNNativeForcePop (C++).

var _processor: RefCounted = null


func _init() -> void:
	super._init()
	node_type = "force"
	time_dependent = true
	node_description = "Apply gravity, wind, and drag forces — native C++ accelerated."
	if ClassDB.class_exists("GNNativeForcePop"):
		_processor = ClassDB.instantiate("GNNativeForcePop")


func _init_ports() -> void:
	add_input("pop_in", GNFamily.Type.POP, false, "Particle input")
	add_output("out", GNFamily.Type.POP, "Particle data output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("gravity_x", 0.0, -100.0, 100.0, 0.01, "Gravity X", "X gravity"))
	add_parameter(GNParameter.create_float("gravity_y", -9.81, -100.0, 100.0, 0.01, "Gravity Y", "Y gravity"))
	add_parameter(GNParameter.create_float("gravity_z", 0.0, -100.0, 100.0, 0.01, "Gravity Z", "Z gravity"))
	add_parameter(GNParameter.create_float("wind_x", 0.0, -100.0, 100.0, 0.01, "Wind X", "X wind force"))
	add_parameter(GNParameter.create_float("wind_y", 0.0, -100.0, 100.0, 0.01, "Wind Y", "Y wind force"))
	add_parameter(GNParameter.create_float("wind_z", 0.0, -100.0, 100.0, 0.01, "Wind Z", "Z wind force"))
	add_parameter(GNParameter.create_float("drag", 0.01, 0.0, 1.0, 0.01, "Drag", "Velocity damping"))


func _cook_cpu(inputs: Array[GNData]) -> GNData:
	var pd := _get_input_pop_cpu(inputs)
	if pd == null or not pd.has_particles() or not _processor:
		return null

	var fx: float = get_param_value("gravity_x") + get_param_value("wind_x")
	var fy: float = get_param_value("gravity_y") + get_param_value("wind_y")
	var fz: float = get_param_value("gravity_z") + get_param_value("wind_z")

	var result: Dictionary = _processor.process(pd.cpu_positions, pd.cpu_velocities,
		pd.particle_count, fx, fy, fz, get_param_value("drag"), current_delta)

	pd.cpu_positions = result.get("positions", pd.cpu_positions)
	pd.cpu_velocities = result.get("velocities", pd.cpu_velocities)
	return pd
