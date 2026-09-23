class_name FFmpegOUT
extends GNOutBase
## Encodes an IMG image sequence into a video file using the FFmpeg CLI.
##
## **Requires `ffmpeg` on the system PATH**, or set the **FFmpeg Path**
## parameter to a full path to `ffmpeg.exe`.
##
## Workflow:
##   1. Set output path, codec, framerate, quality (and optional FFmpeg Path).
##   2. Optional: set Duration (sec) > 0 to auto-stop capture after that many
##      seconds of frames (uses Framerate). 0 = unlimited — stop by turning
##      Active OFF.
##   3. Toggle **Capture** ON → frames queue to a temp folder on a disk thread
##      (cooks stay responsive). Status may show `(disk N)` if writes lag.
##   4. Capture OFF or Duration reached → flush pending writes, Capture clears,
##      encode runs **in the background** with Progress / Status updates.
##      Temp frames are removed after a successful encode.
##   5. **Cancel** aborts capture or kills a running encode.
##
## Output resolution = input IMG pixel size (set upstream with FitTOP etc.).

enum Codec { H264, H265, VP9, AV1, PRORES }

enum JobPhase {
	IDLE,
	CAPTURING,
	ENCODING,
	DONE,
	FAILED,
	CANCELLED,
}

## Temp directory for intermediate frames.
var _temp_dir: String = ""

## Frame counter for temp frames.
var _frame_counter: int = 0

## Previous "active" state — encode on falling edge.
var _was_active: bool = false

## Total frames captured this recording session.
var _total_captured: int = 0

## Capture target when Duration > 0 (0 = unlimited).
var _capture_target: int = 0

## Job phase for status / progress.
var _phase: int = JobPhase.IDLE

## Whether ffmpeg was found on PATH / custom path.
var _ffmpeg_available: bool = false
var _ffmpeg_checked: bool = false
var _last_ffmpeg_exe: String = ""

## Background encode
var _encode_thread: Thread = null
var _encode_pid: int = -1
var _cancel_requested: bool = false
var _last_output_path: String = ""
var _encode_total_frames: int = 0

## Async disk writer for capture (keeps cooks from blocking on PNG encode/IO).
const _WRITE_QUEUE_MAX := 64
var _write_mutex: Mutex = Mutex.new()
var _write_queue: Array = []  # [{ "path": String, "img": Image }, ...]
var _write_thread: Thread = null
var _write_running: bool = false
var _frames_written: int = 0
var _write_fail_count: int = 0
## Shared with encode thread (written on worker, read on main).
var _encode_current_frame: int = 0


func _init() -> void:
	node_type = "ffmpeg"
	time_dependent = true


## FFmpeg CLI requires OS.execute() — desktop-only (no CLI on mobile or web).
func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, false, "Image frames to encode")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("active", false,
		"Capture",
		"ON = write frames to temp. Turning OFF (or Duration reached) clears this and starts FFmpeg encode in the background — no extra toggle."))
	add_parameter(GNParameter.create_pulse("cancel", "Cancel",
		"Stop capture, or kill a background encode in progress."))
	add_parameter(GNParameter.create_float("duration", 0.0, 0.0, 36000.0, 0.1,
		"Duration (sec)",
		"Auto-stop capture after this many seconds of frames (0 = unlimited — stop by turning Capture OFF)."))
	add_parameter(GNParameter.create_file("output_file", "user://output/video",
		PackedStringArray(["*.mp4", "*.webm", "*.mov"]),
		"Output File",
		"Output video path (extension is set by Codec — pick a base name or a .mp4/.webm/.mov).",
		GNParameter.FileBrowseMode.SAVE_FILE))
	add_parameter(GNParameter.create_file("ffmpeg_path", "",
		PackedStringArray(["*.exe", "*"]),
		"FFmpeg Path",
		"Full path to ffmpeg.exe. Leave empty to use `ffmpeg` from system PATH."))
	add_parameter(GNParameter.create_enum("codec",
		PackedStringArray(["H.264 (.mp4)", "H.265 (.mp4)", "VP9 (.webm)", "AV1 (.mp4)", "ProRes (.mov)"]), 0,
		"Codec", "Video codec for encoding"))
	add_parameter(GNParameter.create_int("framerate", 30, 1, 120,
		"Framerate", "Output video frame rate"))
	add_parameter(GNParameter.create_int("crf", 23, 0, 51,
		"Quality (CRF)", "Constant Rate Factor (0=lossless, 23=default, 51=worst). Lower is better."))
	var status_p := GNParameter.create_string("status", "Idle", "Status",
		"Idle / Capturing / Encoding (background) / Done / Failed / Cancelled — encode always runs in the background after capture")
	status_p.read_only = true
	add_parameter(status_p)
	var prog_p := GNParameter.create_float("progress", 0.0, 0.0, 1.0, 0.01,
		"Progress", "Capture or background-encode progress (0–1)")
	prog_p.read_only = true
	add_parameter(prog_p)


