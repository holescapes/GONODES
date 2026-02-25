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


func get_family() -> GNFamily.Type:
	return GNFamily.Type.CHOP


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
