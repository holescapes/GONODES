class_name AudioFileInCHOP
extends GNChopBase
## Plays an audio file (WAV, OGG Vorbis) and outputs waveform samples as CHOP channels.
##
## Uses AudioStreamPlayer + AudioEffectCapture to capture playback PCM data.
## Transport controls: play, pause, seek, loop.
##
## The **file** parameter also accepts HTTP/HTTPS URLs.  When a URL is provided,
## the audio is fetched asynchronously via GNUrlCache, cached on disk, and loaded
## on the next cook once the download completes.
##
## Output channels:
##   left   — left channel waveform
##   right  — right channel waveform (stereo files only)
##   level  — RMS amplitude (0-1)
##   pos    — playback position in seconds
##   length — file duration in seconds
##   playing — 1.0 if playing, 0.0 if stopped/paused

# ─── Audio infrastructure ──────────────────────────────────────────────────────

var _bus_name: String = ""
var _bus_idx: int = -1
var _capture_effect: AudioEffectCapture = null
var _stream_player: AudioStreamPlayer = null
var _audio_stream: AudioStream = null
var _current_file: String = ""
var _capture_active: bool = false

## Pre-allocated sample buffers.
var _left_buf: PackedFloat32Array = PackedFloat32Array()
var _right_buf: PackedFloat32Array = PackedFloat32Array()


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "audio_file_in"
	time_dependent = true
	thread_safe = false  # AudioStreamPlayer + URL fetching use the scene tree


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Audio waveform + transport channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_file("file", "Path to the file",
		PackedStringArray(["*.wav", "*.ogg"]), "File",
		"Audio file path (WAV or OGG Vorbis)"))
	add_parameter(GNParameter.create_bool("play", false, "Play",
		"Start/stop playback"))
	add_parameter(GNParameter.create_bool("loop", true, "Loop",
		"Loop playback"))
	add_parameter(GNParameter.create_float("volume", 0.0, -60.0, 6.0, 0.1, "Volume (dB)",
		"Playback volume in decibels"))
	add_parameter(GNParameter.create_float("seek_pos", 0.0, 0.0, null, 0.01, "Seek",
		"Seek to position in seconds (set to jump)"))
	add_parameter(GNParameter.create_int("buffer_size", 1024, 64, 8192, "Buffer",
		"Number of samples to output per cook"))
	add_parameter(GNParameter.create_bool("stereo", true, "Stereo",
		"Output stereo channels"))
	add_parameter(GNParameter.create_bool("mute_output", false, "Mute",
		"Mute audio output (still captures waveform)"))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(_inputs: Array[GNData]) -> GNData:
	var file_path: String = get_param_value("file")
	var want_play: bool = get_param_value("play")
	var want_loop: bool = get_param_value("loop")
	var volume_db: float = get_param_value("volume")
	var buf_size: int = get_param_value("buffer_size")
	var stereo: bool = get_param_value("stereo")
	var mute: bool = get_param_value("mute_output")

	var sample_rate: float = float(AudioServer.get_mix_rate())
	var out: GNChannelData = _prepare_output(sample_rate)

	# URL support — fetch via cache, cook with local path once ready
	if GNUrlCache.is_url(file_path):
		var result: Dictionary = GNUrlCache.resolve_url(file_path, self)
		match result.status:
			"ready":
				file_path = result.path
			"pending":
				return out  # placeholder until download completes
			"error":
				GNLogger.warn("AudioFileInCHOP", "'%s' — URL fetch error: %s" % [id, result.error])
				return out

	# Load / reload audio file
	if file_path != _current_file:
		_load_audio(file_path)

	# Manage playback state
	if _stream_player != null and _audio_stream != null:
		# Update volume + mute
		_stream_player.volume_db = volume_db
		if _bus_idx >= 0:
			AudioServer.set_bus_mute(_bus_idx, mute)

		# Handle seek
		var seek_pos: float = get_param_value("seek_pos")
		if seek_pos > 0.0 and _stream_player.playing:
			_stream_player.seek(seek_pos)
			set_param_value("seek_pos", 0.0)

		# Play / stop
		if want_play and not _stream_player.playing:
			_stream_player.play()
		elif not want_play and _stream_player.playing:
			_stream_player.stop()

	# Pull captured audio — discard backlog so output stays current.
	if _capture_effect != null and _capture_active:
		var available: int = _capture_effect.get_frames_available()
		var excess: int = available - buf_size
		if excess > 0:
			_capture_effect.get_buffer(excess)  # discard stale samples
			available = buf_size

		if available > 0:
			var frames: PackedVector2Array = _capture_effect.get_buffer(available)
			_left_buf.resize(frames.size())
			if stereo:
				_right_buf.resize(frames.size())

			var rms_sum: float = 0.0
			for i in range(frames.size()):
				_left_buf[i] = frames[i].x
				rms_sum += frames[i].x * frames[i].x
				if stereo:
					_right_buf[i] = frames[i].y

			out.set_channel("left", _left_buf.duplicate())
			if stereo:
				out.set_channel("right", _right_buf.duplicate())

			var rms: float = sqrt(rms_sum / maxf(float(frames.size()), 1.0))
			out.set_single_value("level", clampf(rms, 0.0, 1.0))
		else:
			out.set_single_value("level", 0.0)
	else:
		_left_buf.resize(buf_size)
		_left_buf.fill(0.0)
		out.set_channel("left", _left_buf.duplicate())
		out.set_single_value("level", 0.0)

	# Transport info channels
	var is_playing: bool = _stream_player != null and _stream_player.playing
	out.set_single_value("playing", 1.0 if is_playing else 0.0)
	out.set_single_value("pos", _stream_player.get_playback_position() if is_playing else 0.0)
	var duration: float = _audio_stream.get_length() if _audio_stream != null else 0.0
	out.set_single_value("length", duration)

	return out


