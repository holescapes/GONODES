class_name ImageSequenceIMG
extends GNImgBase
## Plays a numbered image sequence as animated CPU Images.
##
## Images are loaded via GNResourceLoader and cached as Image in memory.
## Supports PNG/JPG/WebP and KTX/KTX2 (ETC2 VRAM-compressed when present).
## Chain → ImgToTOP for GPU; compressed frames upload without pixel decode on
## GLES/mobile GPUs that support the format (e.g. ETC2 on Raspberry Pi).
##
## Images must follow a numbered naming convention:
##   prefix0001.png, prefix0002.png, ...  (auto-detected padding)
##
## Leave resolution at (0,0) for KTX2 sequences so frames stay compressed.

## Base path used for the last discovery scan — avoids re-scanning.
var _loaded_base_path: String = ""

## Ordered list of absolute frame paths.
var _frame_paths: PackedStringArray = PackedStringArray()

## Frame cache: index → CPU Image. On-demand or preloaded.
var _frame_cache: Dictionary = {}

## Current frame index (persisted across cooks for pause state).
var _current_frame_idx: int = -1

## Async per-frame load (when async_load ON and preload_all OFF).
var _async_frame_idx: int = -1
var _async_pending: bool = false
var _async_result: Image = null
var _async_mutex: Mutex = Mutex.new()
var _async_thread: Thread = null


func _init() -> void:
	node_type = "image_sequence"
	thread_safe = false


func update_time_dependency() -> void:
	var manual_idx: int = get_param_value("index")
	var playing: bool = get_param_value("play")
	time_dependent = playing and manual_idx < 0


func _init_ports() -> void:
	add_output("out", GNFamily.Type.IMG, "Current frame (CPU Image)")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_file("file", "Path to the file",
		PackedStringArray(["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.tga",
			"*.ktx", "*.ktx2"]),
		"", "Path to ANY frame in the sequence. Auto-discovers all numbered siblings."))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(0, 0),
		"Resolution", "Resize frames in pixels. (0, 0) keeps each frame's native size. Each side stays at 0 or above. Resizing decompresses KTX2/ETC2."))
	var res_param := get_parameter("resolution")
	if res_param != null:
		res_param.min_value = 0
	add_parameter(GNParameter.create_bool("play", true, "Play", "Play / pause"))
	add_parameter(GNParameter.create_float("speed", 1.0, 0.01, 10.0, 0.1, "Playback speed multiplier",
		"Playback speed multiplier (1.0 ≈ 30 fps)"))
	add_parameter(GNParameter.create_int("index", -1, -1, null,
		"", "Manual frame index override. -1 = auto-playback."))
	add_parameter(GNParameter.create_enum("loop_mode",
		PackedStringArray(["Loop", "Hold First", "Hold Last", "Ping-Pong"]),
		0, "", "Behavior at sequence end"))
	add_parameter(GNParameter.create_bool("preload_all", false, "Enable preload all",
		"Load all frames into memory at startup (faster playback, more RAM)"))
	add_parameter(GNParameter.create_bool("async_load", false,
		"Async Load", "Load each frame on a worker thread; hold last frame until ready."))


func _cook(_inputs: Array[GNData]) -> GNData:
	var out := _prepare_image()

	var file_path: String = get_param_value("file")
	var res: Vector2i = get_param_value("resolution")
	var do_play: bool = get_param_value("play")
	var spd: float = get_param_value("speed")
	var manual_idx: int = get_param_value("index")
	var loop_mode: int = get_param_value("loop_mode")
	var do_preload: bool = get_param_value("preload_all")
	var async_load: bool = get_param_value("async_load")

	# Discover sequence if file path changed.
	_discover_sequence(file_path, do_preload and not async_load)

	if _frame_paths.is_empty():
		return out

	var total_frames := _frame_paths.size()

	# Determine current frame index.
	var frame_idx := 0
	if manual_idx >= 0:
		frame_idx = manual_idx
	elif do_play:
		var raw_idx := int(absf(current_frame) * spd)
		frame_idx = raw_idx
	else:
		frame_idx = maxi(_current_frame_idx, 0)

	frame_idx = _apply_loop_mode(frame_idx, total_frames, loop_mode)
	_current_frame_idx = frame_idx

	_poll_async_frame()

	# Load the frame as a CPU Image.
	var img := _get_frame_image(frame_idx, async_load and not do_preload)
	if _is_async_pending():
		if not time_dependent:
			request_keep_dirty()
		node_warning = "Loading frame…"
	elif img == null:
		return out
	else:
		node_warning = ""

	# Resize only when both sides are set. (0, 0) stays native and is not written back.
	if res.x > 0 and res.y > 0 and Vector2i(img.get_width(), img.get_height()) != res:
		if img.is_compressed():
			img = GNResourceLoader.ensure_cpu_editable_image(img)
		else:
			img = img.duplicate() as Image
		img.resize(res.x, res.y, Image.INTERPOLATE_BILINEAR)

	out.set_image(img)
	return out


# ─── Sequence Discovery ───────────────────────────────────────────────────────

