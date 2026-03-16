class_name HostInCHOP
extends GNChopBase
## Receives channel data from the host application via the LibGodot C API.
##
## The host calls gonodes_set_input_chop() to push float sample arrays.
## GNEmbeddedHost flushes that data into this node via _set_host_channels().
##
## Usage: Place in a patch, set the node ID, and wire output to downstream CHOPs.
## The host references this node by its ID string.

## Host-provided channel data: channel_name → PackedFloat32Array.
var _host_channels: Dictionary = {}
var _host_dirty: bool = false


func _init() -> void:
	node_type = "hostinchop"
	node_description = "Receive channel data from host application (LibGodot embedding)."
	time_dependent = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Channels received from host")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("label", "", "Label",
		"Optional label for this input in the host's UI"))
	add_parameter(GNParameter.create_float("sample_rate", 60.0, 1.0, 96000.0, 1.0, "Sample Rate",
		"Sample rate hint for downstream operators"))


## Called by GNEmbeddedHost._flush_inputs() with the host's channel data.
func _set_host_channels(channels: Dictionary) -> void:
	_host_channels = channels
	_host_dirty = true
	mark_dirty()


func _cook(_inputs: Array[GNData]) -> GNData:
	var sr: float = get_param_value("sample_rate")
	var out := _prepare_output(sr)

	for ch_name in _host_channels:
		var samples: PackedFloat32Array = _host_channels[ch_name]
		out.set_channel(ch_name, samples)

	out.valid = not _host_channels.is_empty()
	_host_dirty = false
	return out
