class_name TrailCHOP
extends GNChopBase
## Records the most recent N frames of input channel values as a scrolling
## ring-buffer, producing multi-sample output channels (like an oscilloscope
## trace).  Useful for visualising a value over time or feeding into analysis.

## Rolling buffers: channel_name → Array[float].
var _buffers: Dictionary = {}


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "trail"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels to trail")
	add_output("out", GNFamily.Type.CHOP, "Trailed channel history")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("length", 120, 2, 3600,
		"Length", "Number of frames to keep in the scrolling buffer"))
	add_parameter(GNParameter.create_bool("active", true,
		"Active", "Enable/disable recording (freeze when off)"))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(inputs: Array[GNData]) -> GNData:
	var chop_in: GNChannelData = _get_input_chop(inputs, 0)
	var trail_length: int = get_param_value("length")
	var active: bool = get_param_value("active")

	var out: GNChannelData = _prepare_output(60.0)

	if chop_in == null:
		# No input — output whatever we have buffered.
		_output_buffers(out)
		return out

	var names: PackedStringArray = chop_in.get_channel_names()

	if active:
		for ch_name in names:
			var current_val: float = chop_in.get_value(ch_name)

			if not _buffers.has(ch_name):
				_buffers[ch_name] = []

			_buffers[ch_name].push_back(current_val)

			# Trim to max length.
			while _buffers[ch_name].size() > trail_length:
				_buffers[ch_name].pop_front()

		# Remove channels from buffers that no longer exist in the input.
		var stale_keys: Array = []
		for key in _buffers:
			if key not in names:
				stale_keys.append(key)
		for key in stale_keys:
			_buffers.erase(key)

	_output_buffers(out)
	return out


# ═══════════════════════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Converts the internal buffers into PackedFloat32Array channels on [param out].
func _output_buffers(out: GNChannelData) -> void:
	for ch_name in _buffers:
		var buf: Array = _buffers[ch_name]
		var arr := PackedFloat32Array()
		arr.resize(buf.size())
		for i in range(buf.size()):
			arr[i] = buf[i]
		out.set_channel(ch_name, arr)
	out.length = _buffers.values()[0].size() if not _buffers.is_empty() else 0
