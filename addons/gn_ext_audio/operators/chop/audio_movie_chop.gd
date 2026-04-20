class_name AudioMovieCHOP
extends GNChopBase
## Extract audio track from a video file for synchronized playback.
##
## Reads the audio stream from a video/movie file and outputs it as CHOP
## channels. Designed to work alongside MovieFileInTOP for synchronized
## audio/video playback.
##
## Supported formats depend on Godot's built-in codecs: OGG Theora (.ogv).
## For broader format support (MP4, MOV, etc.), the gn_ext_ffmpeg extension
## is required.


func _init() -> void:
	node_type = "audiomovie"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Audio channels from video file")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("file", "",
		"File", "Path to video file"))
	add_parameter(GNParameter.create_bool("play", true,
		"Play", "Enable playback"))
	add_parameter(GNParameter.create_bool("loop", true,
		"Loop", "Loop when reaching end of file"))
	add_parameter(GNParameter.create_float("volume", 1.0, 0.0, 2.0, 0.01,
		"Volume", "Playback volume multiplier"))

var _player: AudioStreamPlayer = null
var _capture: AudioEffectCapture = null
var _bus_name: String = ""
var _loaded_file: String = ""


func _cook(inputs: Array[GNData]) -> GNData:
	var file_path: String = get_param_value("file")
	var playing: bool = get_param_value("play")
	var looping: bool = get_param_value("loop")
	var vol: float = get_param_value("volume")

	if file_path.is_empty():
		return null

	# Load audio from video file
	if file_path != _loaded_file:
		_cleanup()
		var stream: AudioStream = _load_audio_stream(file_path)
		if stream == null:
			GNLogger.warn("AudioMovieCHOP", "'%s' — could not load audio from '%s'" % [id, file_path])
			return null
		_setup_capture(stream)
		_loaded_file = file_path

	if _player == null or _capture == null:
		return null

	_player.volume_db = linear_to_db(maxf(vol, 0.001))

	if playing and not _player.playing:
		_player.play()
	elif not playing and _player.playing:
		_player.stop()

	if not _player.playing:
		return null

	# Capture audio frames
	var sr: float = AudioServer.get_mix_rate()
	var out := _prepare_output(sr)
	var frames_available: int = _capture.get_frames_available()
	if frames_available == 0:
		return out

	var buf: PackedVector2Array = _capture.get_buffer(frames_available)
	var left := PackedFloat32Array()
	left.resize(buf.size())
	var right := PackedFloat32Array()
	right.resize(buf.size())

	for i: int in range(buf.size()):
		left[i] = buf[i].x
		right[i] = buf[i].y

	out.set_channel("left", left)
	out.set_channel("right", right)
	return out


func _load_audio_stream(path: String) -> AudioStream:
	if not FileAccess.file_exists(path):
		return null
	# Try loading as audio resource (Godot supports .ogg, .wav, .mp3)
	var stream: AudioStream = load(path) as AudioStream
	return stream


func _setup_capture(stream: AudioStream) -> void:
	# Create dedicated audio bus with capture effect
	var bus_idx: int = AudioServer.bus_count
	AudioServer.add_bus(bus_idx)
	_bus_name = "AudioMovieCHOP_%s_%d" % [id, get_instance_id()]
	AudioServer.set_bus_name(bus_idx, _bus_name)
	AudioServer.set_bus_mute(bus_idx, true)  # Don't play to speakers

	_capture = AudioEffectCapture.new()
	AudioServer.add_bus_effect(bus_idx, _capture)

	_player = AudioStreamPlayer.new()
	_player.stream = stream
	_player.bus = _bus_name
	add_child(_player)

	time_dependent = true


func _cleanup() -> void:
	if _player != null and is_instance_valid(_player):
		_player.stop()
		_player.queue_free()
		_player = null

	if not _bus_name.is_empty():
		var idx: int = AudioServer.get_bus_index(_bus_name)
		if idx >= 0:
			AudioServer.remove_bus(idx)
		_bus_name = ""

	_capture = null
	_loaded_file = ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cleanup()
