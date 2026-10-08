class_name AudioFileInCHOP
extends GNChopBase
## Plays an audio file (WAV, OGG Vorbis, MP3) and outputs waveform samples as CHOP channels.
##
## **Load Mode**
##   • Auto — stream 8/16-bit PCM WAV from disk; Memory for OGG/MP3
##   • Memory — full decode into RAM (avoid for large WAV)
##   • Stream — disk-stream 8/16-bit PCM WAV via AudioStreamGenerator
##
## 24-bit / float WAV is not supported — convert to 16-bit PCM or OGG.
##
## Transport: play, pause, start cue, seek scrubber, loop, volume, gain.
## URLs fetch via GNUrlCache.
##
## Output channels:
##   left, right, level, pos, length, playing

const LOAD_AUTO := 0
const LOAD_MEMORY := 1
const LOAD_STREAM := 2

## WAV PCM larger than this is never fully decoded into RAM (Auto/Memory → Stream).
const _MEMORY_WAV_MAX_BYTES := 1_000_000

# ─── Audio infrastructure ──────────────────────────────────────────────────────

var _bus_name: String = ""
var _bus_idx: int = -1
var _capture_effect: AudioEffectCapture = null
var _stream_player: AudioStreamPlayer = null
var _audio_stream: AudioStream = null
var _current_file: String = ""
var _current_load_mode: int = -1
var _capture_active: bool = false
var _last_loop: bool = false
var _loop_applied: bool = false
var _load_queued: bool = false
var _pending_load_path: String = ""
var _pending_load_mode: int = LOAD_AUTO
var _load_thread: Thread = null
var _load_generation: int = 0
var _thread_result: AudioStream = null
var _memory_load_busy: bool = false

# Seek scrubber (do not reset to 0 — that made the slider unusable)
var _seek_user_dirty: bool = false
var _syncing_seek: bool = false
var _known_duration: float = 0.0
var _was_playing: bool = false
var _last_applied_cue: float = -1.0

# Stream-from-disk (8/16-bit PCM WAV)
var _is_stream_mode: bool = false
var _stream_file: FileAccess = null
var _stream_data_offset: int = 0
var _stream_data_size: int = 0
var _stream_frame: int = 0
var _stream_total_frames: int = 0
var _stream_channels: int = 1
var _stream_bits: int = 16
var _stream_rate: int = 44100
var _stream_frame_bytes: int = 2
var _generator: AudioStreamGenerator = null
var _gen_playback: AudioStreamGeneratorPlayback = null