# ═══════════════════════════════════════════════════════════════════════════════
# Audio File Loading
# ═══════════════════════════════════════════════════════════════════════════════

func _load_audio(file_path: String) -> void:
	_stop_and_cleanup()
	_current_file = file_path

	if file_path.is_empty():
		return

	var stream := GNResourceLoader.load_audio(file_path, project_dir)
	if stream != null:
		_audio_stream = stream
		# Set loop property based on stream type
		_apply_loop(_audio_stream, get_param_value("loop"))
		_start_capture()
	else:
		GNLogger.warn("AudioFileInCHOP", "'%s' is not a valid AudioStream" % file_path)


func _apply_loop(stream: AudioStream, loop: bool) -> void:
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop


# ═══════════════════════════════════════════════════════════════════════════════
# Capture Bus Management
# ═══════════════════════════════════════════════════════════════════════════════

func _start_capture() -> void:
	if _capture_active or _audio_stream == null:
		return

	# Create dedicated bus
	_bus_name = "GN_AudioFile_%s" % id
	_bus_idx = AudioServer.bus_count
	AudioServer.add_bus(_bus_idx)
	AudioServer.set_bus_name(_bus_idx, _bus_name)

	# Add capture effect
	_capture_effect = AudioEffectCapture.new()
	_capture_effect.buffer_length = 0.5
	AudioServer.add_bus_effect(_bus_idx, _capture_effect)

	# Create stream player
	_stream_player = AudioStreamPlayer.new()
	_stream_player.stream = _audio_stream
	_stream_player.bus = _bus_name
	add_child(_stream_player)

	# Auto-play if the play param is on
	if get_param_value("play"):
		_stream_player.play()

	_capture_active = true
	GNLogger.info("AudioFileInCHOP", "Loaded '%s' on bus '%s'" % [_current_file, _bus_name])


func _stop_and_cleanup() -> void:
	if _stream_player != null:
		_stream_player.stop()
		_stream_player.queue_free()
		_stream_player = null

	if _bus_idx >= 0:
		for i in range(AudioServer.bus_count):
			if AudioServer.get_bus_name(i) == _bus_name:
				AudioServer.remove_bus(i)
				break

	_capture_effect = null
	_audio_stream = null
	_bus_idx = -1
	_capture_active = false


## Clean up on node removal.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_stop_and_cleanup()
