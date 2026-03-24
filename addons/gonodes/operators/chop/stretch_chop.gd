class_name StretchCHOP
extends GNChopBase
## Stretches or compresses channels in time by resampling the sample array.
## Changes the number of samples without changing content — useful for
## time-warping patterns and animations.


func _init() -> void:
	node_type = "stretch"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels")
	add_output("out", GNFamily.Type.CHOP, "Stretched channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["By Factor", "To Length"]), 0, "",
		"Stretch by factor or to absolute sample count"))
	add_parameter(GNParameter.create_float("factor", 2.0, 0.01, 100.0, 0.01,
		"Factor", "Time stretch factor (2 = double length)"))
	add_parameter(GNParameter.create_int("length", 120, 1, 100000, "Length",
		"Target sample count (By Length mode)"))
	add_parameter(GNParameter.create_enum("interpolate",
		PackedStringArray(["Linear", "Cubic", "Nearest"]), 0, "",
		"Interpolation quality"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var mode: int = get_param_value("mode")
	var factor: float = maxf(get_param_value("factor"), 0.01)
	var target_len: int = maxi(get_param_value("length"), 1)
	var interp: int = get_param_value("interpolate")

	var out: GNChannelData = _prepare_output(in_data.sample_rate)

	for ch_name in in_data.channels:
		var src: PackedFloat32Array = in_data.channels[ch_name]
		if src.is_empty():
			continue

		var new_len: int
		if mode == 0:
			new_len = maxi(roundi(src.size() * factor), 1)
		else:
			new_len = target_len

		var dst := PackedFloat32Array()
		dst.resize(new_len)

		for i in range(new_len):
			var t: float = float(i) / maxf(new_len - 1.0, 1.0) * maxf(src.size() - 1.0, 0.0)
			dst[i] = _sample(src, t, interp)

		out.set_channel(ch_name, dst)

	return out


func _sample(src: PackedFloat32Array, pos: float, interp: int) -> float:
	var n: int = src.size()
	if n == 0:
		return 0.0
	if n == 1:
		return src[0]

	match interp:
		2:  # Nearest
			return src[clampi(roundi(pos), 0, n - 1)]
		1:  # Cubic (Catmull-Rom)
			var i1: int = clampi(int(pos), 0, n - 1)
			var frac: float = pos - float(i1)
			var i0: int = clampi(i1 - 1, 0, n - 1)
			var i2: int = clampi(i1 + 1, 0, n - 1)
			var i3: int = clampi(i1 + 2, 0, n - 1)
			var p0: float = src[i0]; var p1: float = src[i1]
			var p2: float = src[i2]; var p3: float = src[i3]
			return _catmull_rom(p0, p1, p2, p3, frac)
		_:  # Linear
			var lo: int = clampi(int(pos), 0, n - 1)
			var hi: int = clampi(lo + 1, 0, n - 1)
			return lerpf(src[lo], src[hi], pos - float(lo))


func _catmull_rom(p0: float, p1: float, p2: float, p3: float, t: float) -> float:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
