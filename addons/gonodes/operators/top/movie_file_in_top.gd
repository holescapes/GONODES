class_name MovieFileInTOP
extends GNTopBase
## Loads and plays a video file as a texture stream.
## Uses Godot's native VideoStreamPlayer (.ogv Theora format built-in).
## Similar to TouchDesigner's Movie File In TOP.
##
## The video plays inside a SubViewport; output is a live GPU texture.
## Supports play, pause, loop, speed, and seek controls.

var _video_player: VideoStreamPlayer = null
var _bg: ColorRect = null
var _loaded_file_path: String = ""
var _stream: VideoStream = null
var _awaiting_video_size: bool = false

# Audio capture infrastructure
var _audio_bus_name: String = ""
var _audio_bus_idx: int = -1
var _capture_effect: AudioEffectCapture = null
var _cached_audio_data: GNChannelData = null
var _left_buf: PackedFloat32Array = PackedFloat32Array()
var _right_buf: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	node_type = "movie_file_in"
	time_dependent = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Video frame texture")
	add_output("audio", GNFamily.Type.CHOP, "Audio waveform (left, right, level, pos, length, playing)")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_file("file", "",
		PackedStringArray(["*.ogv", "*.ogg"]),
		"", "Video file path (Theora .ogv format). Must be in the project directory."))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "",
		"Output resolution. Auto-set from video when a new file is loaded."))
	add_parameter(GNParameter.create_bool("play", true, "", "Play / pause the video"))
	add_parameter(GNParameter.create_bool("loop", true, "", "Loop the video when it reaches the end"))
	add_parameter(GNParameter.create_float("speed", 1.0, 0.0, 4.0, 0.05, "",
		"Playback speed multiplier (1.0 = normal)"))
	add_parameter(GNParameter.create_float("seek", -1.0, -1.0, null, 0.1, "",
		"Seek to time in seconds. Set -1 to disable manual seek."))
	add_parameter(GNParameter.create_color("bg_color", Color.BLACK, "",
		"Background color shown when no video is loaded or during gaps"))
	add_parameter(GNParameter.create_bool("mute", false, "Mute",
		"Mute direct audio output (audio still available on CHOP port)"))
	add_parameter(GNParameter.create_int("audio_buffer", 1024, 64, 8192, "Audio Buffer",
		"Number of audio samples to output per cook"))


func _cook(_inputs: Array[GNData]) -> GNData:
	_setup_viewport()

	var file_path: String = get_param_value("file")
	var res: Vector2i = get_param_value("resolution")
	var do_play: bool = get_param_value("play")
	var do_loop: bool = get_param_value("loop")
	var seek_time: float = get_param_value("seek")
	var bg_col: Color = get_param_value("bg_color")

	# Update viewport size
	if _viewport.size != res:
		_viewport.size = res

	_bg.color = bg_col

	# Load video file if path changed
	_apply_video_file(file_path)

	# Try to read video dimensions once available (after first frame decodes)
	if _awaiting_video_size and _video_player.is_playing():
		var vtex := _video_player.get_video_texture()
		if vtex and vtex.get_width() > 0 and vtex.get_height() > 0:
			var native_res := Vector2i(vtex.get_width(), vtex.get_height())
			if native_res != res:
				set_param_value("resolution", native_res)
				_viewport.size = native_res
				GNLogger.info("MovieFileInTOP", "'%s' resolution auto-set to %s" % [id, str(native_res)])
			_awaiting_video_size = false

	# Apply playback controls
	if _video_player.stream != null:
		_video_player.loop = do_loop

		# Seek (only when user explicitly sets a non-negative value)
		if seek_time >= 0.0:
			_video_player.stream_position = seek_time

		# Play/pause
		if do_play and not _video_player.is_playing():
			_video_player.play()
		elif not do_play and _video_player.is_playing():
			_video_player.paused = true
		elif do_play and _video_player.paused:
			_video_player.paused = false

	# Audio capture (skip if port 1 unconnected)
	if is_output_demanded(1):
		_pull_audio()

	if _audio_bus_idx >= 0:
		AudioServer.set_bus_mute(_audio_bus_idx, get_param_value("mute"))

	_cached_tex_data.resolution = _viewport.size
	return _cached_tex_data


func _setup_viewport() -> void:
	if _viewport != null:
		return

	_ensure_viewport(get_param_value("resolution"), false)
	# CRITICAL: GNNode sets process_mode = DISABLED on itself.
	# SubViewport and VideoStreamPlayer need processing enabled to decode
	# and render video frames. Override to ALWAYS on these children.
	_viewport.process_mode = Node.PROCESS_MODE_ALWAYS

	# Background fill
	_bg = ColorRect.new()
	_bg.name = "BG"
	_bg.color = Color.BLACK
	_viewport.add_child(_bg)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Dedicated audio bus with capture effect
	_setup_audio_bus()

	# VideoStreamPlayer fills the viewport
	_video_player = VideoStreamPlayer.new()
	_video_player.name = "VideoPlayer"
	_video_player.expand = true
	_video_player.autoplay = false
	_video_player.loop = true
	_video_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_video_player.bus = _audio_bus_name
	_viewport.add_child(_video_player)
	_video_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_video_player.finished.connect(_on_video_finished)


