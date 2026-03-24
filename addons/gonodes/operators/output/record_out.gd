class_name RecordOUT
extends GNOutBase
## Accumulates channel samples over time into an internal buffer.
##
## When "active" is on, each cook appends the current input channel values
## as a new row.  When stopped, the buffer can be saved to CSV or JSON
## via the "save" pulse, or cleared via the "reset" pulse.

## Internal recording buffer: channel_name → PackedFloat32Array of samples.
var _buffer: Dictionary = {}

## Number of recorded samples (rows).
var _sample_count: int = 0

## Channel order for consistent column output.
var _channel_order: PackedStringArray = PackedStringArray()

## Previous "save" state for edge detection (save on rising edge).
var _prev_save: bool = false

## Previous "reset" state for edge detection.
var _prev_reset: bool = false


func _init() -> void:
	node_type = "record"
	node_description = "Record CHOP channels over time to buffer. Save to CSV/JSON."


## Disk write on save — not available on web.
func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux", "android", "ios"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Channels to record")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("active", false,
		"Active", "When enabled, records input channel values each cook"))
	add_parameter(GNParameter.create_int("max_samples", 10000, 1, 1000000,
		"Max Samples", "Maximum number of recorded samples. Oldest dropped when exceeded."))
	add_parameter(GNParameter.create_bool("save", false,
		"Save", "Toggle on to save the buffer to disk (rising-edge triggered)"))
	add_parameter(GNParameter.create_bool("reset", false,
		"Reset", "Toggle on to clear the buffer (rising-edge triggered)"))
	add_parameter(GNParameter.create_string("file_path", "user://output/recording",
		"File Path", "Save file path (without extension)"))
	add_parameter(GNParameter.create_enum("format",
		PackedStringArray(["CSV", "JSON"]), 0,
		"Format", "File format for saving"))


func _cook(inputs: Array[GNData]) -> GNData:
	var chop_in: GNChannelData = _get_input_chop(inputs, 0)

	# Handle reset pulse (rising edge)
	var do_reset: bool = get_param_value("reset")
	if do_reset and not _prev_reset:
		_buffer.clear()
		_channel_order.clear()
		_sample_count = 0
		GNLogger.debug("RecordOUT", "'%s': Buffer cleared" % id)
	_prev_reset = do_reset

	# Record if active and we have input
	var active: bool = get_param_value("active")
	if active and chop_in != null:
		var max_samples: int = get_param_value("max_samples")
		var names: PackedStringArray = chop_in.get_channel_names()

		# Initialize channel order on first record
		if _channel_order.is_empty():
			_channel_order = names.duplicate()

		# Append one sample per channel
		for ch_name in names:
			if not _buffer.has(ch_name):
				_buffer[ch_name] = PackedFloat32Array()
				# Add to order if new channel appeared mid-recording
				if ch_name not in _channel_order:
					_channel_order.append(ch_name)
			_buffer[ch_name].append(chop_in.get_value(ch_name))

		_sample_count += 1

		# Trim oldest if over limit
		if _sample_count > max_samples:
			var excess: int = _sample_count - max_samples
			for ch_name in _buffer:
				var arr: PackedFloat32Array = _buffer[ch_name]
				_buffer[ch_name] = arr.slice(excess)
			_sample_count = max_samples

	# Handle save pulse (rising edge)
	var do_save: bool = get_param_value("save")
	if do_save and not _prev_save:
		_save_to_disk()
	_prev_save = do_save

	return null


# ─── Save Helpers ──────────────────────────────────────────────────────────────

func _save_to_disk() -> void:
	if _sample_count == 0:
		GNLogger.warn("RecordOUT", "'%s': Nothing to save (buffer empty)" % id)
		return

	var base_path: String = get_param_value("file_path")
	var fmt: int = get_param_value("format")

	var content: String = ""
	var extension: String = ""

	match fmt:
		0:  # CSV
			extension = ".csv"
			content = _buffer_to_csv()
		1:  # JSON
			extension = ".json"
			content = _buffer_to_json()

	var full_path: String = base_path + extension

	# Ensure directory
	var dir_path: String = full_path.get_base_dir()
	if not dir_path.is_empty():
		DirAccess.make_dir_recursive_absolute(dir_path)

	var file := FileAccess.open(full_path, FileAccess.WRITE)
	if file == null:
		GNLogger.warn("RecordOUT",
			"'%s': Cannot open '%s' (error %d)" % [id, full_path, FileAccess.get_open_error()])
		return

	file.store_string(content)
	file.close()
	GNLogger.info("RecordOUT",
		"'%s': Saved %d samples to '%s'" % [id, _sample_count, full_path])


func _buffer_to_csv() -> String:
	var lines: PackedStringArray = PackedStringArray()
	# Header row
	lines.append(",".join(_channel_order))
	# Data rows
	for i in range(_sample_count):
		var cells: PackedStringArray = PackedStringArray()
		for ch_name in _channel_order:
			if _buffer.has(ch_name) and i < _buffer[ch_name].size():
				cells.append("%.6f" % _buffer[ch_name][i])
			else:
				cells.append("0")
		lines.append(",".join(cells))
	return "\n".join(lines) + "\n"


func _buffer_to_json() -> String:
	var data: Dictionary = {}
	for ch_name in _channel_order:
		if _buffer.has(ch_name):
			# Convert PackedFloat32Array to regular Array for JSON
			var arr: Array = []
			for v in _buffer[ch_name]:
				arr.append(v)
			data[ch_name] = arr
	return JSON.stringify(data, "\t")


## Override preview to show recording status.
func update_preview_control(control: Control) -> void:
	if control is Label:
		var label: Label = control as Label
		var active: bool = get_param_value("active")
		if active:
			label.text = "REC ● %d" % _sample_count
		elif _sample_count > 0:
			label.text = "STOPPED\n%d samples" % _sample_count
		else:
			label.text = "idle"
