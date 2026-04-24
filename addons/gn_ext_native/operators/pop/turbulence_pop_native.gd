class_name TurbulencePOPNative
extends GNPopBase
## Native-accelerated curl noise turbulence — delegates to GNNativeTurbulencePop (C++).

var _processor: RefCounted = null


func _init() -> void:
	super._init()
	node_type = "turbulence_native"
	time_dependent = true
	node_description = "Curl noise turbulence force field — native C++ accelerated."
	if ClassDB.class_exists("GNNativeTurbulencePop"):
		_processor = ClassDB.instantiate("GNNativeTurbulencePop")


func _init_ports() -> void:
	add_input("pop_in", GNFamily.Type.POP, false, "Particle input")
	add_output("out", GNFamily.Type.POP, "Particle data output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("amplitude", 2.0, 0.0, 100.0, 0.1,
		"Amplitude", "Turbulence strength"))
	add_parameter(GNParameter.create_float("frequency", 1.0, 0.01, 50.0, 0.01,
		"Frequency", "Noise frequency"))
	add_parameter(GNParameter.create_float("roughness", 0.5, 0.0, 1.0, 0.01,
		"Roughness", "FBM gain per octave"))
	add_parameter(GNParameter.create_int("octaves", 3, 1, 8,
		"Octaves", "Number of noise layers"))
	add_parameter(GNParameter.create_float("speed", 0.5, 0.0, 10.0, 0.1,
		"Speed", "Time animation speed"))


func _cook_cpu(inputs: Array[GNData]) -> GNData:
	var pd := _get_input_pop_cpu(inputs)
	if pd == null or not pd.has_particles() or not _processor:
		return null

	var time_val: float = elapsed_time * get_param_value("speed")

	var new_vel: PackedVector3Array = _processor.process(pd.cpu_positions,
		pd.cpu_velocities, pd.particle_count,
		get_param_value("amplitude"), get_param_value("frequency"),
		time_val, get_param_value("roughness"),
		get_param_value("octaves"), current_delta)

	pd.cpu_velocities = new_vel
	return pd
