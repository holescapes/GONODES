class_name LimitPOP
extends GNPopBase
## Kills particles by age, bounding box, or speed limit.
## Processor: modifies the incoming SSBO in-place.

func _init() -> void:
	super._init()
	node_type = "limit"
	node_description = "Kill particles by age, bounds, or speed. Clamp particle velocities."


func _init_ports() -> void:
	add_input("pop_in", GNFamily.Type.POP, false, "Particle input", "Pop")
	add_output("out", GNFamily.Type.POP, "Particle data output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("bbox_min_x", -10.0, -1000.0, 1000.0, 0.1, "BBox Min X", "Bounding box min X"))
	add_parameter(GNParameter.create_float("bbox_min_y", -10.0, -1000.0, 1000.0, 0.1, "BBox Min Y", "Bounding box min Y"))
	add_parameter(GNParameter.create_float("bbox_min_z", -10.0, -1000.0, 1000.0, 0.1, "BBox Min Z", "Bounding box min Z"))
	add_parameter(GNParameter.create_float("bbox_max_x", 10.0, -1000.0, 1000.0, 0.1, "BBox Max X", "Bounding box max X"))
	add_parameter(GNParameter.create_float("bbox_max_y", 10.0, -1000.0, 1000.0, 0.1, "BBox Max Y", "Bounding box max Y"))
	add_parameter(GNParameter.create_float("bbox_max_z", 10.0, -1000.0, 1000.0, 0.1, "BBox Max Z", "Bounding box max Z"))
	add_parameter(GNParameter.create_float("max_speed", 0.0,
		0.0, 1000.0, 0.1, "Max Speed", "Clamp velocity magnitude (0 = no limit)"))
	add_parameter(GNParameter.create_bool("kill_outside", true, "Kill Outside Bounds",
		"Remove particles that exit the bounding box"))


func _cook(inputs: Array[GNData]) -> GNData:
	var pd := _get_input_pop(inputs)
	if pd == null or not pd.has_particles():
		return null

	var ctx := _get_ctx()
	if ctx.rd == null:
		return pd

	var shader: RID = ctx.get_shader("res://addons/gonodes/shaders/pop/limit_pop.glsl")
	if not shader.is_valid():
		return pd

	var pc := PackedByteArray()
	pc.resize(48)  # 10 fields (40 bytes) padded to 48 (next multiple of 16)
	pc.encode_s32(0, pd.particle_count)
	pc.encode_float(4, current_delta)
	pc.encode_float(8, get_param_value("bbox_min_x"))
	pc.encode_float(12, get_param_value("bbox_min_y"))
	pc.encode_float(16, get_param_value("bbox_min_z"))
	pc.encode_float(20, get_param_value("bbox_max_x"))
	pc.encode_float(24, get_param_value("bbox_max_y"))
	pc.encode_float(28, get_param_value("bbox_max_z"))
	pc.encode_float(32, get_param_value("max_speed"))
	pc.encode_s32(36, 1 if get_param_value("kill_outside") else 0)
	pc.encode_float(40, 0.0)  # padding
	pc.encode_float(44, 0.0)  # padding

	var uniform_set: RID = ctx.rd.uniform_set_create([
		ctx.uniform_buffer(0, pd.rd_buffer),
	], shader, 0)

	ctx.dispatch(shader, uniform_set, _workgroups(pd.particle_count), 1, 1, pc)
	ctx.rd.free_rid(uniform_set)

	return pd


func _cook_cpu(inputs: Array[GNData]) -> GNData:
	var pd := _get_input_pop_cpu(inputs)
	if pd == null or not pd.has_particles():
		return null

	var bbox_min := Vector3(
		get_param_value("bbox_min_x"),
		get_param_value("bbox_min_y"),
		get_param_value("bbox_min_z"))
	var bbox_max := Vector3(
		get_param_value("bbox_max_x"),
		get_param_value("bbox_max_y"),
		get_param_value("bbox_max_z"))
	var max_speed: float = get_param_value("max_speed")
	var kill_outside: bool = get_param_value("kill_outside")

	var write_idx: int = 0
	for i in range(pd.particle_count):
		var pos: Vector3 = pd.cpu_positions[i]
		# Kill outside bounds
		if kill_outside:
			if pos.x < bbox_min.x or pos.x > bbox_max.x \
			or pos.y < bbox_min.y or pos.y > bbox_max.y \
			or pos.z < bbox_min.z or pos.z > bbox_max.z:
				continue
		# Speed clamp
		if max_speed > 0.0:
			var vel: Vector3 = pd.cpu_velocities[i]
			var spd: float = vel.length()
			if spd > max_speed:
				pd.cpu_velocities[i] = vel * (max_speed / spd)
		# Compact
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

	return pd
