class_name ImageSequenceIMG
extends GNImgBase
## Plays a numbered image sequence as animated CPU Images.
##
## Pure CPU — no SubViewport, no GPU upload.  Images are loaded via
## ResourceLoader and cached as CPU Images in memory.
##
## Images must follow a numbered naming convention:
##   prefix0001.png, prefix0002.png, ...  (auto-detected padding)
##
## Chain → ImgToTOP if you need a GPU texture downstream.

## Base path used for the last discovery scan — avoids re-scanning.
var _loaded_base_path: String = ""

## Ordered list of absolute frame paths.
var _frame_paths: PackedStringArray = PackedStringArray()

## Frame cache: index → CPU Image. On-demand or preloaded.
var _frame_cache: Dictionary = {}

## Current frame index (persisted across cooks for pause state).
var _current_frame_idx: int = -1


func _init() -> void:
	node_type = "image_sequence"
	time_dependent = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.IMG, "Current frame (CPU Image)")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_file("file", "Path to the file",
		PackedStringArray(["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.tga"]),
		"", "Path to ANY frame in the sequence. Auto-discovers all numbered siblings."))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(0, 0),
		"Resolution", "Resize frames to this size. (0, 0) = native."))
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


func _cook(_inputs: Array[GNData]) -> GNData:
	var out := _prepare_image()

	var file_path: String = get_param_value("file")
	var res: Vector2i = get_param_value("resolution")
	var do_play: bool = get_param_value("play")
	var spd: float = get_param_value("speed")
	var manual_idx: int = get_param_value("index")
	var loop_mode: int = get_param_value("loop_mode")
	var do_preload: bool = get_param_value("preload_all")

	# Discover sequence if file path changed.
	_discover_sequence(file_path, do_preload)

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

	# Load the frame as a CPU Image.
	var img := _get_frame_image(frame_idx)
	if img == null:
		return out

	# Resize if requested.
	if res != Vector2i.ZERO and Vector2i(img.get_width(), img.get_height()) != res:
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
		_auto_set_resolution()
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
	_auto_set_resolution()


## Auto-sets resolution from the first frame's native dimensions.
func _auto_set_resolution() -> void:
	if _frame_paths.is_empty():
		return
	var img := _get_frame_image(0)
	if img != null and img.get_width() > 0 and img.get_height() > 0:
		var native := Vector2i(img.get_width(), img.get_height())
		var current: Vector2i = get_param_value("resolution")
		if current == Vector2i.ZERO:
			set_param_value("resolution", native)
			GNLogger.info("ImageSequenceIMG",
				"'%s': resolution auto-set to %s" % [id, str(native)])


func _preload_all_frames() -> void:
	for fi in _frame_paths.size():
		_get_frame_image(fi)
	GNLogger.info("ImageSequenceIMG",
		"'%s': preloaded %d frames" % [id, _frame_paths.size()])


# ─── Frame Loading ────────────────────────────────────────────────────────────

## Returns a CPU Image for the given frame index. Caches on first load.
func _get_frame_image(idx: int) -> Image:
	if idx < 0 or idx >= _frame_paths.size():
		return null
	if _frame_cache.has(idx):
		var _ret0 := _frame_cache[idx] as Image
		return _ret0

	var path: String = _frame_paths[idx]
	var img := GNResourceLoader.load_image(path, project_dir)

	if img != null:
		_frame_cache[idx] = img
	return img


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
