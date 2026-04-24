class_name DelayCHOP
extends GNChopBase
## Delays channel values by a configurable number of frames using a ring buffer.
## Similar to TouchDesigner's Delay CHOP.

var _buffers: Dictionary = {}  # channel_name -> Array[float] ring buffer
var _write_idx: int = 0


func _init() -> void:
	node_type = "delay"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels")
	add_output("out", GNFamily.Type.CHOP, "Delayed channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("frames", 10, 1, 600, "Delay Frames",
		"Number of frames to delay"))
	add_parameter(GNParameter.create_bool("reset", false, "Reset", "Clear delay buffers"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var delay_frames: int = maxi(get_param_value("frames"), 1)
	var do_reset: bool = get_param_value("reset")

	if do_reset:
		_buffers.clear()
		_write_idx = 0

	var out: GNChannelData = _prepare_output(in_data.sample_rate)

	for ch_name in in_data.channels:
		var samples: PackedFloat32Array = in_data.channels[ch_name]
		if samples.is_empty():
			continue

		var current_val: float = samples[samples.size() - 1]

		# Initialise or resize buffer if needed
		if not _buffers.has(ch_name) or _buffers[ch_name].size() != delay_frames:
			var buf: Array = []
			buf.resize(delay_frames)
			buf.fill(current_val)
			_buffers[ch_name] = buf

		var buf: Array = _buffers[ch_name]

		# Read delayed value first, then write new value
		var read_idx: int = _write_idx % delay_frames
		var delayed_val: float = buf[read_idx]

		buf[_write_idx % delay_frames] = current_val
		_buffers[ch_name] = buf

		out.set_single_value(ch_name, delayed_val)

	_write_idx = (_write_idx + 1) % (delay_frames * 1000)  # Prevent overflow
	return out