func _pre_cook(delta: float) -> void:
	# Stay in the cook set while capturing or encoding so Cancel / Progress update.
	is_sink = bool(get_param_value("active")) or _phase == JobPhase.ENCODING
	if bool(get_param_value("cancel")):
		set_param_value("cancel", false)
		_request_cancel()
	super._pre_cook(delta)


func _cook(inputs: Array[GNData]) -> GNData:
	# Always refresh availability (path may change).
	var exe_now: String = _ffmpeg_exe()
	if not _ffmpeg_checked or exe_now != _last_ffmpeg_exe:
		_ffmpeg_checked = true
		_last_ffmpeg_exe = exe_now
		_ffmpeg_available = _check_ffmpeg()
		if not _ffmpeg_available:
			GNLogger.warn("FFmpegOUT",
				"'%s': ffmpeg not found (%s). Video encoding unavailable." % [id, exe_now])

	# While encoding, don't capture — just keep progress visible.
	if _phase == JobPhase.ENCODING:
		_sync_status_params()
		return null

	var img_in: GNImageData = _get_input_img(inputs, 0)
	var active: bool = get_param_value("active")

	# Falling edge: stop capture → start background encode
	if _was_active and not active:
		_stop_capture_and_encode()
		return null

	# Rising edge: start capture (refuse if encode still running)
	if active and not _was_active:
		if _is_encode_running():
			GNLogger.warn("FFmpegOUT",
				"'%s': Encode still running — wait or Cancel first" % id)
			set_param_value("active", false)
			_was_active = false
			return null
		_begin_capture()

	_was_active = active

	if not active:
		_sync_status_params()
		return null

	if not _ffmpeg_available:
		return null

	if img_in == null or img_in.image == null:
		return null

	# Queue PNG write on a background thread — sync save_png() stuttered the whole graph.
	if not _enqueue_capture_frame(img_in.image):
		return null

	_update_capture_progress()
	_sync_status_params()

	# Duration limit: stop capture and encode
	if _capture_target > 0 and _total_captured >= _capture_target:
		GNLogger.info("FFmpegOUT",
			"'%s': Duration reached (%d frames) — flushing disk then encode" % [
				id, _total_captured])
		_stop_capture_and_encode()

	return null


func _begin_capture() -> void:
	_cancel_requested = false
	_frame_counter = 0
	_total_captured = 0
	_frames_written = 0
	_write_fail_count = 0
	_temp_dir = _create_temp_dir()
	_phase = JobPhase.CAPTURING
	var dur: float = float(get_param_value("duration"))
	var fps: int = maxi(1, int(get_param_value("framerate")))
	_capture_target = maxi(1, int(round(dur * float(fps)))) if dur > 0.0 else 0
	set_param_value("progress", 0.0)
	_start_write_thread()
	_sync_status_params()
	if _capture_target > 0:
		GNLogger.info("FFmpegOUT",
			"'%s': Capture started (%d frames / %.1fs @ %dfps) → %s" % [
				id, _capture_target, dur, fps, _temp_dir])
	else:
		GNLogger.info("FFmpegOUT",
			"'%s': Capture started → %s" % [id, _temp_dir])


## Clear Capture, flush pending PNG writes, then kick off background encode.
func _stop_capture_and_encode() -> void:
	_was_active = false
	if bool(get_param_value("active")):
		set_param_value("active", false)

	if _cancel_requested:
		_phase = JobPhase.CANCELLED
		_stop_write_thread(true)
		_cleanup_temp_dir()
		_sync_status_params()
		return

	# Finish writing queued frames before ffmpeg reads the sequence.
	set_param_value("status", "Flushing disk…")
	_stop_write_thread(false)

	if not _ffmpeg_available:
		GNLogger.warn("FFmpegOUT",
			"'%s': Cannot encode — ffmpeg not on PATH" % id)
		_phase = JobPhase.FAILED
		_sync_status_params()
		return

	if _total_captured <= 0 or _temp_dir.is_empty():
		_phase = JobPhase.IDLE
		_sync_status_params()
		return

	if _write_fail_count > 0:
		GNLogger.warn("FFmpegOUT",
			"'%s': %d frame write(s) failed during capture" % [id, _write_fail_count])

	_start_encode_async()


