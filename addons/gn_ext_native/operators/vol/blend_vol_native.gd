class_name BlendVOLNative
extends GNVolBase
## Native-accelerated two-volume blend — delegates to GNNativeBlendVol (C++).

var _processor: RefCounted = null

const OP_MAP := {"add": 0, "subtract": 1, "multiply": 2, "max": 3, "min": 4, "mix": 5}


func _init() -> void:
	super._init()
	node_type = "blend"
	node_description = "Blend two volumes with arithmetic operations — native C++ accelerated."
	if ClassDB.class_exists("GNNativeBlendVol"):
		_processor = ClassDB.instantiate("GNNativeBlendVol")


func _init_ports() -> void:
	add_input("vol_a", GNFamily.Type.VOL, true, "Volume A")
	add_input("vol_b", GNFamily.Type.VOL, true, "Volume B")
	add_output("out", GNFamily.Type.VOL, "Blended volume")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("operation", "add",
		"Operation", "add/subtract/multiply/max/min/mix"))
	add_parameter(GNParameter.create_float("mix_factor", 0.5, 0.0, 1.0, 0.01,
		"Mix Factor", "Blend ratio for mix mode"))
	add_parameter(GNParameter.create_float("scale_a", 1.0, 0.0, 10.0, 0.01,
		"Scale A", "Pre-multiply factor for volume A"))
	add_parameter(GNParameter.create_float("scale_b", 1.0, 0.0, 10.0, 0.01,
		"Scale B", "Pre-multiply factor for volume B"))


func _cook(inputs: Array[GNData]) -> GNData:
	var vol_a: GNVolumeData = _get_input_vol(inputs, 0)
	var vol_b: GNVolumeData = _get_input_vol(inputs, 1)
	if vol_a == null or vol_b == null or not _processor:
		return null
	if not vol_a.has_volume() or not vol_b.has_volume():
		return null

	var ctx := _get_ctx()
	if ctx.rd == null:
		return null

	var raw_a: PackedByteArray = vol_a.read_full()
	var raw_b: PackedByteArray = vol_b.read_full()
	var total: int = mini(raw_a.size(), raw_b.size()) / 4

	var fa := PackedFloat32Array()
	fa.resize(total)
	var fb := PackedFloat32Array()
	fb.resize(total)
	for i in range(total):
		fa[i] = raw_a.decode_float(i * 4)
		fb[i] = raw_b.decode_float(i * 4)

	var op_str: String = get_param_value("operation")
	var op_idx: int = OP_MAP.get(op_str, 0)

	var blended: PackedFloat32Array = _processor.process(fa, fb, total, op_idx,
		get_param_value("mix_factor"), get_param_value("scale_a"),
		get_param_value("scale_b"))

	if blended.is_empty():
		return null

	var res: Vector3i = vol_a.resolution
	var out_vol := _create_volume(res, vol_a.format, vol_a.field_name)
	var bytes := PackedByteArray()
	bytes.resize(blended.size() * 4)
	for i in range(blended.size()):
		bytes.encode_float(i * 4, blended[i])
	ctx.rd.texture_update(out_vol.rd_texture, 0, bytes)
	return out_vol