## Pre-allocated sample buffers.
var _left_buf: PackedFloat32Array = PackedFloat32Array()
var _right_buf: PackedFloat32Array = PackedFloat32Array()
var _stream_read_buf: PackedByteArray = PackedByteArray()


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "audio_file_in"
	time_dependent = true
	thread_safe = false  # AudioStreamPlayer + URL fetching use the scene tree
	is_sink = false


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Audio waveform + transport channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_file("file", "Path to the file",
		PackedStringArray(["*.wav", "*.ogg", "*.mp3"]), "File",
		"Audio path (WAV/OGG/MP3). 8/16-bit PCM WAV, OGG, or MP3 only — 24-bit WAV is not supported."))
	add_parameter(GNParameter.create_enum("load_mode",
		PackedStringArray(["Auto", "Memory", "Stream"]), 0, "Load Mode",
		"Auto: stream 8/16-bit PCM WAV, Memory for OGG/MP3. Memory: full RAM decode. Stream: force disk stream."))
	add_parameter(GNParameter.create_bool("play", false, "Play",
		"Start/stop playback (starts from Start Position)"))
	add_parameter(GNParameter.create_bool("loop", true, "Loop",
		"Loop playback (returns to Start Position)"))
	add_parameter(GNParameter.create_float("volume", 0.0, -60.0, 6.0, 0.1, "Volume (dB)",
		"Capture-bus level in decibels (before Gain)"))
	add_parameter(GNParameter.create_float("gain", 1.0, 0.0, 16.0, 0.05, "Gain",
		"Linear amplitude for CHOP waveform + analysis bus (1 = unity). Raise if spectrum/bands look weak on loud masters."))
	# Cue point — Play starts here; Loop returns here. Independent of Seek scrubber.
	# Max must stay large until duration is known — a tiny max (e.g. 1.0) clamps
	# saved values on patch load via GNParameter.from_dict → _clamp_value.
	add_parameter(GNParameter.create_float("start_pos", 0.0, 0.0, 86400.0, 0.01, "Start Position",
		"Cue time in seconds. Play begins here; Loop wraps here. Use for export in-point."))
	# Live scrubber — follows playhead while playing.
	add_parameter(GNParameter.create_float("seek_pos", 0.0, 0.0, 86400.0, 0.01, "Seek",
		"Live playback position in seconds. Drag to scrub — follows playhead while playing."))
	add_parameter(GNParameter.create_int("buffer_size", 1024, 64, 8192, "Buffer",
		"Number of samples to output per cook"))
	add_parameter(GNParameter.create_bool("stereo", true, "Stereo",
		"Output stereo channels"))
	add_parameter(GNParameter.create_bool("mute_output", false, "Mute",
		"Does not send this file to the speakers. The capture bus stays audible to the waveform and a wired AudioSpectrumCHOP. Hear the file through AudioDeviceOUT."))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(_inputs: Array[GNData]) -> GNData:
	var file_path: String = get_param_value("file")
	var want_mode: int = int(get_param_value("load_mode"))
	var want_play: bool = get_param_value("play")
	var want_loop: bool = get_param_value("loop")
	var volume_db: float = get_param_value("volume")
	var gain_lin: float = maxf(float(get_param_value("gain")), 0.0)
	var buf_size: int = get_param_value("buffer_size")
	var stereo: bool = get_param_value("stereo")
	var effective_db: float = _effective_volume_db(volume_db, gain_lin)

	var play_rising: bool = want_play and not _was_playing

	var sample_rate: float = float(AudioServer.get_mix_rate())
	var out: GNChannelData = _prepare_output(sample_rate)

	# URL support — fetch via cache, cook with local path once ready
	if GNUrlCache.is_url(file_path):
		var result: Dictionary = GNUrlCache.resolve_url(file_path, self)
		match result.status:
			"ready":
				file_path = result.path
			"pending":
				request_keep_dirty()
				return out
			"error":
				GNLogger.warn("AudioFileInCHOP", "'%s' — URL fetch error: %s" % [id, result.error])
				return out

	# Reload when path or load mode changes
	if file_path != _current_file or want_mode != _current_load_mode:
		if not _load_queued and not _memory_load_busy:
			_load_queued = true
			_pending_load_path = file_path
			_pending_load_mode = want_mode
			call_deferred("_deferred_load_audio")
		_left_buf.resize(buf_size)
		_left_buf.fill(0.0)
		out.set_channel("left", _left_buf.duplicate())
		out.set_single_value("level", 0.0)
		out.set_single_value("playing", 0.0)
		return out

	# Memory decode still running on a worker — keep UI cooking lightly.
	if _memory_load_busy:
		request_keep_dirty()
		_left_buf.resize(buf_size)
		_left_buf.fill(0.0)
		out.set_channel("left", _left_buf.duplicate())
		out.set_single_value("level", 0.0)
		out.set_single_value("playing", 0.0)
		return out

	if play_rising:
		_cue_to_start(want_play)
	elif absf(_clamped_cue_seconds() - _last_applied_cue) > 0.02:
		# Expression-driven Start Cue (and inspector edits) — jump when cue moves.
		_cue_to_start(want_play)
	_was_playing = want_play
	_last_applied_cue = _clamped_cue_seconds()

	if _is_stream_mode:
		_cook_stream_transport(want_play, want_loop, effective_db)
	elif _stream_player != null and _audio_stream != null:
		_cook_memory_transport(want_play, want_loop, effective_db)

	# Waveform / CHOP channels
	var filled := false
	if _is_stream_mode and want_play:
		filled = _fill_channels_from_stream_file(buf_size, stereo, out, gain_lin)
	elif _stream_player != null and _audio_stream is AudioStreamWAV and _stream_player.playing:
		filled = _fill_channels_from_wav(
			_audio_stream as AudioStreamWAV,
			_stream_player.get_playback_position(),
			buf_size, stereo, out, gain_lin)

	if not filled and _capture_effect != null and _capture_active:
		filled = _fill_channels_from_capture(buf_size, stereo, out, gain_lin)

	if not filled:
		_left_buf.resize(buf_size)
		_left_buf.fill(0.0)
		out.set_channel("left", _left_buf.duplicate())
		if stereo:
			_right_buf.resize(buf_size)
			_right_buf.fill(0.0)
			out.set_channel("right", _right_buf.duplicate())
		out.set_single_value("level", 0.0)

	var is_playing: bool = false
	var pos_sec: float = 0.0
	var duration: float = 0.0
	if _is_stream_mode:
		is_playing = want_play and _stream_player != null and _stream_player.playing
		pos_sec = float(_stream_frame) / float(maxi(_stream_rate, 1))
		duration = float(_stream_total_frames) / float(maxi(_stream_rate, 1))
		out.sample_rate = float(_stream_rate)
	else:
		is_playing = _stream_player != null and _stream_player.playing
		pos_sec = _stream_player.get_playback_position() if is_playing else 0.0
		duration = _audio_stream.get_length() if _audio_stream != null else 0.0

	out.set_single_value("playing", 1.0 if is_playing else 0.0)
	out.set_single_value("pos", pos_sec)
	out.set_single_value("length", duration)
	if duration > 0.0:
		_update_seek_param_range(duration)
	out.source_bus = _bus_name
	return out


