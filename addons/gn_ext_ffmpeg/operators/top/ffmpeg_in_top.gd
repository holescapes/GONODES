class_name FFmpegInTOP
extends GNTopBase
## FFmpeg-powered video player.
##
## Supports H.264, H.265, VP9, AV1, and many more codecs via the
## EIRTeam.FFmpeg GDExtension.  This operator is *only* available when
## the GDExtension is installed — the extension registry's ClassDB
## dependency guard prevents registration otherwise.
##
## All references to FFmpegVideoStream are resolved dynamically through
## ClassDB.instantiate() so this script parses cleanly even if the
## GDExtension is absent (though it will never be loaded in that case).
##
## Compared to the built-in MovieFileInTOP:
##   • Broad codec support (H.264, H.265, VP9, AV1, HAP, ProRes …)
##   • More container formats (.mp4, .mkv, .avi, .mov, .flv, .ts …)
##   • Explicit FFmpegVideoStream creation (guaranteed FFmpeg decode path)


# ═══════════════════════════════════════════════════════════════════════════════
# Internals
# ═══════════════════════════════════════════════════════════════════════════════

## SubViewport hosting the VideoStreamPlayer (child of this Node).
var _viewport: SubViewport = null

## The VideoStreamPlayer that decodes and renders video frames.
var _video_player: VideoStreamPlayer = null

## Background fill behind the video.
var _bg: ColorRect = null

## Reusable output data (created once, updated each cook).
var _cached_tex_data: GNTextureData = null

## Path of the currently loaded file — avoids reloading every cook.
var _loaded_file_path: String = ""

## True while waiting for the first decoded frame to read native resolution.
var _awaiting_video_size: bool = false


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "ffmpegin"
	time_dependent = true
	node_description = "FFmpeg video player. H.264, H.265, VP9, AV1 and more. Requires EIRTeam.FFmpeg."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Decoded video frame")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_file("file", "",
		PackedStringArray(["*.mp4", "*.mkv", "*.webm", "*.avi", "*.mov",
			"*.ogv", "*.flv", "*.wmv", "*.ts", "*.m4v"]),
		"", "Video file path"))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "",
		"Output resolution. Auto-set from video when a new file is loaded."))
	add_parameter(GNParameter.create_bool("play", true, "", "Play / pause toggle"))
	add_parameter(GNParameter.create_bool("loop", true, "", "Loop playback"))
	add_parameter(GNParameter.create_float("speed", 1.0, 0.0, 4.0, 0.05, "",
		"Playback speed multiplier (1.0 = normal)"))
	add_parameter(GNParameter.create_float("seek", -1.0, -1.0, null, 0.1, "",
		"Seek to time in seconds. Set -1 to disable manual seek."))
	add_parameter(GNParameter.create_color("bg_color", Color.BLACK, "",
		"Background color shown when no video is loaded"))
	add_parameter(GNParameter.create_float("volume_db", -80.0, -80.0, 24.0, 0.5,
		"", "Audio volume in dB (-80 = muted)"))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(_inputs: Array[GNData]) -> GNData:
	if not _is_ffmpeg_available():
		GNLogger.warn("FFmpegInTOP",
			"'%s': EIRTeam.FFmpeg GDExtension not loaded" % id)
		return null

	_ensure_viewport()

	var file_path: String = get_param_value("file")
	var res: Vector2i    = get_param_value("resolution")
	var do_play: bool    = get_param_value("play")
	var do_loop: bool    = get_param_value("loop")
	var seek_time: float = get_param_value("seek")
	var bg_col: Color    = get_param_value("bg_color")
	var vol_db: float    = get_param_value("volume_db")

	# ── Resolution ──────────────────────────────────────────────────────
	if _viewport.size != res:
		_viewport.size = res

	_bg.color = bg_col

	# ── Load file on change ─────────────────────────────────────────────
	_apply_video_file(file_path)

	# ── Auto-detect native resolution from first decoded frame ──────────
	if _awaiting_video_size and _video_player.is_playing():
		var vtex := _video_player.get_video_texture()
		if vtex and vtex.get_width() > 0 and vtex.get_height() > 0:
			var native_res := Vector2i(vtex.get_width(), vtex.get_height())
			if native_res != res:
				set_param_value("resolution", native_res)
				_viewport.size = native_res
				GNLogger.info("FFmpegInTOP",
					"'%s' resolution auto-set to %s" % [id, str(native_res)])
			_awaiting_video_size = false

	# ── Playback control ────────────────────────────────────────────────
	if _video_player.stream != null:
		_video_player.loop = do_loop
		_video_player.volume_db = vol_db

		# Seek (only when user explicitly sets a non-negative value)
		if seek_time >= 0.0:
			_video_player.stream_position = seek_time

		# Play / pause
		if do_play:
			_video_player.paused = false
			if not _video_player.is_playing():
				_video_player.play()
		else:
			_video_player.paused = true

	# ── Output ──────────────────────────────────────────────────────────
	_cached_tex_data.resolution = _viewport.size
	return _cached_tex_data


