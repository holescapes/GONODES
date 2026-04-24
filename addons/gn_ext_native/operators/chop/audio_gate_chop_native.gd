class_name AudioGateCHOPNative
extends GNChopBase
## Native-accelerated noise gate — delegates to GNNativeAudioGateChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "audiogate_native"
	if ClassDB.class_exists("GNNativeAudioGateChop"):
		_processor = ClassDB.instantiate("GNNativeAudioGateChop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Audio input to gate")
	add_input("sidechain", GNFamily.Type.CHOP, true, "Sidechain input (controls gate from external source)")
	add_output("out", GNFamily.Type.CHOP, "Gated audio output")


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
	var input_chop := _get_input_chop(inputs, 0)
	if not input_chop:
		return null
	if not _processor:
		return null

	var threshold_db: float = get_param_value("threshold_db")
	var attack_ms: float = get_param_value("attack_ms")
	var release_ms: float = get_param_value("release_ms")
	var range_db: float = get_param_value("range_db")
	var hold_ms: float = get_param_value("hold_ms")
	var sr: float = input_chop.sample_rate

	var left: PackedFloat32Array = input_chop.channels.get("left", PackedFloat32Array())
	var right: PackedFloat32Array = input_chop.channels.get("right", left)
	var frames: int = left.size()
	var interleaved := PackedFloat32Array()
	interleaved.resize(frames * 2)
	for i in range(frames):
		interleaved[i * 2] = left[i]
		interleaved[i * 2 + 1] = right[i] if i < right.size() else left[i]

	var result: PackedFloat32Array = _processor.process(interleaved, threshold_db,
		attack_ms / 1000.0, release_ms / 1000.0, range_db, hold_ms / 1000.0, sr)

	var out := _prepare_output(sr)
	var out_l := PackedFloat32Array()
	var out_r := PackedFloat32Array()
	out_l.resize(frames)
	out_r.resize(frames)
	for i in range(frames):
		out_l[i] = result[i * 2]
		out_r[i] = result[i * 2 + 1]
	out.channels["left"] = out_l
	out.channels["right"] = out_r
	out.length = frames
	return out