func _cook_memory_transport(want_play: bool, want_loop: bool, volume_db: float) -> void:
	if not _loop_applied or want_loop != _last_loop:
		_apply_loop(_audio_stream, want_loop)
		_last_loop = want_loop
		_loop_applied = true

	_stream_player.volume_db = volume_db
	_route_capture_off_speakers()

	_apply_seek_scrub(want_play)

	if want_play and not _stream_player.playing:
		_stream_player.play()
		_stream_player.seek(_clamped_cue_seconds())
		_sync_seek_display(_clamped_cue_seconds())
	elif not want_play and _stream_player.playing:
		_stream_player.stop()


func _cook_stream_transport(want_play: bool, want_loop: bool, volume_db: float) -> void:
	if _stream_player == null:
		return

	_last_loop = want_loop
	_stream_player.volume_db = volume_db
	_route_capture_off_speakers()

	_apply_seek_scrub(want_play)

	if want_play:
		if not _stream_player.playing:
			_stream_player.play()
			_gen_playback = _stream_player.get_stream_playback() as AudioStreamGeneratorPlayback
		_feed_stream_generator(want_loop)
	elif _stream_player.playing:
		_stream_player.stop()
		_gen_playback = null


## Volume (dB) plus linear Gain → effective capture-bus level for waveform + spectrum.
func _effective_volume_db(volume_db: float, gain_lin: float) -> float:
	if gain_lin <= 0.0001:
		return -80.0
	return volume_db + linear_to_db(gain_lin)


func _clamped_cue_seconds() -> float:
	var t: float = maxf(float(get_param_value("start_pos")), 0.0)
	if _known_duration > 0.0:
		t = minf(t, _known_duration)
	return t


## Jump playhead to Start Position (Play rising edge / loop wrap).
func _cue_to_start(want_play: bool) -> void:
	var t: float = _clamped_cue_seconds()
	_seek_to_seconds(t, want_play)
	_sync_seek_display(t)


func _sync_seek_display(pos_sec: float) -> void:
	_syncing_seek = true
	set_param_value("seek_pos", pos_sec)
	_syncing_seek = false


## Scrubber: user drag seeks; while playing the param follows the playhead.
## (Old behavior reset seek_pos to 0 every cook, which fought the inspector slider.)
func _apply_seek_scrub(want_play: bool) -> void:
	if _seek_user_dirty:
		var t: float = float(get_param_value("seek_pos"))
		_seek_to_seconds(t, want_play)
		_seek_user_dirty = false
		return
	if not want_play:
		return
	var pos: float = _current_playhead_seconds()
	if absf(pos - float(get_param_value("seek_pos"))) < 0.02:
		return
	_sync_seek_display(pos)


