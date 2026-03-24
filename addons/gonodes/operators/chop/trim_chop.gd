class_name TrimCHOP
extends GNChopBase
## Extracts a sub-range of samples from each channel.
## Modes: by sample index range, by normalised fraction, or relative to end.


func _init() -> void:
	node_type = "trim"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels")
	add_output("out", GNFamily.Type.CHOP, "Trimmed channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("unit",
		PackedStringArray(["Samples", "Fraction (0-1)", "From End"]), 0, "",
		"How start/end values are interpreted"))
	add_parameter(GNParameter.create_float("start", 0.0, 0.0, 100000.0, 1.0,
		"Start", "Start position (samples, fraction, or offset from end)"))
	add_parameter(GNParameter.create_float("end", 1.0, 0.0, 100000.0, 1.0,
		"End", "End position"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var unit: int = get_param_value("unit")
	var start_val: float = get_param_value("start")
	var end_val: float = get_param_value("end")

	var out: GNChannelData = _prepare_output(in_data.sample_rate)

	for ch_name in in_data.channels:
		var src: PackedFloat32Array = in_data.channels[ch_name]
		if src.is_empty():
			continue

		var n: int = src.size()
		var si: int
		var ei: int

		match unit:
			0:  # Samples (absolute index)
				si = clampi(int(start_val), 0, n - 1)
				ei = clampi(int(end_val), si, n - 1)
			1:  # Fraction 0-1
				si = clampi(int(start_val * (n - 1)), 0, n - 1)
				ei = clampi(int(end_val * (n - 1)), si, n - 1)
			_:  # From End
				si = clampi(n - 1 - int(end_val), 0, n - 1)
				ei = clampi(n - 1 - int(start_val), si, n - 1)

		var result := PackedFloat32Array()
		var count: int = ei - si + 1
		result.resize(count)
		for i in range(count):
			result[i] = src[si + i]

		out.set_channel(ch_name, result)

	return out
