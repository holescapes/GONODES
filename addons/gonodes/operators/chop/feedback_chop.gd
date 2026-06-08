class_name FeedbackCHOP
extends GNChopBase
## Outputs the previous frame's channel data, enabling temporal feedback loops.
## On the first frame or when reset, outputs zeros.

var _prev_data: GNChannelData = null


func _init() -> void:
	node_type = "feedback"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Current frame input", "In")
	add_output("out", GNFamily.Type.CHOP, "Previous frame's data", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("reset", false, "Reset",
		"Pulse to clear stored data"))


func _cook(inputs: Array[GNData]) -> GNData:
	var do_reset: bool = get_param_value("reset")
	if do_reset:
		_prev_data = null

	# Output whatever we stored last frame
	var output: GNChannelData = _prev_data

	# Store the current input for next frame
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data != null:
		_prev_data = GNChannelData.new()
		_prev_data.sample_rate = in_data.sample_rate
		for ch_name in in_data.channels:
			_prev_data.set_channel(ch_name, in_data.channels[ch_name].duplicate())

	if output == null:
		return null

	return output
