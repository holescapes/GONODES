class_name BeatCHOP
extends GNChopBase
## Beat/onset detection for music-reactive visuals.
##
## Takes an audio CHOP input and outputs beat-sync channels:
##   beat    — 1.0 on beat frames, 0.0 otherwise (impulse)
##   energy  — current RMS energy (0..1 normalised)
##   onset   — onset envelope (decays after each beat)
##
## Algorithm: energy-based onset detection with adaptive threshold.
## Compares current frame's RMS energy against a running average.
## A beat is detected when energy exceeds average * sensitivity.

var _energy_history: PackedFloat32Array = PackedFloat32Array()
var _history_idx: int = 0
var _onset_env: float = 0.0
var _last_beat_time: float = 0.0


func _init() -> void:
	node_type = "beat"
	time_dependent = true
	node_description = "Beat/onset detection from audio CHOP input for music-reactive visuals."


func _init_ports() -> void:
	add_input("audio", GNFamily.Type.CHOP, false, "Audio CHOP (waveform channels)")
	add_output("out", GNFamily.Type.CHOP, "Beat channels (beat, energy, onset)")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("sensitivity", 1.5, 1.0, 5.0, 0.01,
		"Sensitivity", "Beat detection threshold multiplier over running average"))
	add_parameter(GNParameter.create_float("decay", 0.9, 0.5, 0.999, 0.001,
		"Onset Decay", "How quickly the onset envelope decays (higher = slower)"))
	add_parameter(GNParameter.create_int("history_size", 43, 10, 120,
		"History Size", "Number of frames for running average (~43 at 60fps ≈ 0.7s)"))
	add_parameter(GNParameter.create_float("min_interval", 0.15, 0.0, 1.0, 0.01,
		"Min Interval", "Minimum seconds between detected beats (de-bounce)"))
	add_parameter(GNParameter.create_float("bpm_default", 120.0, 30.0, 300.0, 0.1,
		"Default BPM", "Fallback BPM when no audio input is connected"))


func _cook(inputs: Array[GNData]) -> GNData:
	var sensitivity: float = get_param_value("sensitivity")
	var decay: float = get_param_value("decay")
	var hist_size: int = get_param_value("history_size")
	var min_interval: float = get_param_value("min_interval")
	var bpm_default: float = get_param_value("bpm_default")

	var out: GNChannelData = _prepare_output(60.0)

	# Ensure history buffer sized correctly
	if _energy_history.size() != hist_size:
		_energy_history.resize(hist_size)
		_energy_history.fill(0.0)
		_history_idx = 0

	# Compute current frame RMS energy from audio input
	var current_energy: float = 0.0
	var audio_in: GNChannelData = _get_input_chop(inputs, 0)
	if audio_in != null and audio_in.channels.size() > 0:
		var total: float = 0.0
		var count: int = 0
		for ch_name: String in audio_in.channels:
			var samples: PackedFloat32Array = audio_in.channels[ch_name]
			for s: float in samples:
				total += s * s
				count += 1
		if count > 0:
			current_energy = sqrt(total / float(count))
	else:
		# No audio input — generate synthetic beat from BPM
		var beat_interval: float = 60.0 / bpm_default
		var t: float = elapsed_time
		var phase: float = fmod(t, beat_interval)
		current_energy = 1.0 if phase < current_delta else 0.0

	# Store in circular history buffer
	_energy_history[_history_idx % hist_size] = current_energy
	_history_idx += 1

	# Compute running average energy
	var avg_energy: float = 0.0
	for e: float in _energy_history:
		avg_energy += e
	avg_energy /= float(hist_size)

	# Beat detection — energy spike above adaptive threshold
	var beat: float = 0.0
	var threshold: float = avg_energy * sensitivity
	if current_energy > threshold and current_energy > 0.01:
		# De-bounce: only fire if enough time has passed since last beat
		if elapsed_time - _last_beat_time >= min_interval:
			beat = 1.0
			_onset_env = 1.0
			_last_beat_time = elapsed_time

	# Decay onset envelope
	_onset_env *= decay

	# Output channels
	out.channels["beat"] = PackedFloat32Array([beat])
	out.channels["energy"] = PackedFloat32Array([current_energy])
	out.channels["onset"] = PackedFloat32Array([_onset_env])
	out.length = 1

	return out
