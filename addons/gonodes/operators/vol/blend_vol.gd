class_name BlendVOL
extends GNVolBase
## Blends two volumes with configurable operations (add, subtract, multiply, max, min, mix).

func _init() -> void:
	super._init()
	node_type = "blend"
	node_description = "Combine two volumes (add, subtract, multiply, max, min, mix)."


func _init_ports() -> void:
	add_input("vol_a", GNFamily.Type.VOL, false, "Volume A")
	add_input("vol_b", GNFamily.Type.VOL, false, "Volume B")
	add_output("out", GNFamily.Type.VOL, "Blended volume")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("operation", "add", "Operation",
		"Blend mode: add, subtract, multiply, max, min, mix"))
	add_parameter(GNParameter.create_float("mix_factor", 0.5,
		0.0, 1.0, 0.01, "Mix Factor", "Blend weight for mix operation (0=A, 1=B)"))
	add_parameter(GNParameter.create_float("scale_a", 1.0,
		0.0, 10.0, 0.01, "Scale A", "Multiply A before blend"))
	add_parameter(GNParameter.create_float("scale_b", 1.0,
		0.0, 10.0, 0.01, "Scale B", "Multiply B before blend"))


func _cook(inputs: Array[GNData]) -> GNData:
	var vol_a := _get_input_vol(inputs, 0)
	var vol_b := _get_input_vol(inputs, 1)
	if vol_a == null or not vol_a.has_volume():
		return vol_b
	if vol_b == null or not vol_b.has_volume():
		return vol_a

	var ctx := _get_ctx()
	if ctx.rd == null:
		return null

	var res: Vector3i = vol_a.resolution
	var out_vol := _create_volume(res, vol_a.data_format, vol_a.field_name)

	var shader: RID = ctx.get_shader("res://addons/gonodes/shaders/vol/blend_vol.glsl")
	if not shader.is_valid():
		return null

	var op_idx: int = _op_to_int(get_param_value("operation"))

	var pc := PackedByteArray()
	pc.resize(32)
	pc.encode_s32(0, res.x)
	pc.encode_s32(4, res.y)
	pc.encode_s32(8, res.z)
	pc.encode_s32(12, op_idx)
	pc.encode_float(16, get_param_value("mix_factor"))
	pc.encode_float(20, get_param_value("scale_a"))
	pc.encode_float(24, get_param_value("scale_b"))
	pc.encode_float(28, 0.0)

	var uniform_set: RID = ctx.rd.uniform_set_create([
		ctx.uniform_image(0, vol_a.rd_texture),
		ctx.uniform_image(1, vol_b.rd_texture),
		ctx.uniform_image(2, out_vol.rd_texture),
	], shader, 0)

	var wg := _workgroups_3d(res)
	ctx.dispatch(shader, uniform_set, wg.x, wg.y, wg.z, pc)
	ctx.rd.free_rid(uniform_set)

	return out_vol


func _op_to_int(op: String) -> int:
	match op.to_lower():
		"add": return 0
		"subtract": return 1
		"multiply": return 2
		"max": return 3
		"min": return 4
		"mix": return 5
	return 0