func _discover_sequence(file_path: String, do_preload: bool) -> void:
	if file_path == _loaded_base_path:
		return
	_loaded_base_path = file_path
	_frame_paths = PackedStringArray()
	_frame_cache.clear()
	_current_frame_idx = -1

	if file_path.is_empty():
		return

	if not GNResourceLoader.exists(file_path, project_dir):
		GNLogger.warn("ImageSequenceIMG",
			"'%s': file not found: %s" % [id, file_path])
		return

	# Resolve to absolute for directory scanning.
	var resolved_path := GNResourceLoader.resolve(file_path, project_dir)

	# Parse filename to extract prefix, digit count, and extension.
	var dir_path := resolved_path.get_base_dir()
	var file_name := resolved_path.get_file()
	var ext := file_path.get_extension()
	var base := file_name.get_basename()

	# Walk backwards to find trailing digit run.
	var digit_count := 0
	var i := base.length() - 1
	while i >= 0 and base[i].is_valid_int():
		digit_count += 1
		i -= 1
	var prefix := base.substr(0, i + 1)

	if digit_count == 0:
		# No numbering — single-frame sequence.
		_frame_paths.append(file_path)
		GNLogger.info("ImageSequenceIMG",
			"'%s': single frame (no numbering): %s" % [id, file_path])
		if do_preload:
			_preload_all_frames()
		return

	# Scan directory for matching files.
	var da := DirAccess.open(dir_path)
	if da == null:
		GNLogger.warn("ImageSequenceIMG",
			"'%s': cannot open directory: %s" % [id, dir_path])
		_frame_paths.append(file_path)
		return

	var matching_files: Array[String] = []
	da.list_dir_begin()
	var fname := da.get_next()
	while fname != "":
		if not da.current_is_dir():
			if fname.get_extension().to_lower() == ext.to_lower() \
					and fname.get_basename().begins_with(prefix):
				var remainder := fname.get_basename().substr(prefix.length())
				if not remainder.is_empty() and remainder.is_valid_int():
					matching_files.append(dir_path.path_join(fname))
		fname = da.get_next()
	da.list_dir_end()

	matching_files.sort()
	_frame_paths = PackedStringArray(matching_files)

	GNLogger.info("ImageSequenceIMG",
		"'%s': discovered %d frames" % [id, _frame_paths.size()])

	if do_preload:
		_preload_all_frames()


func _preload_all_frames() -> void:
	for fi in _frame_paths.size():
		_get_frame_image(fi)
	GNLogger.info("ImageSequenceIMG",
		"'%s': preloaded %d frames" % [id, _frame_paths.size()])


# ─── Frame Loading ────────────────────────────────────────────────────────────

## Returns a CPU Image for the given frame index. Caches on first load.
func _get_frame_image(idx: int, use_async: bool = false) -> Image:
	if idx < 0 or idx >= _frame_paths.size():
		return null
	if _frame_cache.has(idx):
		var _ret0 := _frame_cache[idx] as Image
		return _ret0

	if use_async:
		if not _is_async_pending():
			_start_async_frame_load(idx)
		# Hold previous frame in cache if any
		for prev in range(idx - 1, -1, -1):
			if _frame_cache.has(prev):
				return _frame_cache[prev] as Image
		return null

	var path: String = _frame_paths[idx]
	var img := GNResourceLoader.load_image(path, project_dir)
	if img != null:
		_frame_cache[idx] = img
	return img


func _is_async_pending() -> bool:
	_async_mutex.lock()
	var pending: bool = _async_pending
	_async_mutex.unlock()
	return pending


func _start_async_frame_load(idx: int) -> void:
	if idx < 0 or idx >= _frame_paths.size():
		return
	_cancel_async_frame()
	var path: String = _frame_paths[idx]
	var proj: String = project_dir
	_async_mutex.lock()
	_async_frame_idx = idx
	_async_pending = true
	_async_result = null
	_async_mutex.unlock()
	_async_thread = Thread.new()
	_async_thread.start(func():
		var img: Image = GNResourceLoader.load_image(path, proj)
		_async_mutex.lock()
		_async_result = img
		_async_pending = false
		_async_mutex.unlock()
	)


func _poll_async_frame() -> void:
	_async_mutex.lock()
	var pending: bool = _async_pending
	var result: Image = _async_result
	var idx: int = _async_frame_idx
	_async_mutex.unlock()
	if pending:
		return
	if _async_thread != null and not _async_thread.is_alive():
		_async_thread.wait_to_finish()
		_async_thread = null
	if idx < 0:
		return
	if result != null:
		_frame_cache[idx] = result
	_async_mutex.lock()
	_async_frame_idx = -1
	_async_result = null
	_async_mutex.unlock()


func _cancel_async_frame() -> void:
	if _async_thread != null:
		if _async_thread.is_alive():
			_async_thread.wait_to_finish()
		_async_thread = null
	_async_mutex.lock()
	_async_pending = false
	_async_result = null
	_async_frame_idx = -1
	_async_mutex.unlock()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cancel_async_frame()


# ─── Loop Mode ────────────────────────────────────────────────────────────────

func _apply_loop_mode(raw_idx: int, total: int, mode: int) -> int:
	if total <= 0:
		return 0
	match mode:
		0:  # Loop
			return raw_idx % total
		1:  # Hold First
			return 0 if raw_idx < 0 else mini(raw_idx, 0)
		2:  # Hold Last
			return mini(raw_idx, total - 1)
		3:  # Ping-Pong
			if total == 1:
				return 0
			var cycle_len := (total - 1) * 2
			var pos := raw_idx % cycle_len
			if pos < 0:
				pos += cycle_len
			return pos if pos < total else cycle_len - pos
	return clampi(raw_idx, 0, total - 1)
