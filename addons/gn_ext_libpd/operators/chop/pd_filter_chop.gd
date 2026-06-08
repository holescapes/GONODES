class_name PdFilterCHOP
extends GNChopBase
## Process audio through a Pure Data patch as an effect/filter.
## Input audio is sent to Pd [adc~], processed, and returned from [dac~].

var _engine: GNPdEngine = null
var _patch_loaded: bool = false
var _last_patch: String = ""


func _init() -> void:
	node_type = "pdfilter"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Audio input to process through Pd patch", "In")
	add_output("out", GNFamily.Type.CHOP, "Processed audio output from Pd patch", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("patch", "The patch string",
		"Patch", "Path to Pure Data (.pd) effect patch"))
	add_parameter(GNParameter.create_float("param1", 0.0, -1000.0, 1000.0, 0.01,
		"Param 1", "Send to 'param1' receiver in Pd"))
	add_parameter(GNParameter.create_float("param2", 0.0, -1000.0, 1000.0, 0.01,
		"Param 2", "Send to 'param2' receiver in Pd"))
	add_parameter(GNParameter.create_float("param3", 0.0, -1000.0, 1000.0, 0.01,
		"Param 3", "Send to 'param3' receiver in Pd"))
	add_parameter(GNParameter.create_float("wet", 1.0, 0.0, 1.0, 0.01,
		"Wet", "Wet/dry mix (1 = fully processed)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var input_chop := _get_input_chop(inputs, 0)
	if not input_chop:
		return null

	if not _engine:
		_engine = GNPdEngine.new()
		_engine.init_audio(input_chop.sample_rate, 2, 2)

	if not _engine.is_available():
		return null

	var patch_path: String = get_param_value("patch")
	if patch_path != _last_patch:
		if _last_patch != "":
			_engine.close_patch(_last_patch)
		if patch_path != "":
			_engine.open_patch(patch_path)
		_last_patch = patch_path
		_patch_loaded = patch_path != ""

	if not _patch_loaded:
		return input_chop

	# Send parameters to Pd
	_engine.send_float("param1", get_param_value("param1"))
	_engine.send_float("param2", get_param_value("param2"))
	_engine.send_float("param3", get_param_value("param3"))

	var left: PackedFloat32Array = input_chop.channels.get("left", PackedFloat32Array())
	var right: PackedFloat32Array = input_chop.channels.get("right", left)
	var frames: int = left.size()

	# Interleave input for Pd
	var interleaved := PackedFloat32Array()
	interleaved.resize(frames * 2)
	for i in range(frames):
		interleaved[i * 2] = left[i]
		interleaved[i * 2 + 1] = right[i] if i < right.size() else left[i]

	var block_size: int = _engine.get_block_size()
	var ticks: int = maxi(1, frames / block_size)

	var output: PackedFloat32Array = _engine.process_audio(interleaved, ticks)

	var wet: float = get_param_value("wet")
	var dry: float = 1.0 - wet

	var out := _prepare_output(input_chop.sample_rate)
	var out_l := PackedFloat32Array()
	var out_r := PackedFloat32Array()
	out_l.resize(frames)
	out_r.resize(frames)
	for i in range(frames):
		var proc_l: float = output[i * 2] if i * 2 < output.size() else 0.0
		var proc_r: float = output[i * 2 + 1] if i * 2 + 1 < output.size() else 0.0
		out_l[i] = left[i] * dry + proc_l * wet
		out_r[i] = (right[i] if i < right.size() else left[i]) * dry + proc_r * wet

	out.channels["left"] = out_l
	out.channels["right"] = out_r
	out.length = frames
	return out
