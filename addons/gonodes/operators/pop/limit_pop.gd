class_name LimitPOP
extends GNPopBase
## Kills particles by age, bounding box, or speed limit.
## Processor: modifies the incoming SSBO in-place.

func _init() -> void:
	super._init()
	node_type = "limit"
	node_description = "Kill particles by age, bounds, or speed. Clamp particle velocities."


func _init_ports() -> void:
	add_input("pop_in", GNFamily.Type.POP, false, "Particle input")
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
