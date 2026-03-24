class_name HostOutCHOP
extends GNOutBase
## Exports channel data to the host application via the LibGodot C API.
##
## Takes a CHOP input and makes its channel data available to the host
## through gonodes_get_output_chop().  GNEmbeddedHost._collect_outputs()
## calls _get_host_channels() each frame to publish the data.

## Cached channel data for the host.
var _output_channels: Dictionary = {}


func _init() -> void:
	node_type = "host_out_chop"
	is_sink = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Channel data to export to host")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("label", "", "Label",
		"Optional label for this output in the host's UI"))


func _cook(inputs: Array[GNData]) -> GNData:
	var chop_in: GNChannelData = _get_input_chop(inputs, 0)

	_output_channels.clear()
	if chop_in == null:
		return null

	# Copy channel data for host consumption.
	for ch_name in chop_in.channels:
		_output_channels[ch_name] = chop_in.channels[ch_name].duplicate()

	return null


## Called by GNEmbeddedHost._collect_outputs() to get channel data.
func _get_host_channels() -> Dictionary:
	return _output_channels


func update_preview_control(control: Control) -> void:
	if control is Label:
		if _output_channels.is_empty():
			(control as Label).text = "no input"
		else:
			var lines := PackedStringArray()
			for ch_name in _output_channels:
				var samples: PackedFloat32Array = _output_channels[ch_name]
				if samples.size() > 0:
					lines.append("→ %s: %.3f" % [ch_name, samples[samples.size() - 1]])
			(control as Label).text = "\n".join(lines)
