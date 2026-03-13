class_name PatternCHOPNative
extends GNChopBase
## Native-accelerated pattern generator — delegates to GNNativePatternChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "pattern"
	node_description = "Generate multi-sample patterns — native C++ accelerated."
	if ClassDB.class_exists("GNNativePatternChop"):
		_processor = ClassDB.instantiate("GNNativePatternChop")


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Pattern data")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("type",
		PackedStringArray(["Ramp", "Sine", "Cosine", "Step", "Random", "Constant"]), 0, "", "Pattern shape"))
	add_parameter(GNParameter.create_int("length", 100, 1, 16384, "Sample Count", ""))
	add_parameter(GNParameter.create_int("channels", 1, 1, 16, "", "Number of channels"))
	add_parameter(GNParameter.create_float("from_value", 0.0, null, null, 0.01, "From", "Start value"))
	add_parameter(GNParameter.create_float("to_value", 1.0, null, null, 0.01, "To", "End value"))
	add_parameter(GNParameter.create_float("cycles", 1.0, 0.001, null, 0.01, "", "Pattern repetitions"))
	add_parameter(GNParameter.create_int("seed", 0, 0, 99999, "", "Random seed"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var pattern_type: int = get_param_value("type")
	var samp_len: int = get_param_value("length")
	var num_ch: int = get_param_value("channels")
	var from_val: float = get_param_value("from_value")
	var to_val: float = get_param_value("to_value")
	var cycles: float = get_param_value("cycles")
	var seed_val: int = get_param_value("seed")

	if _processor != null:
		var out: GNChannelData = _prepare_output(60.0)
		for ch in range(num_ch):
			var ch_name: String = "chan%d" % (ch + 1)
			var samples: PackedFloat32Array = _processor.process(pattern_type, samp_len,
				from_val, to_val, seed_val + ch)
			# Apply cycles by remapping
			if cycles != 1.0 and samp_len > 1:
				var cycled := PackedFloat32Array()
				cycled.resize(samp_len)
				for i in range(samp_len):
					var t: float = fmod(float(i) / float(samp_len) * cycles, 1.0)
					var src_idx: float = t * float(samp_len - 1)
					var lo: int = int(src_idx)
					var hi: int = mini(lo + 1, samp_len - 1)
					var frac: float = src_idx - float(lo)
					cycled[i] = samples[lo] * (1.0 - frac) + samples[hi] * frac
				samples = cycled
			out.set_channel(ch_name, samples)
		return out
	else:
		return null