func _seek_to_seconds(pos_sec: float, want_play: bool) -> void:
	var t: float = maxf(pos_sec, 0.0)
	if _known_duration > 0.0:
		t = minf(t, _known_duration)
	if _is_stream_mode:
		_stream_seek_seconds(t)
	elif _stream_player != null and _audio_stream != null:
		if want_play and not _stream_player.playing:
			_stream_player.play()
		_stream_player.seek(t)


func _current_playhead_seconds() -> float:
	if _is_stream_mode:
		return float(_stream_frame) / float(maxi(_stream_rate, 1))
	if _stream_player != null and _stream_player.playing:
		return _stream_player.get_playback_position()
	return float(get_param_value("seek_pos"))


func _update_seek_param_range(duration: float) -> void:
	_known_duration = maxf(duration, 0.0)
	# Keep max at least the clip length, never shrink below the current value
	# (avoids re-clamping a restored cue when duration is still unknown/0).
	var d: float = maxf(_known_duration, 0.01)
	for pname in ["seek_pos", "start_pos"]:
		var p: GNParameter = get_parameter(pname)
		if p == null:
			continue
		var cur: float = float(p.value) if p.value != null else 0.0
		var new_max: float = maxf(d, cur)
		# Prefer clip duration once known, but never below the stored value.
		if _known_duration > 0.0:
			new_max = maxf(_known_duration, cur)
		if p.max_value != null and is_equal_approx(float(p.max_value), new_max):
			continue
		p.max_value = new_max
		# Refresh inspector range fill without treating it as a user scrub.
		_syncing_seek = true
		p.value_changed.emit(p.param_name, p.value)
		_syncing_seek = false


# ═══════════════════════════════════════════════════════════════════════════════
# Waveform fill
# ═══════════════════════════════════════════════════════════════════════════════

func _fill_channels_from_wav(wav: AudioStreamWAV, pos_sec: float,
		buf_size: int, stereo: bool, out: GNChannelData, gain_lin: float = 1.0) -> bool:
	if wav.data.is_empty() or wav.mix_rate <= 0:
		return false
	var bytes_per_sample: int = 2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1
	var ch: int = 2 if wav.stereo else 1
	var frame_bytes: int = bytes_per_sample * ch
	if frame_bytes <= 0:
		return false
	var total_frames: int = int(wav.data.size() / float(frame_bytes))
	if total_frames <= 0:
		return false

	var start_frame: int = clampi(int(pos_sec * float(wav.mix_rate)), 0, total_frames - 1)
	var count: int = mini(buf_size, total_frames - start_frame)
	if count <= 0:
		return false

	_left_buf.resize(count)
	if stereo:
		_right_buf.resize(count)

	var g: float = maxf(gain_lin, 0.0)
	var rms_sum: float = 0.0
	for i in range(count):
		var frame_i: int = start_frame + i
		var base: int = frame_i * frame_bytes
		var l: float = 0.0
		var r: float = 0.0
		if wav.format == AudioStreamWAV.FORMAT_16_BITS:
			l = float(wav.data.decode_s16(base)) / 32768.0
			if ch > 1:
				r = float(wav.data.decode_s16(base + 2)) / 32768.0
		else:
			l = float(wav.data[base] - 128) / 128.0
			if ch > 1:
				r = float(wav.data[base + 1] - 128) / 128.0
		l *= g
		r *= g
		_left_buf[i] = l
		if stereo:
			_right_buf[i] = r if ch > 1 else l
		rms_sum += l * l

	out.set_channel("left", _left_buf.duplicate())
	if stereo:
		out.set_channel("right", _right_buf.duplicate())
	out.set_single_value("level", clampf(sqrt(rms_sum / float(count)), 0.0, 1.0))
	out.sample_rate = float(wav.mix_rate)
	return true


