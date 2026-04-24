class_name TransformCHOPNative
extends GNChopBase
## Native-accelerated TRS transform on xyz channel groups — delegates to GNNativeTransformChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "transform_native"
	if ClassDB.class_exists("GNNativeTransformChop"):
		_processor = ClassDB.instantiate("GNNativeTransformChop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels with xyz groups")
	add_output("out", GNFamily.Type.CHOP, "Transformed channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("tx", 0.0, null, null, 0.01, "Translate X", ""))
	add_parameter(GNParameter.create_float("ty", 0.0, null, null, 0.01, "Translate Y", ""))
	add_parameter(GNParameter.create_float("tz", 0.0, null, null, 0.01, "Translate Z", ""))
	add_parameter(GNParameter.create_float("rx", 0.0, null, null, 0.1, "Rotate X", "Degrees"))
	add_parameter(GNParameter.create_float("ry", 0.0, null, null, 0.1, "Rotate Y", "Degrees"))
	add_parameter(GNParameter.create_float("rz", 0.0, null, null, 0.1, "Rotate Z", "Degrees"))
	add_parameter(GNParameter.create_float("sx", 1.0, null, null, 0.01, "Scale X", ""))
	add_parameter(GNParameter.create_float("sy", 1.0, null, null, 0.01, "Scale Y", ""))
	add_parameter(GNParameter.create_float("sz", 1.0, null, null, 0.01, "Scale Z", ""))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data := _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var t_x: float = get_param_value("tx")
	var t_y: float = get_param_value("ty")
	var t_z: float = get_param_value("tz")
	var r_x: float = get_param_value("rx")
	var r_y: float = get_param_value("ry")
	var r_z: float = get_param_value("rz")
	var s_x: float = get_param_value("sx")
	var s_y: float = get_param_value("sy")
	var s_z: float = get_param_value("sz")

	var out := _prepare_output(in_data.sample_rate)

	# Find xyz groups and transform them
	var groups := _find_xyz_groups(in_data)
	var grouped: Dictionary = {}

	for group in groups:
		var x_s: PackedFloat32Array = in_data.channels.get(group[0], PackedFloat32Array())
		var y_s: PackedFloat32Array = in_data.channels.get(group[1], PackedFloat32Array())
		var z_s: PackedFloat32Array = in_data.channels.get(group[2], PackedFloat32Array())
		var n: int = maxi(maxi(x_s.size(), y_s.size()), z_s.size())

		if _processor != null and n > 0:
			# Pack into interleaved array for C++
			var packed := PackedFloat32Array()
			packed.resize(n * 3)
			for i in range(n):
				packed[i * 3] = x_s[i] if i < x_s.size() else 0.0
				packed[i * 3 + 1] = y_s[i] if i < y_s.size() else 0.0
				packed[i * 3 + 2] = z_s[i] if i < z_s.size() else 0.0
			var result: PackedFloat32Array = _processor.process(packed, n, t_x, t_y, t_z, r_x, r_y, r_z, s_x, s_y, s_z)
			var ox := PackedFloat32Array()
			var oy := PackedFloat32Array()
			var oz := PackedFloat32Array()
			ox.resize(n); oy.resize(n); oz.resize(n)
			for i in range(n):
				ox[i] = result[i * 3]
				oy[i] = result[i * 3 + 1]
				oz[i] = result[i * 3 + 2]
			out.channels[group[0]] = ox
			out.channels[group[1]] = oy
			out.channels[group[2]] = oz
		else:
			out.channels[group[0]] = x_s.duplicate()
			out.channels[group[1]] = y_s.duplicate()
			out.channels[group[2]] = z_s.duplicate()

		for ch in group:
			grouped[ch] = true

	# Pass through ungrouped channels
	for ch_name in in_data.channels:
		if not grouped.has(ch_name):
			out.channels[ch_name] = in_data.channels[ch_name]

	return out


func _find_xyz_groups(data: GNChannelData) -> Array:
	var groups: Array = []
	var used: Dictionary = {}
	for ch_name in data.channels:
		if used.has(ch_name):
			continue
		var prefix: String = ch_name.substr(0, ch_name.length() - 1)
		var suffix: String = ch_name.substr(ch_name.length() - 1)
		if suffix == "x":
			var y_n: String = prefix + "y"
			var z_n: String = prefix + "z"
			if data.channels.has(y_n) and data.channels.has(z_n):
				groups.append([ch_name, y_n, z_n])
				used[ch_name] = true
				used[y_n] = true
				used[z_n] = true
	if groups.is_empty() and data.channels.has("x") and data.channels.has("y") and data.channels.has("z"):
		groups.append(["x", "y", "z"])
	return groups
