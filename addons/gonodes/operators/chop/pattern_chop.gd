class_name PatternCHOP
extends GNNode
## Generates multi-sample patterns (ramp, sine, step, random) as CHOP data.
## Useful for creating lookup tables or animation curves.
## Similar to TouchDesigner's Pattern CHOP.

enum PatternType { RAMP, SINE, COSINE, STEP, RANDOM, CONSTANT }

var _cached_channel_data: GNChannelData = null


func _init() -> void:
	node_type = "pattern"
	family = GNFamily.Type.CHOP


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP)


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("type",
		PackedStringArray(["Ramp", "Sine", "Cosine", "Step", "Random", "Constant"]), 0))
	add_parameter(GNParameter.create_int("length", 100, 1, 16384, "Sample Count"))
	add_parameter(GNParameter.create_int("channels", 1, 1, 16))
	add_parameter(GNParameter.create_float("from_value", 0.0, null, null, 0.01, "From"))
	add_parameter(GNParameter.create_float("to_value", 1.0, null, null, 0.01, "To"))
	add_parameter(GNParameter.create_float("cycles", 1.0, 0.001, null, 0.01))
	add_parameter(GNParameter.create_int("seed", 0, 0, 99999))


func _cook(_inputs: Array[GNData]) -> GNData:
	var pat_type: int = get_param_value("type")
	var samp_count: int = get_param_value("length")
	var num_ch: int = get_param_value("channels")
	var from_val: float = get_param_value("from_value")
	var to_val: float = get_param_value("to_value")
	var cycles: float = get_param_value("cycles")
	var seed_val: int = get_param_value("seed")

	if _cached_channel_data == null:
		_cached_channel_data = GNChannelData.new()
	else:
		_cached_channel_data.channels.clear()
		_cached_channel_data.length = 0
	_cached_channel_data.sample_rate = 60.0

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	for ch in range(num_ch):
		var ch_name: String = "chan%d" % (ch + 1)
		var samples := PackedFloat32Array()
		samples.resize(samp_count)

		for i in range(samp_count):
			var t: float = float(i) / float(maxi(samp_count - 1, 1))

			match pat_type:
				PatternType.RAMP:
					samples[i] = lerpf(from_val, to_val, t)
				PatternType.SINE:
					var phase: float = t * cycles * TAU
					var norm: float = (sin(phase) + 1.0) * 0.5
					samples[i] = lerpf(from_val, to_val, norm)
				PatternType.COSINE:
					var phase: float = t * cycles * TAU
					var norm: float = (cos(phase) + 1.0) * 0.5
					samples[i] = lerpf(from_val, to_val, norm)
				PatternType.STEP:
					samples[i] = to_val if t >= 0.5 else from_val
				PatternType.RANDOM:
					rng.seed = seed_val + i * 31 + ch * 997
					samples[i] = lerpf(from_val, to_val, rng.randf())
				PatternType.CONSTANT:
					samples[i] = from_val

		_cached_channel_data.set_channel(ch_name, samples)

	return _cached_channel_data