func _fill_channels_from_stream_file(buf_size: int, stereo: bool, out: GNChannelData,
		gain_lin: float = 1.0) -> bool:
	if _stream_file == null or _stream_total_frames <= 0 or _stream_frame_bytes <= 0:
		return false
	var start_frame: int = clampi(_stream_frame, 0, _stream_total_frames - 1)
	var count: int = mini(buf_size, _stream_total_frames - start_frame)
	if count <= 0:
		return false

	var restore: int = _stream_file.get_position()
	_stream_file.seek(_stream_data_offset + start_frame * _stream_frame_bytes)
	var need: int = count * _stream_frame_bytes
	_stream_read_buf = _stream_file.get_buffer(need)
	_stream_file.seek(restore)
	if _stream_read_buf.size() < need:
		return false

	_left_buf.resize(count)
	if stereo:
		_right_buf.resize(count)
	var g: float = maxf(gain_lin, 0.0)
	var rms_sum: float = 0.0
	var ch: int = _stream_channels
	for i in range(count):
		var base: int = i * _stream_frame_bytes
		var lr: Vector2 = _decode_stream_frame(_stream_read_buf, base) * g
		_left_buf[i] = lr.x
		if stereo:
			_right_buf[i] = lr.y if ch > 1 else lr.x
		rms_sum += lr.x * lr.x

	out.set_channel("left", _left_buf.duplicate())
	if stereo:
		out.set_channel("right", _right_buf.duplicate())
	out.set_single_value("level", clampf(sqrt(rms_sum / float(count)), 0.0, 1.0))
	return true


func _decode_stream_frame(buf: PackedByteArray, base: int) -> Vector2:
	var l: float = 0.0
	var r: float = 0.0
	if _stream_bits == 16:
		l = float(buf.decode_s16(base)) / 32768.0
		r = float(buf.decode_s16(base + 2)) / 32768.0 if _stream_channels > 1 else l
	else:
		l = float(buf[base] - 128) / 128.0
		r = float(buf[base + 1] - 128) / 128.0 if _stream_channels > 1 else l
	return Vector2(l, r)


func _fill_channels_from_capture(buf_size: int, stereo: bool, out: GNChannelData,
		_gain_lin: float = 1.0) -> bool:
	var available: int = _capture_effect.get_frames_available()
	if available <= 0:
		return false
	var excess: int = available - buf_size
	if excess > 0:
		_capture_effect.get_buffer(excess)
		available = buf_size
	var frames: PackedVector2Array = _capture_effect.get_buffer(available)
	if frames.is_empty():
		return false

	# Capture already includes bus Volume+Gain; don't double-apply gain here.
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
	out.set_single_value("level", clampf(sqrt(rms_sum / float(frames.size())), 0.0, 1.0))
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# Loading — Memory (thread) or Stream (header + FileAccess)
# ═══════════════════════════════════════════════════════════════════════════════

func _deferred_load_audio() -> void:
	var path: String = _pending_load_path
	var requested_mode: int = _pending_load_mode
	_load_queued = false
	if path.is_empty():
		_cancel_load_thread_async()
		_stop_and_cleanup()
		_current_file = ""
		_current_load_mode = requested_mode
		_memory_load_busy = false
		return

	var effective: int = _resolve_effective_mode(path, requested_mode)
	if effective == LOAD_STREAM:
		if _try_open_stream(path, requested_mode):
			return
		# Unsupported WAV (e.g. 24-bit) — do not fall back to Memory convert.
		var layout: Dictionary = GNResourceLoader.peek_wav_layout(path, project_dir)
		if not layout.is_empty() and int(layout.get("format", 0)) == 1 \
				and int(layout.get("bits", 0)) == 24:
			_current_file = path
			_current_load_mode = requested_mode
			GNLogger.warn("AudioFileInCHOP",
				"Refusing 24-bit WAV (unsupported). Convert to 16-bit PCM or OGG: %s" % path)
			return
		GNLogger.warn("AudioFileInCHOP",
			"Cannot stream '%s' — falling back to Memory (OGG/MP3)" % path)

	_start_threaded_memory_load(path, requested_mode)


