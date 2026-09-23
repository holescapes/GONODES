class_name MovieOUT
extends GNOutBase
## Saves an IMG image sequence to disk as numbered frames (PNG or WebP).
##
## When "active" is on, each cook queues a frame write on a background thread
## (so sync PNG/WebP encode does not stutter the graph). Turning Active OFF
## flushes the queue before the node goes idle.
##
## For video container encoding, use FFmpegOUT instead (requires
## system ffmpeg CLI).
##
## Workflow:
##   NoiseTOP → TOPtoIMG → MovieOUT  (GPU → CPU → disk)
##   ScriptIMG → MovieOUT             (CPU → disk directly)

enum Format { PNG, WEBP }

## Running frame counter (path numbering — advanced on enqueue).
var _frame_counter: int = 0

## Previous "active" state for reset-on-reactivation.
var _was_active: bool = false

## Frames accepted into the write queue this session (preview).
var _total_queued: int = 0

## Frames successfully written by the worker (preview / diagnostics).
var _total_written: int = 0

## Async disk writer (keeps cooks from blocking on PNG/WebP encode/IO).
const _WRITE_QUEUE_MAX := 64
var _write_mutex: Mutex = Mutex.new()
var _write_queue: Array = []  # [{ "path", "img", "fmt", "quality" }, ...]
var _write_thread: Thread = null
var _write_running: bool = false
var _write_fail_count: int = 0


func _init() -> void:
	node_type = "movie_out"


## Disk write — not available on web.
func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux", "android", "ios"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, false, "Image to save as frame")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("active", false,
		"Active", "When enabled, queues each input image as a numbered frame (disk write is async)"))
	add_parameter(GNParameter.create_folder("output_folder", "user://output/sequence",
		"Output Folder", "Folder for frame files. Created automatically."))
	add_parameter(GNParameter.create_string("file_prefix", "frame",
		"File Prefix", "Filename prefix before the frame number"))
	add_parameter(GNParameter.create_enum("format",
		PackedStringArray(["PNG", "WebP"]), 0,
		"Format", "Image format for each frame"))
	add_parameter(GNParameter.create_float("quality", 0.9, 0.0, 1.0, 0.01,
		"Quality", "WebP quality (0-1). Ignored for PNG."))
	add_parameter(GNParameter.create_int("start_frame", 0, 0, null,
		"Start Frame", "Starting frame number"))
	add_parameter(GNParameter.create_int("frame_padding", 4, 1, 8,
		"Frame Padding", "Number of digits in frame number (e.g. 4 → frame_0001)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var img_in: GNImageData = _get_input_img(inputs, 0)
	if img_in == null or img_in.image == null:
		return null

	var active: bool = get_param_value("active")

	# Falling edge: flush pending writes before going idle
	if _was_active and not active:
		_stop_write_thread(false)
		_was_active = false
		return null

	# Rising edge: reset counters and start writer
	if active and not _was_active:
		_frame_counter = get_param_value("start_frame")
		_total_queued = 0
		_total_written = 0
		_write_fail_count = 0
		_start_write_thread()
	_was_active = active

	if not active:
		return null

	# Build path: folder/prefix_NNNN.ext
	var folder: String = get_param_value("output_folder")
	var prefix: String = get_param_value("file_prefix")
	var fmt: int = get_param_value("format")
	var padding: int = get_param_value("frame_padding")
	var quality: float = float(get_param_value("quality"))

	# Ensure folder
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder)

	var frame_str: String = str(_frame_counter).pad_zeros(padding)
	var extension: String = ".png" if fmt == Format.PNG else ".webp"
	var full_path: String = folder.path_join("%s_%s%s" % [prefix, frame_str, extension])

	if not _enqueue_frame(full_path, img_in.image, fmt, quality):
		return null

	_frame_counter += 1
	_total_queued += 1
	return null


# ─── Async disk writer ────────────────────────────────────────────────────────

func _start_write_thread() -> void:
	_stop_write_thread(true)
	_write_running = true
	_write_mutex.lock()
	_write_queue.clear()
	_write_mutex.unlock()
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


func _enqueue_frame(path: String, img: Image, fmt: int, quality: float) -> bool:
	if path.is_empty() or img == null:
		return false
	# Duplicate so the source image can be reused next cook while we write async.
	var copy: Image = img.duplicate()
	var spins := 0
	while true:
		_write_mutex.lock()
		if _write_queue.size() < _WRITE_QUEUE_MAX:
			_write_queue.append({
				"path": path,
				"img": copy,
				"fmt": fmt,
				"quality": quality,
			})
			_write_mutex.unlock()
			return true
		_write_mutex.unlock()
		OS.delay_msec(2)
		spins += 1
		if spins > 250:
			GNLogger.warn("MovieOUT",
				"'%s': disk writer backlog — dropped a frame" % id)
			_write_fail_count += 1
			return false
	return false


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
			var fmt: int = int(item.fmt)
			var quality: float = float(item.quality)
			var err: Error = ERR_INVALID_DATA
			if frame_img != null:
				match fmt:
					Format.PNG:
						err = frame_img.save_png(path)
					Format.WEBP:
						err = frame_img.save_webp(path, quality < 1.0, quality)
					_:
						err = ERR_INVALID_PARAMETER
			_write_mutex.lock()
			if err == OK:
				_total_written += 1
			else:
				_write_fail_count += 1
			_write_mutex.unlock()
			if err != OK:
				GNLogger.warn("MovieOUT",
					"'%s': Failed to save frame '%s' (error %d)" % [id, path, err])
		elif should_exit:
			break
		else:
			OS.delay_msec(1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_stop_write_thread(true)


## Override preview to show recording status.
func update_preview_control(control: Control) -> void:
	if control is Label:
		var label: Label = control as Label
		var active: bool = get_param_value("active")
		var pending: int = _write_queue_size()
		if active:
			if pending > 0:
				label.text = "REC ● %d\n(disk %d)" % [_total_queued, pending]
			else:
				label.text = "REC ● %d frames" % _total_queued
		elif _total_queued > 0:
			label.text = "STOPPED\n%d frames" % _total_written
		else:
			label.text = "idle"
