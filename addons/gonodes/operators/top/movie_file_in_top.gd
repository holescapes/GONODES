class_name MovieFileInTOP
extends GNNode
## Loads and plays a video file as a texture stream.
## Uses Godot's native VideoStreamPlayer (.ogv Theora format built-in).
## Similar to TouchDesigner's Movie File In TOP.
##
## The video plays inside a SubViewport; output is a live GPU texture.
## Supports play, pause, loop, speed, and seek controls.

var _viewport: SubViewport = null
var _video_player: VideoStreamPlayer = null
var _bg: ColorRect = null
var _cached_tex_data: GNTextureData = null
var _loaded_file_path: String = ""
var _stream: VideoStream = null
var _awaiting_video_size: bool = false


func _init() -> void:
	node_type = "moviefilein"
	family = GNFamily.Type.TOP
	time_dependent = true
	node_description = "Plays a video file (.ogv) as a texture stream. Godot's native VideoStreamPlayer."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Video frame texture")


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


func _cook(_inputs: Array[GNData]) -> GNData:
	_ensure_viewport()

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

	_cached_tex_data.resolution = _viewport.size
	return _cached_tex_data


func _ensure_viewport() -> void:
	if _viewport != null:
		return

	_viewport = SubViewport.new()
	_viewport.name = "VP_%s" % id
	_viewport.size = Vector2i(512, 512)
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.disable_3d = true
	_viewport.gui_disable_input = true
	# CRITICAL: GNNode sets process_mode = DISABLED on itself.
	# SubViewport and VideoStreamPlayer need processing enabled to decode
	# and render video frames. Override to ALWAYS on these children.
	_viewport.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_viewport)

	# Background fill
	_bg = ColorRect.new()
	_bg.name = "BG"
	_bg.color = Color.BLACK
	_viewport.add_child(_bg)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# VideoStreamPlayer fills the viewport
	_video_player = VideoStreamPlayer.new()
	_video_player.name = "VideoPlayer"
	_video_player.expand = true
	_video_player.autoplay = false
	_video_player.loop = true
	_video_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_viewport.add_child(_video_player)
	_video_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_video_player.finished.connect(_on_video_finished)

	_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _viewport.get_texture()
	_cached_tex_data.viewport = _viewport
	_cached_tex_data.resolution = _viewport.size
	GNLogger.debug("MovieFileInTOP", "'%s' viewport created" % id)


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

	if not ResourceLoader.exists(file_path):
		GNLogger.warn("MovieFileInTOP", "'%s' video file not found: %s" % [id, file_path])
		_video_player.stop()
		_video_player.stream = null
		_stream = null
		return

	var loaded := ResourceLoader.load(file_path)
	if loaded is VideoStream:
		_stream = loaded as VideoStream
		_video_player.stream = _stream
		_awaiting_video_size = true  # Will read dimensions from first decoded frame
		var do_play: bool = get_param_value("play")
		if do_play:
			_video_player.play()
		GNLogger.info("MovieFileInTOP", "'%s' loaded video: %s" % [id, file_path])
	else:
		GNLogger.warn("MovieFileInTOP", "'%s' resource is not a VideoStream: %s" % [id, file_path])
		_video_player.stop()
		_video_player.stream = null
		_stream = null


func _on_video_finished() -> void:
	GNLogger.debug("MovieFileInTOP", "'%s' video playback finished" % id)
