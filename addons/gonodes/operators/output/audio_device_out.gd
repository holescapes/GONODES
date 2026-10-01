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

const BUFFER_SAMPLES: Array[int] = [512, 1024, 2048, 4096, 8192]
const GENERATOR_MIN_SECONDS := 0.01

var _bus_name: String = ""
var _bus_idx: int = -1
var _stream_player: AudioStreamPlayer = null
var _generator: AudioStreamGenerator = null
var _playback: AudioStreamGeneratorPlayback = null
var _active: bool = false
var _devices_initialized: bool = false


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
	var buf_options := PackedStringArray()
	for samples in BUFFER_SAMPLES:
		buf_options.append(str(samples))
	add_parameter(GNParameter.create_enum("buffer_length", buf_options, 3, "Buffer",
		"Generator buffer size in samples (512–8192). Godot enforces a 10 ms minimum."))


func _cook(inputs: Array[GNData]) -> GNData:
	if not _devices_initialized:
		refresh_dynamic_enums()
		_devices_initialized = true
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


func _get_buffer_sample_count() -> int:
	var idx: int = int(get_param_value("buffer_length"))
	idx = clampi(idx, 0, BUFFER_SAMPLES.size() - 1)
	return BUFFER_SAMPLES[idx]


func _get_buffer_seconds() -> float:
	var mix_rate: float = float(get_param_value("mix_rate"))
	if mix_rate <= 0.0:
		mix_rate = 44100.0
	var seconds: float = float(_get_buffer_sample_count()) / mix_rate
	if seconds < GENERATOR_MIN_SECONDS:
		return GENERATOR_MIN_SECONDS
	return seconds


func _update_buffer_warning() -> void:
	var mix_rate: float = float(get_param_value("mix_rate"))
	if mix_rate <= 0.0:
		mix_rate = 44100.0
	var seconds: float = float(_get_buffer_sample_count()) / mix_rate
	if seconds < GENERATOR_MIN_SECONDS:
		node_warning = "Generator buffer floor is 10 ms — at this sample rate the effective buffer was raised."
	else:
		node_warning = ""


static func _migrate_buffer_length_value(val: Variant, mix_rate: float) -> int:
	if val is int and val >= 0 and val < BUFFER_SAMPLES.size():
		return val
	if val is float or val is int:
		var seconds: float = float(val)
		if seconds > 0.0 and seconds <= 2.0:
			var target_samples: float = seconds * mix_rate
			var best_idx: int = 0
			var best_diff: float = absf(float(BUFFER_SAMPLES[0]) - target_samples)
			for i in range(1, BUFFER_SAMPLES.size()):
				var diff: float = absf(float(BUFFER_SAMPLES[i]) - target_samples)
				if diff < best_diff:
					best_diff = diff
					best_idx = i
			return best_idx
	return 3


func from_dict(d: Dictionary) -> void:
	var migrated := d.duplicate(true)
	if migrated.has("parameters"):
		var params: Dictionary = migrated["parameters"]
		if params.has("buffer_length"):
			var buf_dict: Dictionary = params["buffer_length"]
			if buf_dict.has("value"):
				var mix_rate: float = 44100.0
				if params.has("mix_rate"):
					var mix_dict: Dictionary = params["mix_rate"]
					if mix_dict.has("value"):
						var mr = mix_dict["value"]
						if mr is float or mr is int:
							mix_rate = float(mr)
				buf_dict["value"] = _migrate_buffer_length_value(buf_dict["value"], mix_rate)
	super.from_dict(migrated)


func _start_output() -> void:
	if _active:
		return

	var mix_rate: float = get_param_value("mix_rate")
	var buf_length: float = _get_buffer_seconds()
	_update_buffer_warning()

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
	if param_name in ["buffer_length", "mix_rate"]:
		_update_buffer_warning()
	if param_name in ["device", "buffer_length", "mix_rate"] and _active:
		_stop_output()
		_start_output()
