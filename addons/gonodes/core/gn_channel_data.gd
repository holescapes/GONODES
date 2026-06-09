class_name GNChannelData
extends GNData
## Output data type for CHOP operators.
## Holds named channels of float sample arrays.
## RefCounted (inherits from GNData) — transient compute result.

## Channel data: maps channel name → float sample array.
## Example: {"tx": PackedFloat32Array([0.0, 0.1, ...]), "ty": PackedFloat32Array([...])}
var channels: Dictionary = {}

## Sample rate in Hz (e.g., 60.0 for frame-rate, 44100.0 for audio).
var sample_rate: float = 60.0

## Number of samples per channel.  All channels share the same length.
var length: int = 1

## Optional: the AudioServer bus name this data was captured from.
## Set by AudioInCHOP so AudioSpectrumCHOP can auto-route its analyzer via wire.
var source_bus: String = ""


func get_family() -> int:
	return GNFamily.Type.CHOP


func get_preview_text() -> String:
	var lines := PackedStringArray()
	for ch_name in channels:
		var samples: PackedFloat32Array = channels[ch_name]
		if samples.size() > 0:
			lines.append("%s: %.3f" % [ch_name, samples[samples.size() - 1]])
		else:
			lines.append("%s: —" % ch_name)
	return "\n".join(lines) if lines.size() > 0 else ""


func get_data_summary() -> String:
	var ch_count: int = channels.size()
	if length <= 1:
		return "%dch" % ch_count
	return "%dch×%d" % [ch_count, length]


## Returns the sample array for a named channel, or an empty array if not found.
func get_channel(channel_name: String) -> PackedFloat32Array:
	return channels.get(channel_name, PackedFloat32Array())


## Returns a single sample value from a channel.
## [param index] = -1 returns the last sample (most recent / single-value shortcut).
func get_value(channel_name: String, index: int = -1) -> float:
	var ch: PackedFloat32Array = channels.get(channel_name, PackedFloat32Array())
	if ch.is_empty():
		push_warning("GNChannelData: channel '%s' not found" % channel_name)
		return 0.0
	if index < 0:
		return ch[ch.size() - 1]
	if index >= ch.size():
		push_warning("GNChannelData: index %d out of range for channel '%s' (size %d)" % [index, channel_name, ch.size()])
		return 0.0
	return ch[index]


## Returns an array of all channel names.
func get_channel_names() -> PackedStringArray:
	var names := PackedStringArray()
	for key in channels.keys():
		names.append(key)
	return names


## Sets a single-sample channel (convenience for scalar CHOPs like LFO).
func set_single_value(channel_name: String, value: float) -> void:
	channels[channel_name] = PackedFloat32Array([value])
	length = 1


## Sets a multi-sample channel.
func set_channel(channel_name: String, samples: PackedFloat32Array) -> void:
	channels[channel_name] = samples
	# Keep length consistent with the largest channel
	if samples.size() > length:
		length = samples.size()


func invalidate() -> void:
	super.invalidate()
	channels.clear()
	length = 0


func duplicate_data() -> GNData:
	var copy := GNChannelData.new()
	copy.valid = valid
	copy.timestamp = timestamp
	copy.sample_rate = sample_rate
	copy.length = length
	# Deep copy channel arrays
	for ch_name in channels:
		copy.channels[ch_name] = channels[ch_name].duplicate()
	return copy


func get_expression_value(key: String, index: int = -1) -> Variant:
	return get_value(key, index)


func get_expression_info() -> Dictionary:
	return {
		"channels": get_channel_names(),
		"length": length,
		"sample_rate": sample_rate,
	}


func get_completions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ch_name in get_channel_names():
		result.append({"label": ch_name, "kind": "member"})
	return result


func save_state() -> Dictionary:
	var saved: Dictionary = {}
	for ch_name in channels:
		saved[ch_name] = channels[ch_name].duplicate()
	return saved


func restore_state(state: Dictionary) -> void:
	for ch_name in state:
		channels[ch_name] = state[ch_name]


func get_export_filters() -> Array[Dictionary]:
	return [
		{"filter": "*.csv", "description": "CSV (channels as columns)"},
		{"filter": "*.json", "description": "JSON"},
	]


func export_to_file(path: String) -> Error:
	var ext := path.get_extension().to_lower()
	match ext:
		"json":
			var dict := {}
			for ch_name in channels:
				var arr: PackedFloat32Array = channels[ch_name]
				var float_arr: Array = []
				for v in arr:
					float_arr.append(v)
				dict[ch_name] = float_arr
			var json_str := JSON.stringify(dict, "\t")
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f == null:
				return FileAccess.get_open_error()
			f.store_string(json_str)
			f.close()
			return OK
		_:
			var names: Array = channels.keys()
			if names.is_empty():
				return ERR_INVALID_DATA
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f == null:
				return FileAccess.get_open_error()
			f.store_csv_line(PackedStringArray(names))
			for i in range(length):
				var row := PackedStringArray()
				for ch_name in names:
					var arr: PackedFloat32Array = channels[ch_name]
					row.append(str(arr[i]) if i < arr.size() else "")
				f.store_csv_line(row)
			f.close()
			return OK
