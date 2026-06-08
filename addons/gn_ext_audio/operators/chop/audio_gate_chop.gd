class_name AudioGateCHOP
extends GNChopBase
## Noise gate with threshold, attack, hold, and release.
##
## Attenuates audio below a threshold level. Uses a sidechain-capable
## design: if a second input is connected, its level controls the gate
## instead of the main input's level.
##
## More specialized than AudioDynamicsCHOP's gate mode — provides hold time,
## hysteresis, and sidechain support.

var _gate_env: Dictionary = {}
var _hold_counter: Dictionary = {}


func _init() -> void:
	node_type = "audiogate"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Audio input to gate", "In")
	add_input("sidechain", GNFamily.Type.CHOP, true, "Sidechain input (controls gate from external source)", "Sidechain")
	add_output("out", GNFamily.Type.CHOP, "Gated audio output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("threshold_db", -40.0, -80.0, 0.0, 0.1,
		"Threshold (dB)", "Level below which the gate closes"))
	add_parameter(GNParameter.create_float("hysteresis_db", 3.0, 0.0, 12.0, 0.1,
		"Hysteresis (dB)", "Gap between open and close thresholds to prevent chatter"))
	add_parameter(GNParameter.create_float("attack_ms", 1.0, 0.01, 100.0, 0.1,
		"Attack (ms)", "Gate opening speed"))
	add_parameter(GNParameter.create_float("hold_ms", 50.0, 0.0, 2000.0, 1.0,
		"Hold (ms)", "Time gate stays open after signal drops below threshold"))
	add_parameter(GNParameter.create_float("release_ms", 50.0, 1.0, 2000.0, 1.0,
		"Release (ms)", "Gate closing speed"))
	add_parameter(GNParameter.create_float("range_db", -80.0, -80.0, 0.0, 0.1,
		"Range (dB)", "Minimum gain when gate is closed (-80 = full silence)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var sc_data: GNChannelData = _get_input_chop(inputs, 1)

	var sr: float = in_data.sample_rate if in_data.sample_rate > 0.0 else AudioServer.get_mix_rate()
	var out := _prepare_output(sr)

	var threshold_lin: float = _db_to_lin(get_param_value("threshold_db"))
	var hysteresis_lin: float = _db_to_lin(get_param_value("threshold_db") - get_param_value("hysteresis_db"))
	var attack_coeff: float = exp(-1.0 / maxf(sr * get_param_value("attack_ms") * 0.001, 1.0))
	var hold_samples: int = int(sr * get_param_value("hold_ms") * 0.001)
	var release_coeff: float = exp(-1.0 / maxf(sr * get_param_value("release_ms") * 0.001, 1.0))
	var range_lin: float = _db_to_lin(get_param_value("range_db"))

	for ch_name: String in in_data.get_channel_names():
		var samples: PackedFloat32Array = in_data.get_channel(ch_name)
		if samples.size() == 0:
			continue

		# Determine sidechain signal (external or self)
		var sc_samples: PackedFloat32Array = samples
		if sc_data != null:
			var sc_names: PackedStringArray = sc_data.get_channel_names()
			if sc_names.size() > 0:
				sc_samples = sc_data.get_channel(sc_names[0])

		var env: float = _gate_env.get(ch_name, 0.0)
		var hold_count: int = _hold_counter.get(ch_name, 0)
		var output := PackedFloat32Array()
		output.resize(samples.size())

		for i: int in range(samples.size()):
			var sc_level: float = absf(sc_samples[mini(i, sc_samples.size() - 1)])
			var target_gain: float

			if sc_level >= threshold_lin:
				# Gate open
				target_gain = 1.0
				hold_count = hold_samples
			elif hold_count > 0:
				# Hold phase
				target_gain = 1.0
				hold_count -= 1
			elif sc_level < hysteresis_lin:
				# Gate closed
				target_gain = range_lin
			else:
				# Between hysteresis and threshold — maintain current state
				target_gain = range_lin if env < 0.5 else 1.0

			# Smooth envelope
			if target_gain > env:
				env = (1.0 - attack_coeff) * target_gain + attack_coeff * env
			else:
				env = (1.0 - release_coeff) * target_gain + release_coeff * env

			output[i] = samples[i] * env

		_gate_env[ch_name] = env
		_hold_counter[ch_name] = hold_count
		out.set_channel(ch_name, output)

	return out


static func _db_to_lin(db: float) -> float:
	if db <= -80.0:
		return 0.0
	return pow(10.0, db / 20.0)
