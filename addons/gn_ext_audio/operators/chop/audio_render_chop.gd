class_name AudioRenderCHOP
extends GNChopBase
## Offline render of a CHOP audio chain to a WAV buffer.
##
## Accumulates input audio samples over time into an internal buffer,
## then exports to WAV file on demand. Useful for non-realtime bounce
## of generative audio chains.
##
## Unlike real-time audio operators, this captures every sample that
## passes through it and stores them for export.

var _buffer_l := PackedFloat32Array()
var _buffer_r := PackedFloat32Array()
var _recording: bool = false
var _sample_rate: float = 44100.0


func _init() -> void:
	node_type = "audiorender"
	is_sink = false
	parameter_changed.connect(_on_record_export_sink_changed)


func _on_record_export_sink_changed(_node_id: String, param_name: String) -> void:
	if param_name == "record" or param_name == "export_now":
		is_sink = bool(get_param_value("record")) or bool(get_param_value("export_now"))


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Audio input to record", "In")
	add_output("out", GNFamily.Type.CHOP, "Pass-through of input (with recording status)", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("record", false,
		"Record", "Start/stop recording"))
	add_parameter(GNParameter.create_bool("clear", false,
		"Clear", "Clear the recording buffer"))
	add_parameter(GNParameter.create_file("export_path", "user://render.wav",
		PackedStringArray(["*.wav"]),
		"Export Path", "File path for WAV export",
		GNParameter.FileBrowseMode.SAVE_FILE))
	add_parameter(GNParameter.create_bool("export_now", false,
		"Export", "Write buffer to WAV file"))
	add_parameter(GNParameter.create_float("max_seconds", 300.0, 1.0, 3600.0, 1.0,
		"Max Seconds", "Maximum recording length in seconds"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)

	var record: bool = get_param_value("record")
	var clear: bool = get_param_value("clear")
	var export_now: bool = get_param_value("export_now")
	var max_sec: float = get_param_value("max_seconds")

	if clear:
		_buffer_l.clear()
		_buffer_r.clear()

	if in_data != null:
		_sample_rate = in_data.sample_rate if in_data.sample_rate > 0.0 else AudioServer.get_mix_rate()

	var max_samples: int = int(_sample_rate * max_sec)

	# Record if enabled and input available
	if record and in_data != null:
		_recording = true
		var names: PackedStringArray = in_data.get_channel_names()
		var left: PackedFloat32Array = in_data.get_channel(names[0]) if names.size() > 0 else PackedFloat32Array()
		var right: PackedFloat32Array = in_data.get_channel(names[1]) if names.size() > 1 else left

		_buffer_l.append_array(left)
		_buffer_r.append_array(right)

		# Trim to max
		if _buffer_l.size() > max_samples:
			_buffer_l = _buffer_l.slice(_buffer_l.size() - max_samples)
			_buffer_r = _buffer_r.slice(_buffer_r.size() - max_samples)
	else:
		_recording = false

	# Export on demand
	if export_now and _buffer_l.size() > 0:
		var path: String = get_param_value("export_path")
		_export_wav(path)

	# Output: pass input through + status channels
	var out := _prepare_output(_sample_rate)
	if in_data != null:
		for ch_name: String in in_data.get_channel_names():
			out.set_channel(ch_name, in_data.get_channel(ch_name))
	out.set_single_value("recording", 1.0 if _recording else 0.0)
	out.set_single_value("samples", float(_buffer_l.size()))
	out.set_single_value("seconds", float(_buffer_l.size()) / _sample_rate)
	return out


func _export_wav(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		GNLogger.warn("AudioRenderCHOP", "'%s' — could not open '%s' for writing" % [id, path])
		return

	var num_samples: int = _buffer_l.size()
	var num_channels: int = 2
	var bits_per_sample: int = 16
	var byte_rate: int = int(_sample_rate) * num_channels * bits_per_sample / 8
	var block_align: int = num_channels * bits_per_sample / 8
	var data_size: int = num_samples * block_align

	# WAV header
	file.store_string("RIFF")
	file.store_32(36 + data_size)
	file.store_string("WAVE")
	file.store_string("fmt ")
	file.store_32(16)  # PCM chunk size
	file.store_16(1)   # PCM format
	file.store_16(num_channels)
	file.store_32(int(_sample_rate))
	file.store_32(byte_rate)
	file.store_16(block_align)
	file.store_16(bits_per_sample)
	file.store_string("data")
	file.store_32(data_size)

	# Interleaved 16-bit samples
	for i: int in range(num_samples):
		var l: int = clampi(int(_buffer_l[i] * 32767.0), -32768, 32767)
		var r: int = clampi(int(_buffer_r[i] * 32767.0), -32768, 32767)
		file.store_16(l)
		file.store_16(r)

	file.close()
	GNLogger.info("AudioRenderCHOP", "'%s' — exported %d samples (%.1fs) to '%s'" % [
		id, num_samples, float(num_samples) / _sample_rate, path])
