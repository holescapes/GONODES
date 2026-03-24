class_name CHOPtoVOL
extends GNVolBase
## Converts CHOP channel data into a 3D volume.
##
## Modes:
##   • slice — Each channel fills one Z-slice (channel length → XY row-major).
##   • stack — First channel replicated across all slices (uniform fill).
##   • map   — Maps tx/ty/tz channels to field values (scattered).
##
## Useful for driving procedural volumes from audio, motion, or expression data.

func _init() -> void:
	super._init()
	node_type = "chop_to_vol"
	node_description = "Convert CHOP channel data to a 3D volume."


func _init_ports() -> void:
	add_input("chop", GNFamily.Type.CHOP, true, "Channel data to convert")
	add_output("out", GNFamily.Type.VOL, "Volume output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("res_x", 64, 4, 256, "Resolution X", "Grid width"))
	add_parameter(GNParameter.create_int("res_y", 64, 4, 256, "Resolution Y", "Grid height"))
	add_parameter(GNParameter.create_int("res_z", 64, 4, 256, "Resolution Z", "Grid depth"))
	add_parameter(GNParameter.create_enum("mode", ["slice", "stack", "map"], 0, "Mode",
		"How to map channels to voxels"))
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
	var field := PackedFloat32Array()
	field.resize(total)

	match mode:
		0:  # slice — each channel → one Z-slice
			var slice_size: int = res.x * res.y
			for zi in range(mini(names.size(), res.z)):
				var samples: PackedFloat32Array = chop.get_channel(names[zi])
				for i in range(mini(samples.size(), slice_size)):
					field[zi * slice_size + i] = samples[i]
		1:  # stack — one channel, fill all slices uniformly
			var target: String = ch_name if ch_name != "" else names[0]
			var samples: PackedFloat32Array = chop.get_channel(target)
			if samples.is_empty():
				return null
			var slice_size: int = res.x * res.y
			for zi in range(res.z):
				for i in range(mini(samples.size(), slice_size)):
					field[zi * slice_size + i] = samples[i]
		2:  # map — tx/ty/tz channels → voxel positions, value channel → density
			var tx: PackedFloat32Array = chop.get_channel("tx")
			var ty: PackedFloat32Array = chop.get_channel("ty")
			var tz: PackedFloat32Array = chop.get_channel("tz")
			var target: String = ch_name if ch_name != "" else "val"
			var vals: PackedFloat32Array = chop.get_channel(target)
			if tx.is_empty() or ty.is_empty() or tz.is_empty():
				return null
			var count: int = mini(mini(tx.size(), ty.size()), mini(tz.size(), vals.size()))
			for i in range(count):
				# Normalize [0,1] → grid coords
				var gx: int = clampi(int(tx[i] * float(res.x)), 0, res.x - 1)
				var gy: int = clampi(int(ty[i] * float(res.y)), 0, res.y - 1)
				var gz: int = clampi(int(tz[i] * float(res.z)), 0, res.z - 1)
				field[gz * res.y * res.x + gy * res.x + gx] += vals[i]

	# Upload to GPU 3D texture
	var out_vol := _create_volume(res, RenderingDevice.DATA_FORMAT_R32_SFLOAT, "density")

	# Convert float array to bytes and upload
	var bytes := PackedByteArray()
	bytes.resize(total * 4)
	for i in range(total):
		bytes.encode_float(i * 4, field[i])

	# Upload via texture_update
	ctx.rd.texture_update(out_vol.rd_texture, 0, bytes)

	return out_vol


func _cook_cpu(inputs: Array[GNData]) -> GNData:
	if inputs.size() == 0 or not (inputs[0] is GNChannelData):
		return null
	var chop: GNChannelData = inputs[0] as GNChannelData
	var names: PackedStringArray = chop.get_channel_names()
	if names.is_empty():
		return null

	var res := Vector3i(get_param_value("res_x"), get_param_value("res_y"), get_param_value("res_z"))
	var mode: int = get_param_value("mode")
	var ch_name: String = get_param_value("channel")

	var out := _create_volume_cpu(res, 1, "density")

	match mode:
		0:  # slice
			var slice_size: int = res.x * res.y
			for zi in range(mini(names.size(), res.z)):
				var samples: PackedFloat32Array = chop.get_channel(names[zi])
				for i in range(mini(samples.size(), slice_size)):
					out.cpu_data[zi * slice_size + i] = samples[i]
		1:  # stack
			var target: String = ch_name if ch_name != "" else names[0]
			var samples: PackedFloat32Array = chop.get_channel(target)
			if samples.is_empty():
				return null
			var slice_size: int = res.x * res.y
			for zi in range(res.z):
				for i in range(mini(samples.size(), slice_size)):
					out.cpu_data[zi * slice_size + i] = samples[i]
		2:  # map
			var tx: PackedFloat32Array = chop.get_channel("tx")
			var ty: PackedFloat32Array = chop.get_channel("ty")
			var tz: PackedFloat32Array = chop.get_channel("tz")
			var target: String = ch_name if ch_name != "" else "val"
			var vals: PackedFloat32Array = chop.get_channel(target)
			if tx.is_empty() or ty.is_empty() or tz.is_empty():
				return null
			var count: int = mini(mini(tx.size(), ty.size()), mini(tz.size(), vals.size()))
			for i in range(count):
				var gx: int = clampi(int(tx[i] * float(res.x)), 0, res.x - 1)
				var gy: int = clampi(int(ty[i] * float(res.y)), 0, res.y - 1)
				var gz: int = clampi(int(tz[i] * float(res.z)), 0, res.z - 1)
				out.cpu_data[gz * res.y * res.x + gy * res.x + gx] += vals[i]

	return out
