class_name TextureSaveOUT
extends GNOutBase
## Reads a GPU texture back to CPU and saves to disk as PNG, WebP, or EXR.
##
## Activate the "active" toggle to start writing.
## Supports auto-numbering for image sequences.
## GPU→CPU readback uses async readback on the cook thread; compress + disk
## write run on a background thread so sync save does not stutter the graph.
## Turning Active OFF flushes the write queue before idle.

enum Format { PNG, WEBP, EXR }

## Running frame counter for auto-numbering (advanced on enqueue).
var _frame_counter: int = 0

## Previous "active" state — reset counter on re-activation.
var _was_active: bool = false

## Frames accepted into the write queue this session.
var _total_queued: int = 0

## Frames successfully written by the worker.
var _total_written: int = 0

## Async disk writer (compress + IO off the cook thread).
const _WRITE_QUEUE_MAX := 64
var _write_mutex: Mutex = Mutex.new()
var _write_queue: Array = []  # [{ "path", "img", "fmt", "quality" }, ...]
var _write_thread: Thread = null
var _write_running: bool = false
var _write_fail_count: int = 0


func _init() -> void:
	node_type = "texture_save"


## Disk write — not available on web.
func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux", "android", "ios"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Texture to save")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("active", false,
		"Active", "When enabled, queues texture saves every cook (disk write is async)"))
	add_parameter(GNParameter.create_file("file_path", "user://output/frame",
		PackedStringArray(["*.png", "*.webp", "*.exr"]),
		"File Path",
		"Base output path (format extension is appended; existing extension is stripped).",
		GNParameter.FileBrowseMode.SAVE_FILE))
	add_parameter(GNParameter.create_enum("format",
		PackedStringArray(["PNG", "WebP", "EXR"]), 0,
		"Format", "Output image format"))
	add_parameter(GNParameter.create_float("quality", 0.75, 0.0, 1.0, 0.01,
		"Quality", "WebP lossy quality (0-1). Ignored for PNG/EXR."))
	add_parameter(GNParameter.create_bool("auto_number", true,
		"Auto Number", "Append _NNNN frame counter to filename"))
	add_parameter(GNParameter.create_int("start_frame", 0, 0, null,
		"Start Frame", "Starting frame number for auto-numbering"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null or tex_in.texture == null:
		return null

	var active: bool = get_param_value("active")

	# Falling edge: flush pending writes before going idle
	if _was_active and not active:
		_stop_write_thread(false)
		_was_active = false
		return null

	# Rising edge: reset counter and start writer
	if active and not _was_active:
		_frame_counter = get_param_value("start_frame")
		_total_queued = 0
		_total_written = 0
		_write_fail_count = 0
		_start_write_thread()
	_was_active = active

	if not active:
		return null

	# GPU → CPU readback (async; must stay on cook / render thread)
	var image: Image = tex_in.get_readback_image()
	if image == null:
		GNLogger.warn("TextureSaveOUT",
			"'%s': readback returned null (texture may not be ready)" % id)
		return null

	# Build path
	var base_path: String = str(get_param_value("file_path")).get_basename()
	var fmt: int = get_param_value("format")
	var auto_num: bool = get_param_value("auto_number")
	var quality: float = float(get_param_value("quality"))

	var full_path: String = base_path
	if auto_num:
		full_path += "_%04d" % _frame_counter
		_frame_counter += 1

	match fmt:
		Format.PNG:  full_path += ".png"
		Format.WEBP: full_path += ".webp"
		Format.EXR:  full_path += ".exr"

	# Ensure directory
	var dir_path: String = full_path.get_base_dir()
	if not dir_path.is_empty():
		DirAccess.make_dir_recursive_absolute(dir_path)

	if not _enqueue_frame(full_path, image, fmt, quality):
		return null

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
	# Duplicate so GPU readback buffer can be reused / freed next cook.
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
			GNLogger.warn("TextureSaveOUT",
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
					Format.EXR:
						err = frame_img.save_exr(path, false)
					_:
						err = ERR_INVALID_PARAMETER
			_write_mutex.lock()
			if err == OK:
				_total_written += 1
			else:
				_write_fail_count += 1
			_write_mutex.unlock()
			if err != OK:
				GNLogger.warn("TextureSaveOUT",
					"'%s': Failed to save '%s' (error %d)" % [id, path, err])
			else:
				GNLogger.debug("TextureSaveOUT", "'%s': Saved '%s'" % [id, path])
		elif should_exit:
			break
		else:
			OS.delay_msec(1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_stop_write_thread(true)
