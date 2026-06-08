class_name RecordCHOP
extends GNChopBase
## Records input channel values over time into a buffer.
##
## Captures channel values each frame while recording, storing them in a
## ring buffer. Supports record/stop/clear controls, configurable max
## length, and loop mode for continuous overwriting.
##
## Use cases: gesture capture, motion recording, sample-accurate logging,
## time-series analysis, undo-buffer for animations.
##
## TouchDesigner equivalent: Record CHOP.

var _buffers: Dictionary = {}  # channel_name → PackedFloat32Array
var _write_head: int = 0
var _recorded_length: int = 0
var _is_recording: bool = false


func _init() -> void:
	node_type = "record"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels to record", "In")
	add_output("out", GNFamily.Type.CHOP, "Recorded channel history", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("record", false,
		"Record", "Start/stop recording"))
	add_parameter(GNParameter.create_pulse("clear",
		"Clear", "Clear all recorded data"))
	add_parameter(GNParameter.create_int("max_length", 3600, 1, 216000,
		"Max Length", "Maximum number of frames to record"))
	add_parameter(GNParameter.create_bool("loop", false,
		"Loop", "Overwrite oldest samples when buffer is full"))
	add_parameter(GNParameter.create_float("sample_rate", 60.0, 1.0, 48000.0, 1.0,
		"Sample Rate", "Output sample rate (default: frame rate)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var chop_in: GNChannelData = _get_input_chop(inputs, 0)
	var recording: bool = get_param_value("record")
	var do_clear: bool = get_param_value("clear")
	var max_len: int = get_param_value("max_length")
	var loop_mode: bool = get_param_value("loop")
	var sr: float = get_param_value("sample_rate")

	if do_clear:
		_clear()

	if recording and chop_in != null:
		var names: PackedStringArray = chop_in.get_channel_names()

		# Initialize buffers for new channels
		for ch_name: String in names:
			if not _buffers.has(ch_name):
				var buf := PackedFloat32Array()
				buf.resize(max_len)
				buf.fill(0.0)
				_buffers[ch_name] = buf

		# Record current values
		if _recorded_length < max_len:
			for ch_name: String in names:
				if _buffers.has(ch_name):
					_buffers[ch_name][_write_head] = chop_in.get_value(ch_name)
			_write_head += 1
			_recorded_length += 1
		elif loop_mode:
			_write_head = _write_head % max_len
			for ch_name: String in names:
				if _buffers.has(ch_name):
					_buffers[ch_name][_write_head] = chop_in.get_value(ch_name)
			_write_head += 1

	# Output recorded data
	var out: GNChannelData = _prepare_output(sr)
	var out_len: int = mini(_recorded_length, max_len) if not _buffers.is_empty() else 0

	for ch_name: String in _buffers:
		var buf: PackedFloat32Array = _buffers[ch_name]
		if out_len <= 0:
			out.set_single_value(ch_name, 0.0)
			continue

		if loop_mode and _recorded_length >= max_len:
			# Unwrap ring buffer: read_head to write_head
			var result := PackedFloat32Array()
			result.resize(max_len)
			for i: int in range(max_len):
				result[i] = buf[(_write_head + i) % max_len]
			out.set_channel(ch_name, result)
		else:
			out.set_channel(ch_name, buf.slice(0, out_len))

	out.length = out_len
	return out


func _clear() -> void:
	_buffers.clear()
	_write_head = 0
	_recorded_length = 0
