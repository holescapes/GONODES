class_name EnvelopeCHOP
extends GNChopBase
## Envelope follower for CHOP channels — computes RMS or peak amplitude
## over a sliding window.  Useful for audio-reactive visuals.

var _ring: Dictionary = {}   # channel -> PackedFloat32Array ring buffer
var _ring_idx: Dictionary = {}  # channel -> int write index
var _peak_val: Dictionary = {}  # channel -> float (for peak hold/decay)


func _init() -> void:
	node_type = "envelope"
	time_dependent = true
	node_description = "RMS / peak envelope follower for channels."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels")
	add_output("out", GNFamily.Type.CHOP, "Envelope")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["RMS", "Peak", "Average (abs)"]), 0, "",
		"Envelope detection mode"))
	add_parameter(GNParameter.create_int("window", 16, 1, 1024, "Window Size",
		"Sliding window length (samples/frames)"))
	add_parameter(GNParameter.create_float("decay", 0.95, 0.0, 1.0, 0.01,
		"Peak Decay", "For Peak mode — how fast the peak decays (0=instant, 1=hold)"))
	add_parameter(GNParameter.create_bool("reset", false, "", "Clear envelope state"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var mode: int = get_param_value("mode")
	var win_size: int = maxi(get_param_value("window"), 1)
	var decay: float = get_param_value("decay")
	var do_reset: bool = get_param_value("reset")

	if do_reset:
		_ring.clear(); _ring_idx.clear(); _peak_val.clear()

	var out: GNChannelData = _prepare_output(in_data.sample_rate)

	for ch_name in in_data.channels:
		var samples: PackedFloat32Array = in_data.channels[ch_name]
		if samples.is_empty():
			continue

		var value: float = samples[samples.size() - 1]

		if mode == 1:
			# Peak with decay
			var prev_peak: float = _peak_val.get(ch_name, 0.0)
			var abs_val: float = absf(value)
			var peak: float = maxf(abs_val, prev_peak * decay)
			_peak_val[ch_name] = peak
			out.set_single_value(ch_name, peak)
		else:
			# RMS or Average — use ring buffer
			if not _ring.has(ch_name) or _ring[ch_name].size() != win_size:
				var buf := PackedFloat32Array()
				buf.resize(win_size)
				buf.fill(0.0)
				_ring[ch_name] = buf
				_ring_idx[ch_name] = 0

			var buf: PackedFloat32Array = _ring[ch_name]
			var idx: int = _ring_idx[ch_name] % win_size
			buf[idx] = value
			_ring[ch_name] = buf
			_ring_idx[ch_name] = idx + 1

			var result: float = 0.0
			if mode == 0:
				# RMS
				var sum_sq: float = 0.0
				for s in buf:
					sum_sq += s * s
				result = sqrt(sum_sq / win_size)
			else:
				# Average absolute
				var sum_abs: float = 0.0
				for s in buf:
					sum_abs += absf(s)
				result = sum_abs / win_size

			out.set_single_value(ch_name, result)

	return out
