class_name FanCHOP
extends GNChopBase
## Takes a single-channel input and fans it out to multiple channels,
## each with an offset/spread applied.  Useful for creating multi-channel
## animation drives from a single source.


func _init() -> void:
	node_type = "fan"
	node_description = "Fan a single channel into multiple spread copies."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channel(s)")
	add_output("out", GNFamily.Type.CHOP, "Fanned channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("count", 4, 1, 64, "Count",
		"Number of output channels"))
	add_parameter(GNParameter.create_float("offset", 0.1, -100.0, 100.0, 0.01,
		"Offset", "Value offset between each copy"))
	add_parameter(GNParameter.create_enum("operation",
		PackedStringArray(["Add", "Multiply", "Phase Shift"]), 0, "",
		"How offset is applied per copy"))
	add_parameter(GNParameter.create_string("prefix", "ch",
		"Output channel name prefix", "Channel name prefix"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var count: int = maxi(get_param_value("count"), 1)
	var offset: float = get_param_value("offset")
	var op: int = get_param_value("operation")
	var prefix: String = get_param_value("prefix")

	var out: GNChannelData = _prepare_output(in_data.sample_rate)

	# Use first channel from input as source
	var src_name: String = ""
	var src_samples := PackedFloat32Array()
	for ch in in_data.channels:
		src_name = ch
		src_samples = in_data.channels[ch]
		break

	if src_samples.is_empty():
		return null

	for c in range(count):
		var ch_name: String = "%s%d" % [prefix, c]
		var dst := PackedFloat32Array()
		dst.resize(src_samples.size())
		var spread: float = offset * (c - (count - 1) * 0.5)

		for i in range(src_samples.size()):
			match op:
				0:  # Add
					dst[i] = src_samples[i] + spread
				1:  # Multiply
					dst[i] = src_samples[i] * (1.0 + spread)
				2:  # Phase Shift (useful for sine-like inputs)
					# Shift sample position
					var shift: int = roundi(spread * src_samples.size())
					var src_idx: int = ((i + shift) % src_samples.size() + src_samples.size()) % src_samples.size()
					dst[i] = src_samples[src_idx]

		out.set_channel(ch_name, dst)

	return out
