class_name LimitCHOP
extends GNChopBase
## Clamps, loops, or zig-zags channel values within min/max bounds.
## Similar to TouchDesigner's Limit CHOP.

enum LimitType { CLAMP, LOOP, ZIGZAG }


func _init() -> void:
	node_type = "limit"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels")
	add_output("out", GNFamily.Type.CHOP, "Limited channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("type",
		PackedStringArray(["Clamp", "Loop", "Zig-Zag"]), 0, "", "Limit mode"))
	add_parameter(GNParameter.create_float("min", 0.0, null, null, 0.01, "Min", "Lower bound"))
	add_parameter(GNParameter.create_float("max", 1.0, null, null, 0.01, "Max", "Upper bound"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = inputs[0] as GNChannelData if inputs.size() > 0 and inputs[0] is GNChannelData else null
	if in_data == null:
		GNLogger.warn("LimitCHOP", "'%s' — no valid input" % id)
		return null

	var limit_type: int = get_param_value("type")
	var lo: float = get_param_value("min")
	var hi: float = get_param_value("max")

	if _cached_channel_data == null:
		_cached_channel_data = GNChannelData.new()
	else:
		_cached_channel_data.channels.clear()
		_cached_channel_data.length = 0
	_cached_channel_data.sample_rate = in_data.sample_rate

	var range_size: float = hi - lo
	if range_size <= 0.0:
		range_size = 1.0  # Guard against zero range

	for ch_name in in_data.channels:
		var samples: PackedFloat32Array = in_data.channels[ch_name]
		var out_samples := PackedFloat32Array()
		out_samples.resize(samples.size())

		for i in range(samples.size()):
			out_samples[i] = _apply_limit(limit_type, samples[i], lo, hi, range_size)

		_cached_channel_data.set_channel(ch_name, out_samples)

	return _cached_channel_data


func _apply_limit(limit_type: int, value: float, lo: float, hi: float,
		range_size: float) -> float:
	match limit_type:
		LimitType.CLAMP:
			return clampf(value, lo, hi)
		LimitType.LOOP:
			if value < lo or value > hi:
				var normalized: float = fmod(value - lo, range_size)
				if normalized < 0.0:
					normalized += range_size
				return lo + normalized
			return value
		LimitType.ZIGZAG:
			var normalized: float = (value - lo) / range_size
			var floored: int = int(floorf(normalized))
			var frac: float = normalized - floored
			if floored % 2 != 0:
				frac = 1.0 - frac
			return lo + frac * range_size
		_:
			return value