## Auto → Stream for 8/16-bit PCM WAV; Memory for OGG/MP3 / non-streamable.
## Large PCM WAV also forced to Stream when Memory is selected.
func _resolve_effective_mode(path: String, requested: int) -> int:
	if requested == LOAD_STREAM:
		return LOAD_STREAM
	var layout: Dictionary = GNResourceLoader.peek_wav_layout(path, project_dir)
	if not layout.is_empty():
		var bits: int = int(layout.get("bits", 0))
		var fmt: int = int(layout.get("format", 0))
		if fmt == 1 and bits == 24:
			GNLogger.warn("AudioFileInCHOP",
				"24-bit WAV is not supported. Convert to 16-bit PCM WAV or OGG: %s" % path)
			# Still return STREAM so try_open fails cleanly without Memory convert attempt.
			return LOAD_STREAM
	var streamable: bool = GNResourceLoader.wav_layout_is_streamable(layout)
	if requested == LOAD_AUTO:
		return LOAD_STREAM if streamable else LOAD_MEMORY
	if streamable and int(layout.get("data_size", 0)) > _MEMORY_WAV_MAX_BYTES:
		GNLogger.info("AudioFileInCHOP",
			"Using Stream instead of Memory for large WAV (%d bytes)" % int(layout.get("data_size", 0)))
		return LOAD_STREAM
	return LOAD_MEMORY


func _try_open_stream(file_path: String, requested_mode: int) -> bool:
	_cancel_load_thread_async()
	_stop_and_cleanup()

	var layout: Dictionary = GNResourceLoader.peek_wav_layout(file_path, project_dir)
	if layout.is_empty():
		return false
	var bits: int = int(layout.get("bits", 0))
	var fmt: int = int(layout.get("format", 0))
	if fmt == 1 and bits == 24:
		GNLogger.warn("AudioFileInCHOP",
			"24-bit WAV is not supported. Convert to 16-bit PCM WAV or OGG: %s" % file_path)
		return false
	if not GNResourceLoader.wav_layout_is_streamable(layout):
		return false

	var resolved: String = str(layout.get("resolved", ""))
	var file := FileAccess.open(resolved, FileAccess.READ)
	if file == null:
		return false

	_stream_channels = maxi(int(layout.get("channels", 1)), 1)
	_stream_bits = int(layout.get("bits", 16))
	_stream_rate = maxi(int(layout.get("sample_rate", 44100)), 1)
	_stream_data_offset = int(layout.get("data_offset", 0))
	_stream_data_size = int(layout.get("data_size", 0))
	var bytes_per_sample: int = 2 if _stream_bits == 16 else 1
	_stream_frame_bytes = bytes_per_sample * _stream_channels
	if _stream_frame_bytes <= 0:
		file.close()
		return false
	_stream_total_frames = int(_stream_data_size / float(_stream_frame_bytes))
	if _stream_total_frames <= 0:
		file.close()
		return false

	_stream_file = file
	_stream_file.seek(_stream_data_offset)
	_stream_frame = 0
	_is_stream_mode = true
	_memory_load_busy = false
	_current_file = file_path
	# Keep the UI enum value (Auto/Memory/Stream) — do not store effective mode here
	# or cook() will reload every frame and freeze the editor.
	_current_load_mode = requested_mode
	_loop_applied = true
	_start_stream_player()
	GNLogger.info("AudioFileInCHOP",
		"Streaming '%s' (%d-bit %dch @ %d Hz, %d frames)" % [
			file_path, _stream_bits, _stream_channels, _stream_rate, _stream_total_frames])
	mark_dirty()
	return true


func _start_threaded_memory_load(file_path: String, requested_mode: int) -> void:
	_cancel_load_thread_async()
	var gen: int = _load_generation
	_current_file = file_path
	_current_load_mode = requested_mode
	_is_stream_mode = false
	_loop_applied = false
	_stop_and_cleanup()
	_memory_load_busy = true
	_thread_result = null

	if file_path.is_empty():
		_memory_load_busy = false
		return

	var proj: String = project_dir
	_load_thread = Thread.new()
	_load_thread.start(func() -> void:
		_thread_result = GNResourceLoader.load_audio(file_path, proj)
		call_deferred("_finish_memory_load", gen, file_path)
	)


