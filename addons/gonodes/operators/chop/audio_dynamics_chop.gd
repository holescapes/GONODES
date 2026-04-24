class_name AudioDynamicsCHOP
extends GNChopBase
## Dynamics processor: Compressor, Limiter, Expander, or Gate.
##
## An exponential attack/release envelope follower tracks instantaneous signal
## level; per-sample gain is computed and applied based on the selected mode.
##
## Threshold and makeup gain are in dBFS; attack/release in milliseconds.
## Designed for audio-rate CHOPs (44100 Hz) but works at any sample rate.

## Per-channel envelope follower state (linear magnitude).
var _env: Dictionary = {}


func _init() -> void:
	node_type = "audio_dynamics"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input audio channels")
	add_output("out", GNFamily.Type.CHOP, "Processed channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Compressor", "Limiter", "Expander", "Gate"]),
		0, "Mode", "Dynamics processor type"))
	add_parameter(GNParameter.create_float("threshold", -18.0, -60.0, 0.0, 0.5,
		"Threshold (dBFS)", "Level above (Compressor/Limiter) or below (Expander/Gate) which processing activates"))
	add_parameter(GNParameter.create_float("ratio", 4.0, 1.0, 20.0, 0.5,
		"Ratio", "Compression or expansion ratio (ignored by Limiter/Gate)"))
	add_parameter(GNParameter.create_float("attack", 10.0, 0.1, 500.0, 1.0,
		"Attack (ms)", "Gain reduction engage time"))
	add_parameter(GNParameter.create_float("release", 100.0, 1.0, 2000.0, 10.0,
		"Release (ms)", "Gain reduction disengage time"))
	add_parameter(GNParameter.create_float("makeup", 0.0, -20.0, 40.0, 0.5,
		"Makeup (dBFS)", "Output gain added after processing"))
	add_parameter(GNParameter.create_bool("reset", false, "Reset", "Clear envelope follower state"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var mode: int       = get_param_value("mode")
	var thr_db: float   = get_param_value("threshold")
	var ratio: float    = clampf(get_param_value("ratio"), 1.0, 100.0)
	var att_ms: float   = maxf(get_param_value("attack"), 0.1)
	var rel_ms: float   = maxf(get_param_value("release"), 1.0)
	var makeup_db: float = get_param_value("makeup")
	var do_reset: bool  = get_param_value("reset")

	if do_reset:
		_env.clear()

	var sr: float = maxf(in_data.sample_rate, 1.0)
	# RC-style exponential coefficients: c = exp(-1 / (sr * time_sec))
	var att_c: float    = exp(-1.0 / (sr * att_ms * 0.001))
	var rel_c: float    = exp(-1.0 / (sr * rel_ms * 0.001))
	var thr_lin: float  = _db_to_lin(thr_db)
	var makeup_lin: float = _db_to_lin(makeup_db)

	var out: GNChannelData = _prepare_output(sr)

	for ch_name: String in in_data.channels:
		var samples: PackedFloat32Array = in_data.channels[ch_name]
		var env_val: float = _env.get(ch_name, 0.0)
		var out_s := PackedFloat32Array()
		out_s.resize(samples.size())

		for i in range(samples.size()):
			var x: float   = samples[i]
			var lvl: float = abs(x)

			# Envelope follower — separate attack / release time constants.
			if lvl > env_val:
				env_val = att_c * env_val + (1.0 - att_c) * lvl
			else:
				env_val = rel_c * env_val + (1.0 - rel_c) * lvl

			var gain: float = 1.0
			match mode:
				0:  # Compressor — reduce gain above threshold.
					if env_val > thr_lin and env_val > 1e-7:
						var in_db: float  = _lin_to_db(env_val)
						var out_db: float = thr_db + (in_db - thr_db) / ratio
						gain = _db_to_lin(out_db - in_db)
				1:  # Limiter — hard ceiling; ratio → ∞.
					if env_val > thr_lin and env_val > 1e-7:
						gain = thr_lin / env_val
				2:  # Expander — increase gain reduction below threshold.
					if env_val < thr_lin and env_val > 1e-7:
						var in_db: float  = _lin_to_db(env_val)
						var out_db: float = thr_db + (in_db - thr_db) * ratio
						gain = _db_to_lin(out_db - in_db)
				3:  # Gate — silence below threshold.
					gain = 1.0 if env_val >= thr_lin else 0.0

			out_s[i] = x * gain * makeup_lin

		_env[ch_name] = env_val
		out.set_channel(ch_name, out_s)

	return out


# ─── dB helpers ───────────────────────────────────────────────────────────────

static func _db_to_lin(db: float) -> float:
	return pow(10.0, db / 20.0)

static func _lin_to_db(lin: float) -> float:
	if lin <= 1e-10:
		return -200.0
	return 20.0 * log(lin) / log(10.0)
