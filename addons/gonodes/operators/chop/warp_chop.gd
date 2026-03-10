class_name WarpCHOP
extends GNChopBase
## Time-warp / retime CHOP channel data.
##
## Remaps the time axis of input channels using a speed multiplier,
## offset, and optional second-input lookup curve.
##
## Input 0: channel data to warp
## Input 1 (optional): warp curve — a single-channel CHOP whose samples
##         define the time-remap (values are normalized 0..1 positions into input).

func _init() -> void:
	node_type = "warp"
	node_description = "Time-warp / retime channel data."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels to retime")
	add_input("warp", GNFamily.Type.CHOP, false, "Warp curve (optional, 0-1 remap)")
	add_output("out", GNFamily.Type.CHOP, "Warped channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("speed", 1.0, -10.0, 10.0, 0.01,
		"Speed", "Time speed multiplier (negative = reverse)"))
	add_parameter(GNParameter.create_float("offset", 0.0, -1000.0, 1000.0, 0.01,
		"Offset", "Time offset in samples"))
	add_parameter(GNParameter.create_int("output_length", 0, 0, 100000,
		"Output Length", "Output sample count (0 = match input)"))
	add_parameter(GNParameter.create_enum("interpolation",
		PackedStringArray(["Linear", "Nearest"]), 0, "", "Sample interpolation mode"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_chop: GNChannelData = _get_input_chop(inputs, 0)
	if in_chop == null:
		return null

	var speed: float = get_param_value("speed")
	var offset_val: float = get_param_value("offset")
	var out_len: int = get_param_value("output_length")
	var interp_mode: int = get_param_value("interpolation")

	var warp_chop: GNChannelData = _get_input_chop(inputs, 1)

	# Determine output length
	var src_len: int = in_chop.length
	if src_len <= 0:
		# Compute from first channel
		for ch_name: String in in_chop.channels:
			src_len = maxi(src_len, in_chop.channels[ch_name].size())

	var dst_len: int = out_len if out_len > 0 else src_len
	if dst_len <= 0:
		return null

	var output: GNChannelData = _prepare_output(in_chop.sample_rate)

	# Get warp samples if provided
	var warp_samples: PackedFloat32Array = PackedFloat32Array()
	if warp_chop != null:
		for ch_name: String in warp_chop.channels:
			warp_samples = warp_chop.channels[ch_name]
			break  # Use first channel

	for ch_name: String in in_chop.channels:
		var src: PackedFloat32Array = in_chop.channels[ch_name]
		if src.is_empty():
			output.channels[ch_name] = PackedFloat32Array()
			continue

		var dst := PackedFloat32Array()
		dst.resize(dst_len)

		for i in range(dst_len):
			var t: float
			if warp_samples.size() > 0:
				# Warp curve lookup — sample index maps to normalized position
				var warp_idx: int = mini(i, warp_samples.size() - 1)
				t = warp_samples[warp_idx] * float(src.size() - 1)
			else:
				t = float(i) * speed + offset_val

			# Clamp to source range
			t = clampf(t, 0.0, float(src.size() - 1))

			if interp_mode == 1:
				# Nearest
				dst[i] = src[clampi(roundi(t), 0, src.size() - 1)]
			else:
				# Linear interpolation
				var lo: int = clampi(int(t), 0, src.size() - 1)
				var hi: int = clampi(lo + 1, 0, src.size() - 1)
				var frac: float = t - float(lo)
				dst[i] = src[lo] * (1.0 - frac) + src[hi] * frac

		output.channels[ch_name] = dst

	output.length = dst_len
	return output
