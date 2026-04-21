class_name AudioDelayCHOPNative
extends GNChopBase
## Native-accelerated audio delay — delegates to GNNativeAudioDelayChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "audiodelay"
	if ClassDB.class_exists("GNNativeAudioDelayChop"):
		_processor = ClassDB.instantiate("GNNativeAudioDelayChop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Audio input")
	add_output("out", GNFamily.Type.CHOP, "Delayed audio output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("delay_ms", 250.0, 0.1, 5000.0, 0.1,
		"Delay (ms)", "Delay time in milliseconds"))
	add_parameter(GNParameter.create_float("feedback", 0.4, 0.0, 0.95, 0.01,
		"Feedback", "Feedback amount (0-0.95, clamped for stability)"))
	add_parameter(GNParameter.create_float("wet", 0.5, 0.0, 1.0, 0.01,
		"Wet", "Wet (delayed) signal level"))
	add_parameter(GNParameter.create_float("dry", 1.0, 0.0, 1.0, 0.01,
		"Dry", "Dry (original) signal level"))
	add_parameter(GNParameter.create_bool("ping_pong", false,
		"Ping Pong", "Alternate delay between left and right channels"))
	add_parameter(GNParameter.create_bool("clear", false,
		"Clear", "Clear the delay buffer"))


func _cook(inputs: Array[GNData]) -> GNData:
	var input_chop := _get_input_chop(inputs, 0)
	if not input_chop:
		return null
	if not _processor:
		return null

	var delay_ms: float = get_param_value("delay_ms")
	var feedback_val: float = get_param_value("feedback")
	var wet: float = get_param_value("wet")
	var dry: float = get_param_value("dry")
	var do_clear: bool = get_param_value("clear")
	var sr: float = input_chop.sample_rate

	if do_clear:
		_processor.reset()

	var delay_time: float = delay_ms / 1000.0
	var max_delay: float = 5.0

	var left: PackedFloat32Array = input_chop.channels.get("left", PackedFloat32Array())
	var right: PackedFloat32Array = input_chop.channels.get("right", left)
	var frames: int = left.size()
	var interleaved := PackedFloat32Array()
	interleaved.resize(frames * 2)
	for i in range(frames):
		interleaved[i * 2] = left[i]
		interleaved[i * 2 + 1] = right[i] if i < right.size() else left[i]

	var result: PackedFloat32Array = _processor.process(interleaved, delay_time, feedback_val,
		wet, dry, max_delay, sr)

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