# ═══════════════════════════════════════════════════════════════════════════════
# FFmpeg Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Returns true when the EIRTeam.FFmpeg GDExtension is registered in ClassDB.
static func _is_ffmpeg_available() -> bool:
	return ClassDB.class_exists(&"FFmpegVideoStream")


## Creates an FFmpegVideoStream instance dynamically via ClassDB.
## Avoids any compile-time class reference so this script parses cleanly
## even if the GDExtension is absent.
func _create_ffmpeg_stream(path: String) -> VideoStream:
	var stream: Object = ClassDB.instantiate(&"FFmpegVideoStream")
	if stream == null:
		GNLogger.error("FFmpegInTOP",
			"'%s': failed to instantiate FFmpegVideoStream" % id)
		return null
	# FFmpegVideoStream inherits VideoStream which has a "file" property.
	stream.set(&"file", path)
	return stream as VideoStream


# ═══════════════════════════════════════════════════════════════════════════════
# File Loading
# ═══════════════════════════════════════════════════════════════════════════════

func _apply_video_file(file_path: String) -> void:
	if file_path == _loaded_file_path:
		return
	_loaded_file_path = file_path
	_awaiting_video_size = false

	if file_path.is_empty():
		_video_player.stop()
		_video_player.stream = null
		GNLogger.debug("FFmpegInTOP", "'%s' cleared video" % id)
		return

	# Try creating an FFmpegVideoStream explicitly — guarantees FFmpeg decode path.
	var stream := _create_ffmpeg_stream(file_path)
	if stream != null:
		_video_player.stream = stream
		_awaiting_video_size = true
		var do_play: bool = get_param_value("play")
		if do_play:
			_video_player.play()
		GNLogger.info("FFmpegInTOP",
			"'%s' loaded video via FFmpeg: %s" % [id, file_path])
	else:
		GNLogger.warn("FFmpegInTOP",
			"'%s' failed to create FFmpeg stream for: %s" % [id, file_path])
		_video_player.stop()
		_video_player.stream = null


# ═══════════════════════════════════════════════════════════════════════════════
# Viewport Setup
# ═══════════════════════════════════════════════════════════════════════════════

## Lazily creates the SubViewport + VideoStreamPlayer rendering pipeline
## as children of this Node.
func _ensure_viewport() -> void:
	if _viewport != null:
		return

	# SubViewport — captures the video frame each tick
	_viewport = SubViewport.new()
	_viewport.name = "VP_%s" % id
	_viewport.size = Vector2i(512, 512)
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.disable_3d = true
	_viewport.gui_disable_input = true
	# GNNode sets process_mode = DISABLED on itself.
	# SubViewport and VideoStreamPlayer need processing to decode frames.
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
	_video_player.volume_db = -80.0   # muted by default
	_video_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_viewport.add_child(_video_player)
	_video_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_video_player.finished.connect(_on_video_finished)

	# Reusable output data — ViewportTexture is a live GPU reference
	_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _viewport.get_texture()
	_cached_tex_data.viewport = _viewport
	_cached_tex_data.resolution = _viewport.size

	GNLogger.debug("FFmpegInTOP", "'%s' viewport created" % id)


func _on_video_finished() -> void:
	GNLogger.debug("FFmpegInTOP", "'%s' video playback finished" % id)