func _update_capture_progress() -> void:
	if _capture_target > 0:
		set_param_value("progress", clampf(float(_total_captured) / float(_capture_target), 0.0, 1.0))
	else:
		# Soft indeterminate-ish progress based on frames (never quite hits 1).
		set_param_value("progress", clampf(1.0 - 1.0 / (1.0 + float(_total_captured) * 0.01), 0.0, 0.95))


func _sync_status_params() -> void:
	var text := "Idle"
	match _phase:
		JobPhase.CAPTURING:
			var pending: int = _write_queue_size()
			if _capture_target > 0:
				text = "Capturing %d / %d" % [_total_captured, _capture_target]
			else:
				text = "Capturing %d frames" % _total_captured
			if pending > 0:
				text += " (disk %d)" % pending
		JobPhase.ENCODING:
			text = "Encoding (background) %d / %d" % [
				mini(_encode_current_frame_safe(), _encode_total_frames),
				_encode_total_frames]
		JobPhase.DONE:
			text = "Done → %s" % _last_output_path.get_file()
		JobPhase.FAILED:
			text = "Failed"
		JobPhase.CANCELLED:
			text = "Cancelled"
		_:
			text = "Idle"
	set_param_value("status", text)


func _encode_current_frame_safe() -> int:
	return _encode_current_frame


# ─── Async capture writer ─────────────────────────────────────────────────────

func _start_write_thread() -> void:
	_stop_write_thread(true)
	_write_running = true
	_write_queue.clear()
	_frames_written = 0
	_write_fail_count = 0
	_write_thread = Thread.new()
	_write_thread.start(_write_worker)


## Stop the writer. If [param discard] is true, drop queued frames without writing.
func _stop_write_thread(discard: bool) -> void:
	if _write_thread == null:
		return
	if discard:
		_write_mutex.lock()
		_write_queue.clear()
		_write_mutex.unlock()
	_write_running = false
	if _write_thread.is_alive():
		_write_thread.wait_to_finish()
	_write_thread = null


func _write_queue_size() -> int:
	_write_mutex.lock()
	var n: int = _write_queue.size()
	_write_mutex.unlock()
	return n


func _enqueue_capture_frame(img: Image) -> bool:
	if _temp_dir.is_empty() or img == null:
		return false
	var frame_path: String = _temp_dir.path_join("frame_%06d.png" % _frame_counter)
	# Duplicate so the source image can be reused next cook while we write async.
	var copy: Image = img.duplicate()
	# If disk lags, wait briefly rather than unbounded RAM growth.
	var spins := 0
	while true:
		_write_mutex.lock()
		if _write_queue.size() < _WRITE_QUEUE_MAX:
			_write_queue.append({"path": frame_path, "img": copy})
			_write_mutex.unlock()
			break
		_write_mutex.unlock()
		OS.delay_msec(2)
		spins += 1
		if spins > 250:
			GNLogger.warn("FFmpegOUT",
				"'%s': disk writer backlog — dropped a frame" % id)
			_write_fail_count += 1
			return false
	_frame_counter += 1
	_total_captured += 1
	return true


func _write_worker() -> void:
	while true:
		_write_mutex.lock()
		var item: Variant = null
		if not _write_queue.is_empty():
			item = _write_queue.pop_front()
		var should_exit: bool = not _write_running and _write_queue.is_empty() and item == null
		_write_mutex.unlock()
		if item != null:
			var path: String = str(item.path)
			var frame_img: Image = item.img as Image
			var err: Error = ERR_INVALID_DATA
			if frame_img != null:
				err = frame_img.save_png(path)
			_write_mutex.lock()
			if err == OK:
				_frames_written += 1
			else:
				_write_fail_count += 1
			_write_mutex.unlock()
		elif should_exit:
			break
		else:
			OS.delay_msec(1)


# ─── FFmpeg Helpers ────────────────────────────────────────────────────────────

func _ffmpeg_exe() -> String:
	var custom: String = str(get_param_value("ffmpeg_path")).strip_edges()
	if not custom.is_empty():
		return ProjectSettings.globalize_path(custom)
	return "ffmpeg"


func _check_ffmpeg() -> bool:
	var output: Array = []
	var exit_code: int = OS.execute(_ffmpeg_exe(), ["-version"], output, true)
	return exit_code == 0


func _create_temp_dir() -> String:
	var base: String = OS.get_user_data_dir().path_join("gonodes_ffmpeg_temp")
	var session_dir: String = base.path_join("session_%d" % Time.get_ticks_msec())
	DirAccess.make_dir_recursive_absolute(session_dir)
	return session_dir


func _is_encode_running() -> bool:
	return _encode_thread != null and _encode_thread.is_alive()


