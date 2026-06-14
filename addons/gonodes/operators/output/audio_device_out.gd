class_name AudioDeviceOUT
extends GNOutBase
## Outputs CHOP channel data to the audio system as PCM audio.
##
## Uses AudioStreamGenerator + AudioStreamGeneratorPlayback to push
## sample data from CHOP channels to the speakers.  Input channels named
## "left" and "right" (or the first 1-2 channels) are mapped to stereo.
##
## Typical chain:  WaveCHOP → AudioDeviceOUT
##                 AudioFileInCHOP → MathCHOP (gain) → AudioDeviceOUT

var _bus_name: String = ""
var _bus_idx: int = -1
var _stream_player: AudioStreamPlayer = null
var _generator: AudioStreamGenerator = null
var _playback: AudioStreamGeneratorPlayback = null
var _active: bool = false


func _init() -> void:
	node_type = "audio_device"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Audio samples to output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("active", false, "Active",
		"Enable/disable audio output"))
	var dev_param := GNParameter.create_enum("device",
		PackedStringArray(["Default"]), 0, "Device",
		"Output audio device. Switches AudioServer.output_device -- one device active at a time.")
	dev_param.dynamic_enum_callback = Callable(self, "_get_device_menu")
	add_parameter(dev_param)
	add_parameter(GNParameter.create_float("gain", 1.0, 0.0, 10.0, 0.01,
		"Gain", "Output gain multiplier"))
	add_parameter(GNParameter.create_float("mix_rate", 44100.0, 8000.0, 96000.0, 1.0,
		"Sample Rate", "Audio output sample rate (Hz)"))
	add_parameter(GNParameter.create_float("buffer_length", 0.1, 0.01, 1.0, 0.01,
		"Buffer (s)", "Generator buffer length in seconds"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	var want_active: bool = get_param_value("active")
	var gain: float = get_param_value("gain")

	if want_active and not _active:
		_start_output()
	elif not want_active and _active:
		_stop_output()

	if not _active or _playback == null or in_data == null:
		return null

	# Resolve left/right channels from input
	var left_samples: PackedFloat32Array = _resolve_channel(in_data, "left", 0)
	var right_samples: PackedFloat32Array = _resolve_channel(in_data, "right", 1)
	if right_samples.is_empty():
		right_samples = left_samples  # Mono → duplicate to both channels

	if left_samples.is_empty():
		return null

	# Push samples to the audio generator
	var frames_available: int = _playback.get_frames_available()
	var push_count: int = mini(left_samples.size(), frames_available)

	for i in range(push_count):
		var l: float = left_samples[i] * gain
		var r: float = right_samples[mini(i, right_samples.size() - 1)] * gain
		_playback.push_frame(Vector2(l, r))

	return null


func _resolve_channel(data: GNChannelData, preferred_name: String,
		fallback_idx: int) -> PackedFloat32Array:
	# Try preferred name first
	if data.channels.has(preferred_name):
		return data.channels[preferred_name]
	# Fall back to channel by index
	var names: PackedStringArray = data.get_channel_names()
	if fallback_idx < names.size():
		return data.channels[names[fallback_idx]]
	return PackedFloat32Array()


func _start_output() -> void:
	if _active:
		return

	var mix_rate: float = get_param_value("mix_rate")
	var buf_length: float = get_param_value("buffer_length")

	# Create a dedicated audio bus
	_bus_name = "GN_AudioOut_%s" % id
	_bus_idx = AudioServer.bus_count
	AudioServer.add_bus(_bus_idx)
	AudioServer.set_bus_name(_bus_idx, _bus_name)
	# Route to Master so it plays through speakers
	AudioServer.set_bus_send(_bus_idx, &"Master")

	# Set output device before starting
	var dev_idx: int = get_param_value("device")
	var devices := AudioServer.get_output_device_list()
	if devices.size() > 0 and dev_idx < devices.size():
		AudioServer.output_device = devices[dev_idx]

	# Create AudioStreamGenerator
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = mix_rate
	_generator.buffer_length = buf_length

	# Create AudioStreamPlayer
	_stream_player = AudioStreamPlayer.new()
	_stream_player.stream = _generator
	_stream_player.bus = _bus_name
	add_child(_stream_player)
	_stream_player.play()

	_playback = _stream_player.get_stream_playback() as AudioStreamGeneratorPlayback

	_active = true
	GNLogger.info("AudioDeviceOUT", "Audio output started on bus '%s' @ %.0f Hz" % [_bus_name, mix_rate])


func _stop_output() -> void:
	if not _active:
		return

	if _stream_player != null:
		_stream_player.stop()
		_stream_player.queue_free()
		_stream_player = null

	_playback = null
	_generator = null

	# Remove the bus
	for i in range(AudioServer.bus_count):
		if AudioServer.get_bus_name(i) == _bus_name:
			AudioServer.remove_bus(i)
			break

	_bus_idx = -1
	_active = false
	GNLogger.info("AudioDeviceOUT", "Audio output stopped")


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_stop_output()


func _get_device_menu() -> PackedStringArray:
	var devices := AudioServer.get_output_device_list()
	if devices.is_empty():
		return PackedStringArray(["Default"])
	return devices


func _on_parameter_changed(param_name: String, _new_value: Variant) -> void:
	if param_name == "device" and _active:
		_stop_output()
		_start_output()