func _finish_memory_load(gen: int, file_path: String) -> void:
	# Yield until the worker exits — never wait_to_finish while it is still running.
	if _load_thread != null:
		while is_instance_valid(self) and _load_thread.is_alive():
			await get_tree().process_frame
		if _load_thread != null:
			_load_thread.wait_to_finish()
			_load_thread = null

	_memory_load_busy = false
	if not is_instance_valid(self):
		return
	if gen != _load_generation:
		_thread_result = null
		return

	var stream: AudioStream = _thread_result
	_thread_result = null
	if stream != null:
		_audio_stream = stream
		_is_stream_mode = false
		_apply_loop(_audio_stream, get_param_value("loop"))
		_last_loop = get_param_value("loop")
		_loop_applied = true
		_start_memory_player()
	else:
		GNLogger.warn("AudioFileInCHOP", "'%s' is not a valid AudioStream" % file_path)
	mark_dirty()


## Ignore in-flight worker results; do not block the UI waiting for them.
func _cancel_load_thread_async() -> void:
	_load_generation += 1
	_thread_result = null


func _join_load_thread() -> void:
	if _load_thread == null:
		return
	if _load_thread.is_alive():
		return
	if _load_thread.is_started():
		_load_thread.wait_to_finish()
	_load_thread = null


func _apply_loop(stream: AudioStream, loop: bool) -> void:
	var cue: float = _clamped_cue_seconds()
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if loop:
			# LOOP_FORWARD with loop_end==0 is an empty region → playback ends
			# immediately (looks like "won't play until Loop is unchecked").
			var rate: int = maxi(wav.mix_rate, 1)
			wav.loop_begin = clampi(int(cue * float(rate)), 0, maxi(_wav_frame_count(wav) - 1, 0))
			wav.loop_end = _wav_frame_count(wav)
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		else:
			wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamOggVorbis:
		var ogg := stream as AudioStreamOggVorbis
		ogg.loop = loop
		if "loop_offset" in ogg:
			ogg.loop_offset = cue if loop else 0.0
	elif stream is AudioStreamMP3:
		var mp3 := stream as AudioStreamMP3
		mp3.loop = loop
		if "loop_offset" in mp3:
			mp3.loop_offset = cue if loop else 0.0


func _wav_frame_count(wav: AudioStreamWAV) -> int:
	if wav.data.is_empty():
		return 0
	var bytes_per_sample: int = 2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1
	var ch: int = 2 if wav.stereo else 1
	var frame_bytes: int = bytes_per_sample * ch
	if frame_bytes <= 0:
		return 0
	return int(wav.data.size() / float(frame_bytes))


# ═══════════════════════════════════════════════════════════════════════════════
# Players / stream feeder
# ═══════════════════════════════════════════════════════════════════════════════

const _NULL_BUS_NAME := "GN_AudioNull"


## A muted bus placed ahead of every capture bus. Godot ignores a send whose
## target is at the same index or later, and an unknown send falls through to
## Master. Muting the capture bus itself also drops the signal before
## AudioEffectCapture and AudioSpectrumCHOP, which is why the viewers stayed
## flat and AudioDeviceOUT played silence.
func _ensure_null_bus() -> void:
	if AudioServer.get_bus_index(_NULL_BUS_NAME) >= 0:
		return
	AudioServer.add_bus(1)
	var idx := 1 if AudioServer.bus_count > 1 else AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, _NULL_BUS_NAME)
	AudioServer.set_bus_send(idx, &"Master")
	AudioServer.set_bus_mute(idx, true)
	AudioServer.set_bus_volume_db(idx, -80.0)


func _route_capture_off_speakers() -> void:
	if _bus_idx < 0:
		return
	AudioServer.set_bus_send(_bus_idx, StringName(_NULL_BUS_NAME))
	AudioServer.set_bus_mute(_bus_idx, false)
	AudioServer.set_bus_volume_db(_bus_idx, 0.0)


func _ensure_bus() -> void:
	if _capture_active:
		return
	_ensure_null_bus()
	_bus_name = "GN_AudioFile_%s" % id
	AudioServer.add_bus()
	_bus_idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(_bus_idx, _bus_name)
	_route_capture_off_speakers()

	_capture_effect = AudioEffectCapture.new()
	_capture_effect.buffer_length = 0.5
	AudioServer.add_bus_effect(_bus_idx, _capture_effect)
	_capture_active = true