func _start_encode_async() -> void:
	if _is_encode_running():
		return

	var output_base: String = str(get_param_value("output_file"))
	var codec_idx: int = int(get_param_value("codec"))
	var fps: int = int(get_param_value("framerate"))
	var crf: int = int(get_param_value("crf"))

	var extension: String = ""
	var codec_args: PackedStringArray = PackedStringArray()
	match codec_idx:
		Codec.H264:
			extension = ".mp4"
			codec_args = PackedStringArray([
				"-c:v", "libx264", "-crf", str(crf), "-pix_fmt", "yuv420p"])
		Codec.H265:
			extension = ".mp4"
			codec_args = PackedStringArray([
				"-c:v", "libx265", "-crf", str(crf), "-pix_fmt", "yuv420p"])
		Codec.VP9:
			extension = ".webm"
			codec_args = PackedStringArray([
				"-c:v", "libvpx-vp9", "-crf", str(crf), "-b:v", "0",
				"-pix_fmt", "yuv420p"])
		Codec.AV1:
			extension = ".mp4"
			codec_args = PackedStringArray([
				"-c:v", "libaom-av1", "-crf", str(crf), "-b:v", "0",
				"-pix_fmt", "yuv420p", "-cpu-used", "4"])
		Codec.PRORES:
			extension = ".mov"
			codec_args = PackedStringArray([
				"-c:v", "prores_ks", "-profile:v", "3", "-pix_fmt", "yuv422p10le"])

	var output_path: String = output_base.get_basename() + extension
	var out_dir: String = output_path.get_base_dir()
	if not out_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	var input_pattern: String = _temp_dir.path_join("frame_%06d.png")
	var args: PackedStringArray = PackedStringArray([
		"-y",
		"-hide_banner",
		"-loglevel", "error",
		"-stats",
		"-framerate", str(fps),
		"-i", ProjectSettings.globalize_path(input_pattern),
	])
	args.append_array(codec_args)
	var global_out: String = ProjectSettings.globalize_path(output_path)
	args.append(global_out)

	_phase = JobPhase.ENCODING
	_encode_total_frames = _total_captured
	_encode_current_frame = 0
	_last_output_path = output_path
	_cancel_requested = false
	set_param_value("progress", 0.0)
	_sync_status_params()
	is_sink = true

	GNLogger.info("FFmpegOUT",
		"'%s': Background encode %d frames → '%s'" % [id, _total_captured, output_path])

	var job := {
		"exe": _ffmpeg_exe(),
		"args": args,
		"output_path": output_path,
		"global_out": global_out,
		"total_frames": _total_captured,
		"temp_dir": _temp_dir,
	}
	# Temp dir ownership transfers to the worker until finish.
	_temp_dir = ""
	_encode_thread = Thread.new()
	_encode_thread.start(_encode_worker.bind(job))


func _encode_worker(job: Dictionary) -> void:
	var pipe: Dictionary = OS.execute_with_pipe(str(job.exe), job.args, false)
	if pipe.is_empty():
		call_deferred("_on_encode_finished", false, str(job.output_path), str(job.temp_dir),
			"failed to start ffmpeg process")
		return

	var pid: int = int(pipe.get("pid", -1))
	var stderr: FileAccess = pipe.get("stderr") as FileAccess
	var stdio: FileAccess = pipe.get("stdio") as FileAccess
	call_deferred("_on_encode_pid", pid)

	var acc := ""
	var total: int = int(job.total_frames)
	while pid >= 0 and OS.is_process_running(pid):
		if _cancel_requested:
			OS.kill(pid)
			break
		acc = _drain_pipe_text(stderr, acc)
		_parse_ffmpeg_progress(acc, total)
		# Also drain stdout so the pipe doesn't block.
		_drain_pipe_text(stdio, "")
		OS.delay_msec(80)

	# Final drain
	acc = _drain_pipe_text(stderr, acc)
	_parse_ffmpeg_progress(acc, total)
	_drain_pipe_text(stdio, "")

	if stderr != null and stderr.is_open():
		stderr.close()
	if stdio != null and stdio.is_open():
		stdio.close()

	var cancelled: bool = _cancel_requested
	var ok: bool = not cancelled and FileAccess.file_exists(str(job.global_out))
	var err_msg := ""
	if cancelled:
		err_msg = "cancelled"
	elif not ok:
		err_msg = "encode failed (no output file)"
	call_deferred("_on_encode_finished", ok, str(job.output_path), str(job.temp_dir), err_msg)


