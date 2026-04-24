class_name AdvectPOPNative
extends GNPopBase
## Native-accelerated volume-field advection — delegates to GNNativeAdvectPop (C++).

var _processor: RefCounted = null


func _init() -> void:
	super._init()
	node_type = "advect_native"
	time_dependent = true
	node_description = "Advect particles through a velocity volume field — native C++ accelerated."
	if ClassDB.class_exists("GNNativeAdvectPop"):
		_processor = ClassDB.instantiate("GNNativeAdvectPop")


func _init_ports() -> void:
	add_input("pop_in", GNFamily.Type.POP, false, "Particle input")
	add_input("vol_in", GNFamily.Type.VOL, false, "Velocity volume field")
	add_output("out", GNFamily.Type.POP, "Advected particles")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("strength", 1.0, 0.0, 100.0, 0.1,
		"Strength", "Advection strength multiplier"))
	add_parameter(GNParameter.create_bool("add_mode", true, "Add Mode",
		"Add velocity (true) or replace (false)"))


func _cook_cpu(inputs: Array[GNData]) -> GNData:
	var pd := _get_input_pop_cpu(inputs)
	if pd == null or not pd.has_particles() or not _processor:
		return null

	var vol: GNVolumeData = inputs[1] as GNVolumeData if inputs.size() > 1 and inputs[1] is GNVolumeData else null
	if vol == null or not vol.has_volume():
		return pd

	# Read volume data for CPU sampling
	var raw: PackedByteArray = vol.read_full()
	if raw.is_empty():
		return pd

	var vol_ch: int = vol.channels_per_voxel()
	var vol_total: int = vol.resolution.x * vol.resolution.y * vol.resolution.z * vol_ch
	var vol_data := PackedFloat32Array()
	vol_data.resize(vol_total)
	for i in range(vol_total):
		vol_data[i] = raw.decode_float(i * 4)

	var bounds_min: Vector3 = vol.bounds_min if vol.has("bounds_min") else Vector3.ZERO
	var bounds_size: Vector3 = vol.bounds_size if vol.has("bounds_size") else Vector3.ONE

	var new_vel: PackedVector3Array = _processor.process(pd.cpu_positions,
		pd.cpu_velocities, vol_data,
		vol.resolution.x, vol.resolution.y, vol.resolution.z, vol_ch,
		bounds_min.x, bounds_min.y, bounds_min.z,
		bounds_size.x, bounds_size.y, bounds_size.z,
		get_param_value("strength"), current_delta, get_param_value("add_mode"))

	pd.cpu_velocities = new_vel
	return pd
