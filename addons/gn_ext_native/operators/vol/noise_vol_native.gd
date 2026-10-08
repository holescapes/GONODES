class_name NoiseVOLNative
extends GNVolBase
## Native-accelerated FBM noise volume generator — delegates to GNNativeNoiseVol (C++).

var _processor: RefCounted = null


func _init() -> void:
	super._init()
	node_type = "noise_native"
	node_description = "FBM value noise volume generator — native C++ accelerated."
	if ClassDB.class_exists("GNNativeNoiseVol"):
		_processor = ClassDB.instantiate("GNNativeNoiseVol")


## When speed == 0 the noise is static.
func update_time_dependency() -> void:
	time_dependent = get_param_value("speed") != 0.0


func _init_ports() -> void:
	add_output("out", GNFamily.Type.VOL, "Noise volume")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("res_x", 64, 8, 512, "Res X", "Grid width"))
	add_parameter(GNParameter.create_int("res_y", 64, 8, 512, "Res Y", "Grid height"))
	add_parameter(GNParameter.create_int("res_z", 64, 8, 512, "Res Z", "Grid depth"))
	add_parameter(GNParameter.create_float("frequency", 4.0, 0.01, 100.0, 0.01,
		"Frequency", "Noise frequency"))
	add_parameter(GNParameter.create_float("amplitude", 1.0, 0.0, 10.0, 0.01,
		"Amplitude", "Noise amplitude"))
	add_parameter(GNParameter.create_int("octaves", 4, 1, 8,
		"Octaves", "FBM octave count"))
	add_parameter(GNParameter.create_float("lacunarity", 2.0, 1.0, 4.0, 0.01,
		"Lacunarity", "Frequency multiplier per octave"))
	add_parameter(GNParameter.create_float("gain", 0.5, 0.0, 1.0, 0.01,
		"Gain", "Amplitude multiplier per octave"))
	add_parameter(GNParameter.create_float("offset_x", 0.0, -100.0, 100.0, 0.1,
		"Offset X", "Noise field offset X"))
	add_parameter(GNParameter.create_float("offset_y", 0.0, -100.0, 100.0, 0.1,
		"Offset Y", "Noise field offset Y"))
	add_parameter(GNParameter.create_float("offset_z", 0.0, -100.0, 100.0, 0.1,
		"Offset Z", "Noise field offset Z"))
	add_parameter(GNParameter.create_float("speed", 0.0, 0.0, 10.0, 0.1,
		"Speed", "Time animation speed"))


func _cook(inputs: Array[GNData]) -> GNData:
	if not _processor:
		return null

	var ctx := _get_ctx()
	if ctx.rd == null:
		return null

	var rx: int = get_param_value("res_x")
	var ry: int = get_param_value("res_y")
	var rz: int = get_param_value("res_z")
	var time_val: float = elapsed_time * get_param_value("speed")

	var field: PackedFloat32Array = _processor.process(rx, ry, rz,
		get_param_value("frequency"), get_param_value("amplitude"),
		get_param_value("offset_x"), get_param_value("offset_y"),
		get_param_value("offset_z"), time_val,
		get_param_value("lacunarity"), get_param_value("gain"),
		get_param_value("octaves"), 0)

	if field.is_empty():
		return null

	var res := Vector3i(rx, ry, rz)
	var out_vol := _create_volume(res, RenderingDevice.DATA_FORMAT_R32_SFLOAT, "density")
	var bytes := PackedByteArray()
	bytes.resize(field.size() * 4)
	for i in range(field.size()):
		bytes.encode_float(i * 4, field[i])
	ctx.rd.texture_update(out_vol.rd_texture, 0, bytes)
	return out_vol