func _drain_pipe_text(pipe: FileAccess, acc: String) -> String:
	if pipe == null or not pipe.is_open():
		return acc
	while true:
		var chunk: PackedByteArray = pipe.get_buffer(4096)
		if pipe.get_error() != OK or chunk.is_empty():
			break
		acc += chunk.get_string_from_utf8()
	if acc.length() > 8192:
		acc = acc.substr(acc.length() - 4096)
	return acc


func _parse_ffmpeg_progress(acc: String, total_frames: int) -> void:
	# Prefer "frame=123" from -stats lines.
	var idx: int = acc.rfind("frame=")
	if idx < 0:
		return
	var rest: String = acc.substr(idx + 6)
	var num := ""
	for i in rest.length():
		var ch: String = rest[i]
		if ch == " " or ch == "\t":
			if num.is_empty():
				continue
			break
		if ch >= "0" and ch <= "9":
			num += ch
		elif not num.is_empty():
			break
	if num.is_empty():
		return
	var frame_i: int = int(num)
	_encode_current_frame = frame_i
	var p: float = 1.0
	if total_frames > 0:
		p = clampf(float(frame_i) / float(total_frames), 0.0, 1.0)
	call_deferred("_on_encode_progress", p, frame_i)


func _on_encode_pid(pid: int) -> void:
	_encode_pid = pid


func _on_encode_progress(p: float, frame_i: int) -> void:
	_encode_current_frame = frame_i
	set_param_value("progress", p)
	_sync_status_params()
	mark_dirty()


func _on_encode_finished(ok: bool, output_path: String, temp_dir: String, err_msg: String) -> void:
	_encode_pid = -1
	if _encode_thread != null:
		if _encode_thread.is_alive():
			# Worker deferred this after exiting the loop — join next frame if needed.
			pass
		_encode_thread.wait_to_finish()
		_encode_thread = null

	_last_output_path = output_path
	if ok:
		_phase = JobPhase.DONE
		set_param_value("progress", 1.0)
		GNLogger.info("FFmpegOUT",
			"'%s': Encoding complete → '%s'" % [id, output_path])
		_cleanup_temp_dir_path(temp_dir)
	elif err_msg == "cancelled":
		_phase = JobPhase.CANCELLED
		GNLogger.info("FFmpegOUT", "'%s': Encode cancelled" % id)
		_cleanup_temp_dir_path(temp_dir)
	else:
		_phase = JobPhase.FAILED
		GNLogger.warn("FFmpegOUT",
			"'%s': %s — temp frames at '%s'" % [id, err_msg, temp_dir])
	_sync_status_params()
	mark_dirty()


func _request_cancel() -> void:
	_cancel_requested = true
	if _phase == JobPhase.CAPTURING or bool(get_param_value("active")):
		GNLogger.info("FFmpegOUT", "'%s': Capture cancelled" % id)
		set_param_value("active", false)
		_was_active = false
		_phase = JobPhase.CANCELLED
		_stop_write_thread(true)
		_cleanup_temp_dir()
		_sync_status_params()
	elif _phase == JobPhase.ENCODING and _encode_pid >= 0:
		GNLogger.info("FFmpegOUT", "'%s': Killing encode pid %d" % [id, _encode_pid])
		OS.kill(_encode_pid)


func _cleanup_temp_dir() -> void:
	_cleanup_temp_dir_path(_temp_dir)
	_temp_dir = ""


func _cleanup_temp_dir_path(path: String) -> void:
	if path.is_empty():
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir():
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cancel_requested = true
		_stop_write_thread(true)
		if _encode_pid >= 0 and OS.is_process_running(_encode_pid):
			OS.kill(_encode_pid)
		if _encode_thread != null:
			if _encode_thread.is_alive():
				_encode_thread.wait_to_finish()
			_encode_thread = null
		_cleanup_temp_dir()


func update_preview_control(control: Control) -> void:
	if control is Label:
		var label: Label = control as Label
		if not _ffmpeg_available and _ffmpeg_checked:
			label.text = "no ffmpeg"
		elif _phase == JobPhase.ENCODING:
			var pct: int = int(round(float(get_param_value("progress")) * 100.0))
			label.text = "ENCODE (bg)\n%d%%" % pct
		elif _phase == JobPhase.CAPTURING or bool(get_param_value("active")):
			if _capture_target > 0:
				label.text = "REC ●\n%d/%d" % [_total_captured, _capture_target]
			else:
				label.text = "REC ● %d" % _total_captured
		elif _phase == JobPhase.DONE:
			label.text = "DONE\n%d frames" % _total_captured
		elif _phase == JobPhase.FAILED:
			label.text = "FAILED"
		elif _phase == JobPhase.CANCELLED:
			label.text = "CANCELLED"
		else:
			label.text = "idle"
