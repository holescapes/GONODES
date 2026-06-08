class_name ExtendCHOP
extends GNChopBase
## Extends or pads channel sample arrays with different fill modes:
## hold (repeat last), cycle, mirror, or slope continuation.


func _init() -> void:
	node_type = "extend"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels", "In")
	add_output("out", GNFamily.Type.CHOP, "Extended channels", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("left",
		PackedStringArray(["Hold", "Cycle", "Mirror", "Slope", "Zero"]), 0, "",
		"How to extend before the start"))
	add_parameter(GNParameter.create_enum("right",
		PackedStringArray(["Hold", "Cycle", "Mirror", "Slope", "Zero"]), 0, "",
		"How to extend after the end"))
	add_parameter(GNParameter.create_int("before", 0, 0, 10000, "Pad Before",
		"Number of samples to prepend"))
	add_parameter(GNParameter.create_int("after", 30, 0, 10000, "Pad After",
		"Number of samples to append"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var left_mode: int = get_param_value("left")
	var right_mode: int = get_param_value("right")
	var before: int = maxi(get_param_value("before"), 0)
	var after: int = maxi(get_param_value("after"), 0)

	var out: GNChannelData = _prepare_output(in_data.sample_rate)

	for ch_name in in_data.channels:
		var src: PackedFloat32Array = in_data.channels[ch_name]
		if src.is_empty():
			continue

		var n: int = src.size()
		var new_len: int = before + n + after
		var dst := PackedFloat32Array()
		dst.resize(new_len)

		# Compute per-sample slope for Slope mode
		var slope_left: float = 0.0
		var slope_right: float = 0.0
		if n >= 2:
			slope_left = src[0] - src[1]
			slope_right = src[n - 1] - src[n - 2]

		# Fill left extension
		for i in range(before):
			var offset: int = before - i  # distance from start (1-based)
			dst[i] = _extend_value(src, -offset, left_mode, slope_left, true)

		# Copy original data
		for i in range(n):
			dst[before + i] = src[i]

		# Fill right extension
		for i in range(after):
			var offset: int = i + 1  # distance past end (1-based)
			dst[before + n + i] = _extend_value(src, n - 1 + offset, right_mode, slope_right, false)

		out.set_channel(ch_name, dst)

	return out


func _extend_value(src: PackedFloat32Array, idx: int, mode: int,
		slope: float, is_left: bool) -> float:
	var n: int = src.size()
	if n == 0:
		return 0.0

	match mode:
		0:  # Hold
			return src[0] if is_left else src[n - 1]
		1:  # Cycle
			var wrapped: int = ((idx % n) + n) % n
			return src[wrapped]
		2:  # Mirror
			var period: int = maxi(n - 1, 1) * 2
			var m: int = ((idx % period) + period) % period
			return src[m if m < n else period - m]
		3:  # Slope
			if is_left:
				var dist: int = -idx
				return src[0] + slope * dist
			else:
				var dist: int = idx - (n - 1)
				return src[n - 1] + slope * dist
		4:  # Zero
			return 0.0
		_:
			return 0.0
