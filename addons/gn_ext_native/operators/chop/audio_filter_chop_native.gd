class_name AudioFilterCHOPNative
extends GNChopBase
## Native-accelerated biquad filter — delegates to GNNativeAudioFilterChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "audiofilter_native"
	if ClassDB.class_exists("GNNativeAudioFilterChop"):
		_processor = ClassDB.instantiate("GNNativeAudioFilterChop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Audio input to filter", "In")
	add_output("out", GNFamily.Type.CHOP, "Filtered audio output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("type",
		PackedStringArray(["Lowpass", "Highpass", "Bandpass", "Notch", "Allpass",
			"Peaking", "Low Shelf", "High Shelf"]), 0,
		"Filter Type", "Biquad filter topology"))
	add_parameter(GNParameter.create_float("cutoff", 1000.0, 20.0, 20000.0, 1.0,
		"Cutoff", "Filter cutoff/center frequency in Hz"))
	add_parameter(GNParameter.create_float("q", 0.707, 0.1, 30.0, 0.01,
		"Q / Resonance", "Filter quality factor (resonance)"))
	add_parameter(GNParameter.create_float("gain_db", 0.0, -24.0, 24.0, 0.1,
		"Gain (dB)", "Gain for peaking and shelf filter types"))


func _cook(inputs: Array[GNData]) -> GNData:
	var input_chop := _get_input_chop(inputs, 0)
	if not input_chop:
		return null
	if not _processor:
		return null

	var type: int = get_param_value("type")
	var cutoff: float = get_param_value("cutoff")
	var q: float = get_param_value("q")
	var gain_db: float = get_param_value("gain_db")
	var sr: float = input_chop.sample_rate

	# Pack stereo into interleaved
	var left: PackedFloat32Array = input_chop.channels.get("left", PackedFloat32Array())
	var right: PackedFloat32Array = input_chop.channels.get("right", left)
	var frames: int = left.size()
	var interleaved := PackedFloat32Array()
	interleaved.resize(frames * 2)
	for i in range(frames):
		interleaved[i * 2] = left[i]
		interleaved[i * 2 + 1] = right[i] if i < right.size() else left[i]

	var result: PackedFloat32Array = _processor.process(interleaved, type, cutoff, q, gain_db, sr)

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
