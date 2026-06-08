class_name CHOPtoVOLNative
extends GNVolBase
## Native-accelerated CHOP→VOL — delegates to GNNativeChopToVol (C++).
## Converts channel data to a 3D float field, then uploads to GPU texture.

var _processor: RefCounted = null


func _init() -> void:
	super._init()
	node_type = "choptovol_native"
	node_description = "Convert CHOP channel data to a 3D volume — native C++ accelerated."
	if ClassDB.class_exists("GNNativeChopToVol"):
		_processor = ClassDB.instantiate("GNNativeChopToVol")


func _init_ports() -> void:
	add_input("chop", GNFamily.Type.CHOP, true, "Channel data to convert", "CHOP")
	add_output("out", GNFamily.Type.VOL, "Volume output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("res_x", 64, 4, 256, "Resolution X", "Grid width"))
	add_parameter(GNParameter.create_int("res_y", 64, 4, 256, "Resolution Y", "Grid height"))
	add_parameter(GNParameter.create_int("res_z", 64, 4, 256, "Resolution Z", "Grid depth"))
	add_parameter(GNParameter.create_enum("mode", PackedStringArray(["slice", "stack", "map"]), 0,
		"Mode", "How to map channels to voxels"))
	add_parameter(GNParameter.create_string("channel", "", "Channel",
		"Channel name (for stack/map modes, leave empty for first)"))


func _cook(inputs: Array[GNData]) -> GNData:
	if inputs.size() == 0 or not (inputs[0] is GNChannelData):
		return null
	var chop: GNChannelData = inputs[0] as GNChannelData
	var names: PackedStringArray = chop.get_channel_names()
	if names.is_empty():
		return null

	var ctx := _get_ctx()
	if ctx.rd == null:
		return null

	var res := Vector3i(get_param_value("res_x"), get_param_value("res_y"), get_param_value("res_z"))
	var mode: int = get_param_value("mode")
	var ch_name: String = get_param_value("channel")

	var total: int = res.x * res.y * res.z

	var field: PackedFloat32Array
	if _processor:
		field = _processor.process(chop.channels, names, res.x, res.y, res.z, mode, ch_name)
	else:
		field = _chop_to_vol_gdscript(chop, names, res, mode, ch_name)

	if field.is_empty():
		return null

	# Upload to GPU 3D texture
	var out_vol := _create_volume(res, RenderingDevice.DATA_FORMAT_R32_SFLOAT, "density")
	var bytes := PackedByteArray()
	bytes.resize(total * 4)
	for i in range(total):
		bytes.encode_float(i * 4, field[i])
	ctx.rd.texture_update(out_vol.rd_texture, 0, bytes)

	return out_vol


func _chop_to_vol_gdscript(chop: GNChannelData, names: PackedStringArray,
		res: Vector3i, mode: int, ch_name: String) -> PackedFloat32Array:
	var total: int = res.x * res.y * res.z
	var field := PackedFloat32Array()
	field.resize(total)

	match mode:
		0:  # slice
			var slice_size: int = res.x * res.y
			for zi in range(mini(names.size(), res.z)):
				var samples: PackedFloat32Array = chop.get_channel(names[zi])
				for i in range(mini(samples.size(), slice_size)):
					field[zi * slice_size + i] = samples[i]
		1:  # stack
			var target: String = ch_name if ch_name != "" else names[0]
			var samples: PackedFloat32Array = chop.get_channel(target)
			if samples.is_empty():
				return PackedFloat32Array()
			var slice_size: int = res.x * res.y
			for zi in range(res.z):
				for i in range(mini(samples.size(), slice_size)):
					field[zi * slice_size + i] = samples[i]
		2:  # map
			var tx: PackedFloat32Array = chop.get_channel("tx")
			var ty: PackedFloat32Array = chop.get_channel("ty")
			var tz: PackedFloat32Array = chop.get_channel("tz")
			var target: String = ch_name if ch_name != "" else "val"
			var vals: PackedFloat32Array = chop.get_channel(target)
			if tx.is_empty() or ty.is_empty() or tz.is_empty():
				return PackedFloat32Array()
			var count: int = mini(mini(tx.size(), ty.size()), mini(tz.size(), vals.size()))
			for i in range(count):
				var gx: int = clampi(int(tx[i] * float(res.x)), 0, res.x - 1)
				var gy: int = clampi(int(ty[i] * float(res.y)), 0, res.y - 1)
				var gz: int = clampi(int(tz[i] * float(res.z)), 0, res.z - 1)
				field[gz * res.y * res.x + gy * res.x + gx] += vals[i]

	return field
