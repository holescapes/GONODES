class_name ResampleCHOP
extends GNChopBase
## Resamples all channels to a new sample count or sample rate.
## Useful for matching sample lengths between different CHOPs before combining.


func _init() -> void:
	node_type = "resample"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels")
	add_output("out", GNFamily.Type.CHOP, "Resampled channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("method",
		PackedStringArray(["To Samples", "To Rate"]), 0, "",
		"Resample by sample count or target rate"))
	add_parameter(GNParameter.create_int("samples", 60, 1, 100000, "Samples",
		"Target number of samples"))
	add_parameter(GNParameter.create_float("rate", 60.0, 1.0, 48000.0, 1.0,
		"Rate (Hz)", "Target sample rate"))
	add_parameter(GNParameter.create_enum("quality",
		PackedStringArray(["Linear", "Cubic", "Nearest"]), 0, "",
		"Interpolation quality"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var method: int = get_param_value("method")
	var target_samples: int = maxi(get_param_value("samples"), 1)
	var target_rate: float = maxf(get_param_value("rate"), 1.0)
	var quality: int = get_param_value("quality")

	var new_rate: float = in_data.sample_rate
	if method == 1:
		new_rate = target_rate

	var out: GNChannelData = _prepare_output(new_rate)

	for ch_name in in_data.channels:
		var src: PackedFloat32Array = in_data.channels[ch_name]
		if src.is_empty():
			continue

		var new_len: int
		if method == 0:
			new_len = target_samples
		else:
			# Keep the same duration, adjust sample count to new rate
			var duration: float = float(src.size()) / maxf(in_data.sample_rate, 1.0)
			new_len = maxi(roundi(duration * target_rate), 1)

		var dst := PackedFloat32Array()
		dst.resize(new_len)

		for i in range(new_len):
			var t: float = float(i) / maxf(new_len - 1.0, 1.0) * maxf(src.size() - 1.0, 0.0)
			dst[i] = _interpolate_sample(src, t, quality)

		out.set_channel(ch_name, dst)

	return out


func _interpolate_sample(src: PackedFloat32Array, pos: float, quality: int) -> float:
	var n: int = src.size()
	if n == 0:
		return 0.0
	if n == 1:
		return src[0]

	match quality:
		2:  # Nearest
			return src[clampi(roundi(pos), 0, n - 1)]
		1:  # Cubic (Catmull-Rom)
			var i1: int = clampi(int(pos), 0, n - 1)
			var frac: float = pos - float(i1)
			var i0: int = clampi(i1 - 1, 0, n - 1)
			var i2: int = clampi(i1 + 1, 0, n - 1)
			var i3: int = clampi(i1 + 2, 0, n - 1)
			var t2: float = frac * frac
			var t3: float = t2 * frac
			return 0.5 * ((2.0 * src[i1]) + (-src[i0] + src[i2]) * frac + \
				(2.0 * src[i0] - 5.0 * src[i1] + 4.0 * src[i2] - src[i3]) * t2 + \
				(-src[i0] + 3.0 * src[i1] - 3.0 * src[i2] + src[i3]) * t3)
		_:  # Linear
			var lo: int = clampi(int(pos), 0, n - 1)
			var hi: int = clampi(lo + 1, 0, n - 1)
			return lerpf(src[lo], src[hi], pos - float(lo))
