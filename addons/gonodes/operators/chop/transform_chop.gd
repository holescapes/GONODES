class_name TransformCHOP
extends GNChopBase
## Applies 3D transform operations (translate, rotate, scale) to xyz channel
## groups. Expects channels named tx/ty/tz (or x/y/z) and outputs transformed
## values. Similar to TouchDesigner's Transform CHOP.

func _init() -> void:
	node_type = "transform"
	node_description = "3D transform on xyz channel groups."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels with xyz groups")
	add_output("out", GNFamily.Type.CHOP, "Transformed channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("tx", 0.0, null, null, 0.01, "Translate X", ""))
	add_parameter(GNParameter.create_float("ty", 0.0, null, null, 0.01, "Translate Y", ""))
	add_parameter(GNParameter.create_float("tz", 0.0, null, null, 0.01, "Translate Z", ""))
	add_parameter(GNParameter.create_float("rx", 0.0, -360.0, 360.0, 0.1, "Rotate X", "Degrees"))
	add_parameter(GNParameter.create_float("ry", 0.0, -360.0, 360.0, 0.1, "Rotate Y", "Degrees"))
	add_parameter(GNParameter.create_float("rz", 0.0, -360.0, 360.0, 0.1, "Rotate Z", "Degrees"))
	add_parameter(GNParameter.create_float("sx", 1.0, 0.001, 100.0, 0.01, "Scale X", ""))
	add_parameter(GNParameter.create_float("sy", 1.0, 0.001, 100.0, 0.01, "Scale Y", ""))
	add_parameter(GNParameter.create_float("sz", 1.0, 0.001, 100.0, 0.01, "Scale Z", ""))
	add_parameter(GNParameter.create_enum("order",
		PackedStringArray(["SRT", "STR", "RST", "RTS", "TSR", "TRS"]),
		0, "Transform Order", "Order of transform operations"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = inputs[0] as GNChannelData if inputs.size() > 0 and inputs[0] is GNChannelData else null
	if in_data == null:
		return null

	var t := Vector3(get_param_value("tx"), get_param_value("ty"), get_param_value("tz"))
	var r := Vector3(deg_to_rad(get_param_value("rx")),
		deg_to_rad(get_param_value("ry")),
		deg_to_rad(get_param_value("rz")))
	var s := Vector3(get_param_value("sx"), get_param_value("sy"), get_param_value("sz"))
	var order_idx: int = get_param_value("order")

	# Build transform matrix
	var xform := _build_transform(t, r, s, order_idx)

	if _cached_channel_data == null:
		_cached_channel_data = GNChannelData.new()
	else:
		_cached_channel_data.channels.clear()
		_cached_channel_data.length = 0
	_cached_channel_data.sample_rate = in_data.sample_rate

	# Identify xyz channel groups
	var groups := _find_xyz_groups(in_data)

	# Transform each group
	for group in groups:
		var x_ch: String = group[0]
		var y_ch: String = group[1]
		var z_ch: String = group[2]

		var x_samples: PackedFloat32Array = in_data.channels.get(x_ch, PackedFloat32Array())
		var y_samples: PackedFloat32Array = in_data.channels.get(y_ch, PackedFloat32Array())
		var z_samples: PackedFloat32Array = in_data.channels.get(z_ch, PackedFloat32Array())
		var num_samples: int = maxi(maxi(x_samples.size(), y_samples.size()), z_samples.size())

		var ox := PackedFloat32Array()
		var oy := PackedFloat32Array()
		var oz := PackedFloat32Array()
		ox.resize(num_samples)
		oy.resize(num_samples)
		oz.resize(num_samples)

		for i in range(num_samples):
			var vx: float = x_samples[i] if i < x_samples.size() else 0.0
			var vy: float = y_samples[i] if i < y_samples.size() else 0.0
			var vz: float = z_samples[i] if i < z_samples.size() else 0.0
			var transformed: Vector3 = xform * Vector3(vx, vy, vz)
			ox[i] = transformed.x
			oy[i] = transformed.y
			oz[i] = transformed.z

		_cached_channel_data.set_channel(x_ch, ox)
		_cached_channel_data.set_channel(y_ch, oy)
		_cached_channel_data.set_channel(z_ch, oz)

	# Pass through any non-grouped channels unchanged
	var grouped_names: Dictionary = {}
	for group in groups:
		for ch in group:
			grouped_names[ch] = true
	for ch_name in in_data.channels:
		if not grouped_names.has(ch_name):
			_cached_channel_data.set_channel(ch_name, in_data.channels[ch_name])

	return _cached_channel_data


func _find_xyz_groups(data: GNChannelData) -> Array:
	var groups: Array = []
	var used: Dictionary = {}

	# Check for tx/ty/tz pattern
	for ch_name in data.channels:
		if used.has(ch_name):
			continue
		var prefix: String = ch_name.substr(0, ch_name.length() - 1)
		var suffix: String = ch_name.substr(ch_name.length() - 1)
		if suffix == "x":
			var y_name: String = prefix + "y"
			var z_name: String = prefix + "z"
			if data.channels.has(y_name) and data.channels.has(z_name):
				groups.append([ch_name, y_name, z_name])
				used[ch_name] = true
				used[y_name] = true
				used[z_name] = true

	# Check for x/y/z standalone
	if groups.is_empty() and data.channels.has("x") and data.channels.has("y") and data.channels.has("z"):
		groups.append(["x", "y", "z"])

	return groups


func _build_transform(t: Vector3, r: Vector3, s: Vector3, order: int) -> Transform3D:
	var basis_t := Transform3D(Basis.IDENTITY, t)
	var basis_r := Transform3D(Basis.from_euler(r), Vector3.ZERO)
	var basis_s := Transform3D(Basis.from_scale(s), Vector3.ZERO)

	match order:
		0: return basis_s * basis_r * basis_t  # SRT
		1: return basis_s * basis_t * basis_r  # STR
		2: return basis_r * basis_s * basis_t  # RST
		3: return basis_r * basis_t * basis_s  # RTS
		4: return basis_t * basis_s * basis_r  # TSR
		5: return basis_t * basis_r * basis_s  # TRS
		_: return basis_s * basis_r * basis_t