func _apply_video_file(file_path: String) -> void:
	if file_path == _loaded_file_path:
		return
	_loaded_file_path = file_path
	_awaiting_video_size = false

	if file_path.is_empty():
		_video_player.stop()
		_video_player.stream = null
		_stream = null
		GNLogger.debug("MovieFileInTOP", "'%s' cleared video" % id)
		return

	var loaded_stream := GNResourceLoader.load_video(file_path, project_dir)
	if loaded_stream == null:
		GNLogger.warn("MovieFileInTOP", "'%s' video file not found: %s" % [id, file_path])
		_video_player.stop()
		_video_player.stream = null
		_stream = null
		return

	_stream = loaded_stream
	_video_player.stream = _stream
	_awaiting_video_size = true  # Will read dimensions from first decoded frame
	var do_play: bool = get_param_value("play")
	if do_play:
		_video_player.play()
	GNLogger.info("MovieFileInTOP", "'%s' loaded video: %s" % [id, file_path])


func _on_video_finished() -> void:
	GNLogger.debug("MovieFileInTOP", "'%s' video playback finished" % id)


# ═══════════════════════════════════════════════════════════════════════════════
# Audio Capture
# ═══════════════════════════════════════════════════════════════════════════════

func _setup_audio_bus() -> void:
	if _audio_bus_idx >= 0:
		return
	_audio_bus_name = "GN_MovieAudio_%s" % id
	_audio_bus_idx = AudioServer.bus_count
	AudioServer.add_bus(_audio_bus_idx)
	AudioServer.set_bus_name(_audio_bus_idx, _audio_bus_name)

	_capture_effect = AudioEffectCapture.new()
	_capture_effect.buffer_length = 0.5
	AudioServer.add_bus_effect(_audio_bus_idx, _capture_effect)


func _pull_audio() -> void:
	var sample_rate: float = float(AudioServer.get_mix_rate())
	if _cached_audio_data == null:
		_cached_audio_data = GNChannelData.new()
	_cached_audio_data.sample_rate = sample_rate
	_cached_audio_data.channels.clear()

	var buf_size: int = get_param_value("audio_buffer")
	var is_playing: bool = _video_player != null and _video_player.is_playing()

	if _capture_effect != null and is_playing:
		var available: int = _capture_effect.get_frames_available()
		var pull_count: int = mini(available, buf_size)

		if pull_count > 0:
			var frames: PackedVector2Array = _capture_effect.get_buffer(pull_count)
			_left_buf.resize(frames.size())
			_right_buf.resize(frames.size())

			var rms_sum: float = 0.0
			for i in range(frames.size()):
				_left_buf[i] = frames[i].x
				_right_buf[i] = frames[i].y
				rms_sum += frames[i].x * frames[i].x

			_cached_audio_data.set_channel("left", _left_buf.duplicate())
			_cached_audio_data.set_channel("right", _right_buf.duplicate())
			_cached_audio_data.length = frames.size()
			var rms: float = sqrt(rms_sum / maxf(float(frames.size()), 1.0))
			_cached_audio_data.set_single_value("level", clampf(rms, 0.0, 1.0))
		else:
			_cached_audio_data.set_single_value("level", 0.0)
	else:
		_cached_audio_data.set_single_value("level", 0.0)

	# Transport info
	_cached_audio_data.set_single_value("playing", 1.0 if is_playing else 0.0)
	_cached_audio_data.set_single_value("pos",
		_video_player.stream_position if is_playing and _video_player != null else 0.0)
	var duration: float = 0.0
	if _stream != null and _stream.has_method("get_length"):
		duration = _stream.get_length()
	_cached_audio_data.set_single_value("length", duration)


## Route multi-output: port 0 = TOP texture, port 1 = CHOP audio.
func get_output_data(port_index: int) -> GNData:
	if port_index == 1:
		return _cached_audio_data
	return cached_output


func _cleanup_audio_bus() -> void:
	if _audio_bus_idx >= 0:
		for i in range(AudioServer.bus_count):
			if AudioServer.get_bus_name(i) == _audio_bus_name:
				AudioServer.remove_bus(i)
				break
	_capture_effect = null
	_audio_bus_idx = -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cleanup_audio_bus()


## Pause / resume the VideoStreamPlayer when the node enters or leaves the
## active cooking chain.  Without this, Godot's _process() keeps decoding
## and rendering video frames (and playing audio) even when the cook engine
## is not cooking this node.
func _on_active_changed(active: bool) -> void:
	if _video_player == null:
		return
	if active:
		if get_param_value("play") and _video_player.stream != null:
			_video_player.paused = false
	else:
		if _video_player.is_playing():
			_video_player.paused = true
		# Drain capture buffer so stale audio doesn't burst on resume
		if _capture_effect != null:
			_capture_effect.clear_buffer()