func _start_memory_player() -> void:
	if _audio_stream == null:
		return
	_ensure_bus()
	_stream_player = AudioStreamPlayer.new()
	_stream_player.stream = _audio_stream
	_stream_player.bus = _bus_name
	_stream_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_stream_player)
	if get_param_value("play"):
		_stream_player.play()
	GNLogger.info("AudioFileInCHOP", "Memory-loaded '%s' on bus '%s'" % [_current_file, _bus_name])


func _start_stream_player() -> void:
	_ensure_bus()
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = float(_stream_rate)
	_generator.buffer_length = 0.1

	_stream_player = AudioStreamPlayer.new()
	_stream_player.stream = _generator
	_stream_player.bus = _bus_name
	_stream_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_stream_player)
	_gen_playback = null

	if get_param_value("play"):
		_stream_player.play()
		_gen_playback = _stream_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _stream_seek_seconds(pos_sec: float) -> void:
	var frame: int = clampi(int(pos_sec * float(_stream_rate)), 0, maxi(_stream_total_frames - 1, 0))
	_stream_frame = frame
	if _stream_file != null:
		_stream_file.seek(_stream_data_offset + _stream_frame * _stream_frame_bytes)


func _feed_stream_generator(want_loop: bool) -> void:
	if _gen_playback == null or _stream_file == null:
		return
	var avail: int = _gen_playback.get_frames_available()
	if avail <= 0:
		return

	# File cursor stays at the current frame; batch-read to avoid per-sample seeks.
	while avail > 0:
		if _stream_frame >= _stream_total_frames:
			if want_loop and _stream_total_frames > 0:
				_stream_seek_seconds(_clamped_cue_seconds())
				_sync_seek_display(_clamped_cue_seconds())
			else:
				set_param_value("play", false)
				_stream_player.stop()
				_gen_playback = null
				return

		var frames_left: int = _stream_total_frames - _stream_frame
		var chunk: int = mini(avail, frames_left)
		_stream_read_buf = _stream_file.get_buffer(chunk * _stream_frame_bytes)
		var got_frames: int = int(_stream_read_buf.size() / float(_stream_frame_bytes))
		if got_frames <= 0:
			set_param_value("play", false)
			_stream_player.stop()
			_gen_playback = null
			return

		for i in range(got_frames):
			var base: int = i * _stream_frame_bytes
			_gen_playback.push_frame(_decode_stream_frame(_stream_read_buf, base))

		_stream_frame += got_frames
		avail -= got_frames


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

	if _stream_file != null:
		_stream_file.close()
		_stream_file = null

	_capture_effect = null
	_audio_stream = null
	_generator = null
	_gen_playback = null
	_bus_idx = -1
	_capture_active = false
	_is_stream_mode = false
	_stream_frame = 0
	_stream_total_frames = 0


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cancel_load_thread_async()
		_memory_load_busy = false
		# Best-effort join only if the worker already finished.
		_join_load_thread()
		_stop_and_cleanup()


func _on_parameter_changed(param_name: String, new_value: Variant) -> void:
	super._on_parameter_changed(param_name, new_value)
	if param_name == "loop":
		_loop_applied = false
	elif param_name == "start_pos":
		# Cue change: refresh loop region and jump playhead to the new cue
		# (WindowOUT Start Cue slider / inspector). Seek remains the live scrubber.
		_loop_applied = false
		if not _syncing_seek:
			var t: float = _clamped_cue_seconds()
			_sync_seek_display(t)
			_seek_to_seconds(t, bool(get_param_value("play")))
		mark_dirty()
	elif param_name == "seek_pos":
		if not _syncing_seek:
			_seek_user_dirty = true
			mark_dirty()
	elif param_name == "load_mode":
		# Force reload under the new mode on next cook.
		_current_load_mode = -1
		mark_dirty()
	elif param_name == "gain" or param_name == "volume":
		mark_dirty()
