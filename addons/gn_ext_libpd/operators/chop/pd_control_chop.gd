class_name PdControlCHOP
extends GNChopBase
## Send/receive control messages to/from a Pure Data patch.
## Outputs received values as channels.

var _engine: GNPdEngine = null
var _patch_loaded: bool = false
var _last_patch: String = ""


func _init() -> void:
	node_type = "pdcontrol"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, true, "Control input (channel values sent to Pd receivers)")
	add_output("out", GNFamily.Type.CHOP, "Values received from Pd senders")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("patch", "",
		"Patch", "Path to Pure Data (.pd) control patch"))
	add_parameter(GNParameter.create_string("send_prefix", "",
		"Send Prefix", "Prefix for Pd receiver names (e.g., 'ctrl_' maps channel 'x' → 'ctrl_x')"))
	add_parameter(GNParameter.create_string("receive_names", "out1 out2 out3",
		"Receive Names", "Space-separated list of Pd sender names to listen for"))
	add_parameter(GNParameter.create_bool("send_bang", false,
		"Send Bang", "Send a bang to 'bang' receiver"))
	add_parameter(GNParameter.create_float("float_msg", 0.0, -10000.0, 10000.0, 0.01,
		"Float Message", "Send to 'float_in' receiver"))


func _cook(inputs: Array[GNData]) -> GNData:
	if not _engine:
		_engine = GNPdEngine.new()
		_engine.init_audio(44100.0, 0, 0)

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
		return null

	# Send input channels to Pd
	var input_chop := _get_input_chop(inputs, 0)
	var prefix: String = get_param_value("send_prefix")
	if input_chop:
		for ch_name in input_chop.channels:
			var arr: PackedFloat32Array = input_chop.channels[ch_name]
			if arr.size() > 0:
				_engine.send_float(prefix + ch_name, arr[arr.size() - 1])

	# Send parameter messages
	if get_param_value("send_bang"):
		_engine.send_bang("bang")
	_engine.send_float("float_in", get_param_value("float_msg"))

	# Process one tick to let Pd compute
	_engine.process_audio(PackedFloat32Array(), 1)

	# Read received values
	var receive_str: String = get_param_value("receive_names")
	var names: PackedStringArray = receive_str.split(" ", false)

	var out := _prepare_output(44100.0)
	for name in names:
		var val: float = _engine.get_received_value(name)
		out.channels[name] = PackedFloat32Array([val])
	out.length = 1

	return out
