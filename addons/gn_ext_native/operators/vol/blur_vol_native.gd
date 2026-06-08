class_name BlurVOLNative
extends GNVolBase
## Native-accelerated 3D volume blur — delegates to GNNativeBlurVol (C++).

var _processor: RefCounted = null


func _init() -> void:
	super._init()
	node_type = "blur_native"
	node_description = "Multi-pass 3D box blur on volume — native C++ accelerated."
	if ClassDB.class_exists("GNNativeBlurVol"):
		_processor = ClassDB.instantiate("GNNativeBlurVol")


func _init_ports() -> void:
	add_input("vol_in", GNFamily.Type.VOL, true, "Volume to blur", "VOL")
	add_output("out", GNFamily.Type.VOL, "Blurred volume", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("radius", 1, 1, 4,
		"Radius", "Blur kernel radius in voxels"))
	add_parameter(GNParameter.create_int("passes", 1, 1, 4,
		"Passes", "Number of blur passes"))


func _cook(inputs: Array[GNData]) -> GNData:
	var vol: GNVolumeData = _get_input_vol(inputs, 0)
	if vol == null or not vol.has_volume() or not _processor:
		return null

	var ctx := _get_ctx()
	if ctx.rd == null:
		return null

	# GPU → CPU readback
	var raw: PackedByteArray = vol.read_full()
	if raw.is_empty():
		return null

	var res: Vector3i = vol.resolution
	var total: int = res.x * res.y * res.z
	var channels: int = vol.channels_per_voxel()
	var field := PackedFloat32Array()
	field.resize(total * channels)
	for i in range(total * channels):
		field[i] = raw.decode_float(i * 4)

	var blurred: PackedFloat32Array = _processor.process(field, res.x, res.y, res.z,
		channels, get_param_value("radius"), get_param_value("passes"))

	if blurred.is_empty():
		return null

	# Upload blurred result
	var out_vol := _create_volume(res, vol.format, vol.field_name)
	var bytes := PackedByteArray()
	bytes.resize(blurred.size() * 4)
	for i in range(blurred.size()):
		bytes.encode_float(i * 4, blurred[i])
	ctx.rd.texture_update(out_vol.rd_texture, 0, bytes)
	return out_vol
