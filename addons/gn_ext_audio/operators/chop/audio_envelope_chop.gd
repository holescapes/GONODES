class_name AudioEnvelopeCHOP
extends GNChopBase
## Amplitude envelope follower with configurable attack and release.
##
## Tracks the amplitude envelope of input audio using peak or RMS
## detection with smoothed attack/release time constants. Essential for
## sidechain compression, ducking, and audio-reactive visual control.
##
## Outputs one envelope channel per input channel, plus a combined
## "envelope" channel (max of all channels).

# Per-channel envelope state
var _env: Dictionary = {}


func _init() -> void:
	node_type = "audioenvelope"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Audio input to follow")
	add_output("out", GNFamily.Type.CHOP, "Envelope output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Peak", "RMS"]), 0,
		"Mode", "Detection mode — peak tracks instantaneous peaks, RMS tracks average power"))
	add_parameter(GNParameter.create_float("attack_ms", 5.0, 0.1, 500.0, 0.1,
		"Attack (ms)", "Attack time constant in milliseconds"))
	add_parameter(GNParameter.create_float("release_ms", 100.0, 1.0, 5000.0, 1.0,
		"Release (ms)", "Release time constant in milliseconds"))
	add_parameter(GNParameter.create_float("gain", 1.0, 0.0, 10.0, 0.01,
		"Gain", "Output gain multiplier"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var sr: float = in_data.sample_rate if in_data.sample_rate > 0.0 else AudioServer.get_mix_rate()
	var out := _prepare_output(sr)

	var mode: int = get_param_value("mode")
	var attack_ms: float = get_param_value("attack_ms")
	var release_ms: float = get_param_value("release_ms")
	var gain: float = get_param_value("gain")

	# RC time constants
	var attack_coeff: float = exp(-1.0 / maxf(sr * attack_ms * 0.001, 1.0))
	var release_coeff: float = exp(-1.0 / maxf(sr * release_ms * 0.001, 1.0))

	var max_env: float = 0.0

	for ch_name: String in in_data.get_channel_names():
		var samples: PackedFloat32Array = in_data.get_channel(ch_name)
		if samples.size() == 0:
			continue

		var env_val: float = _env.get(ch_name, 0.0)
		var env_out := PackedFloat32Array()
		env_out.resize(samples.size())

		if mode == 0:  # Peak
			for i: int in range(samples.size()):
				var input_level: float = absf(samples[i])
				if input_level > env_val:
					env_val = attack_coeff * env_val + (1.0 - attack_coeff) * input_level
				else:
					env_val = release_coeff * env_val + (1.0 - release_coeff) * input_level
				env_out[i] = env_val * gain
		else:  # RMS
			for i: int in range(samples.size()):
				var input_sq: float = samples[i] * samples[i]
				if input_sq > env_val * env_val:
					env_val = attack_coeff * env_val + (1.0 - attack_coeff) * sqrt(input_sq)
				else:
					env_val = release_coeff * env_val + (1.0 - release_coeff) * sqrt(input_sq)
				env_out[i] = env_val * gain

		_env[ch_name] = env_val
		max_env = maxf(max_env, env_val * gain)
		out.set_channel("env_" + ch_name, env_out)

	# Combined envelope (max of all channels) — single value for convenience
	out.set_single_value("envelope", max_env)
	return out
