class_name ImageSequenceTOP
extends GNTopBase
## Plays back a numbered image sequence as an animated texture stream.
## Supports PNG, WebP, JPG, and other Godot-importable image formats.
## Similar to TouchDesigner's Movie File In TOP with image sequences.
##
## Images must follow a numbered naming convention:
##   prefix0001.png, prefix0002.png, ...  (configurable zero-padding)
## The operator renders frames into a SubViewport via TextureRect.
## Supports play, loop, hold-first/last, speed, and expression-driven index.

var _tex_rect: TextureRect = null
var _bg: ColorRect = null
var _loaded_base_path: String = ""
var _frame_paths: PackedStringArray = PackedStringArray()
var _frame_cache: Dictionary = {}  # int → Texture2D
var _current_frame_idx: int = -1


func _init() -> void:
	node_type = "imagesequence"
	time_dependent = true
	node_description = "Plays a numbered image sequence (PNG, WebP, JPG) as animated texture frames."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Current frame texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_file("file", "",
		PackedStringArray(["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.tga"]),
		"", "Path to ANY frame in the sequence. The operator auto-discovers all numbered siblings."))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "",
		"Output resolution. Auto-set from first image when loaded."))
	add_parameter(GNParameter.create_bool("play", true, "", "Play / pause the sequence"))
	add_parameter(GNParameter.create_float("speed", 1.0, 0.01, 10.0, 0.1, "",
		"Playback speed multiplier (1.0 = 30 fps equivalent)"))
	add_parameter(GNParameter.create_int("index", -1, -1, null,
		"", "Manual frame index override. Set to -1 for auto-playback based on time."))
	add_parameter(GNParameter.create_enum("loop_mode",
		PackedStringArray(["Loop", "Hold First", "Hold Last", "Ping-Pong"]),
		0, "", "Behavior when playback reaches the end of the sequence"))
	add_parameter(GNParameter.create_enum("fit_mode",
		PackedStringArray(["Stretch", "Keep Aspect", "Keep Aspect Centered",
			"Keep Aspect Covered"]),
		2, "", "How each frame image fits into the output resolution"))
	add_parameter(GNParameter.create_color("bg_color", Color.BLACK, "",
		"Background color behind transparent or non-covering frames"))
	add_parameter(GNParameter.create_bool("preload_all", false, "",
		"Load all frames into memory at startup (faster playback, more RAM)"))


func _cook(_inputs: Array[GNData]) -> GNData:
	_setup_viewport()

	var file_path: String = get_param_value("file")
	var res: Vector2i = get_param_value("resolution")
	var do_play: bool = get_param_value("play")
	var spd: float = get_param_value("speed")
	var manual_idx: int = get_param_value("index")
	var loop_mode: int = get_param_value("loop_mode")
	var fit: int = get_param_value("fit_mode")
	var bg_col: Color = get_param_value("bg_color")
	var do_preload: bool = get_param_value("preload_all")

	# Update viewport size
	if _viewport.size != res:
		_viewport.size = res

	_bg.color = bg_col

	# Discover sequence if file path changed
	_discover_sequence(file_path, do_preload)

	# Fit mode → TextureRect stretch_mode
	match fit:
		0: _tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
		1: _tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		2: _tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		3: _tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	if _frame_paths.is_empty():
		_tex_rect.texture = null
		_cached_tex_data.resolution = res
		return _cached_tex_data

	var total_frames := _frame_paths.size()

	# Determine current frame index
	var frame_idx := 0
	if manual_idx >= 0:
		frame_idx = manual_idx
	elif do_play:
		# Time-based index: use cook engine's frame counter
		var raw_idx := int(absf(current_frame) * spd)
		frame_idx = raw_idx
	else:
		frame_idx = maxi(_current_frame_idx, 0)

	# Apply loop mode
	frame_idx = _apply_loop_mode(frame_idx, total_frames, loop_mode)
	_current_frame_idx = frame_idx

	# Load and display the frame
	var tex := _get_frame_texture(frame_idx)
	_tex_rect.texture = tex

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _setup_viewport() -> void:
	if _viewport != null:
		return

	_ensure_viewport(get_param_value("resolution"))

	# Background fill
	_bg = ColorRect.new()
	_bg.name = "BG"
	_bg.color = Color.BLACK
	_viewport.add_child(_bg)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# TextureRect for displaying frames
	_tex_rect = TextureRect.new()
	_tex_rect.name = "FrameRect"
	_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_viewport.add_child(_tex_rect)
	_tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Auto-discovers all numbered image files in the same directory as the given path.
## Expects files like: name0001.ext, name0002.ext, ...
func _discover_sequence(file_path: String, do_preload: bool) -> void:
	if file_path == _loaded_base_path:
		return
	_loaded_base_path = file_path
	_frame_paths = PackedStringArray()
	_frame_cache.clear()
	_current_frame_idx = -1

	if file_path.is_empty():
		GNLogger.debug("ImageSequenceTOP", "'%s' cleared sequence" % id)
		return

	if not ResourceLoader.exists(file_path):
		GNLogger.warn("ImageSequenceTOP", "'%s' file not found: %s" % [id, file_path])
		return

	# Parse the filename to extract prefix, number, and extension
	var dir_path := file_path.get_base_dir()
	var file_name := file_path.get_file()
	var ext := file_path.get_extension()

	# Strip extension and find trailing digits
	var base := file_name.get_basename()
	var prefix := ""
	var digit_count := 0

	# Walk backwards from end to find digit run
	var i := base.length() - 1
	while i >= 0 and base[i].is_valid_int():
		digit_count += 1
		i -= 1
	prefix = base.substr(0, i + 1)

	if digit_count == 0:
		# No numbering found — treat as single-frame sequence
		_frame_paths.append(file_path)
		GNLogger.info("ImageSequenceTOP", "'%s' single frame (no numbering): %s" % [id, file_path])
		if do_preload:
			_preload_all_frames()
		_auto_set_resolution()
		return

	# Scan directory for all files matching prefix + digits + ext
	var da := DirAccess.open(dir_path)
	if da == null:
		GNLogger.warn("ImageSequenceTOP", "'%s' cannot open directory: %s" % [id, dir_path])
		_frame_paths.append(file_path)
		return

	var matching_files: Array[String] = []
	da.list_dir_begin()
	var fname := da.get_next()
	while fname != "":
		if not da.current_is_dir():
			# Check: same extension, starts with prefix, rest is digits
			if fname.get_extension().to_lower() == ext.to_lower() and fname.get_basename().begins_with(prefix):
				var remainder := fname.get_basename().substr(prefix.length())
				if not remainder.is_empty() and remainder.is_valid_int():
					matching_files.append(dir_path.path_join(fname))
		fname = da.get_next()
	da.list_dir_end()

	# Sort by filename (natural order since zero-padded)
	matching_files.sort()

	_frame_paths = PackedStringArray(matching_files)
	GNLogger.info("ImageSequenceTOP", "'%s' discovered %d frames: %s...%s" % [
		id, _frame_paths.size(),
		_frame_paths[0].get_file() if not _frame_paths.is_empty() else "",
		_frame_paths[_frame_paths.size() - 1].get_file() if _frame_paths.size() > 1 else ""])

	if do_preload:
		_preload_all_frames()
	_auto_set_resolution()


## Auto-sets resolution parameter from the first frame's dimensions.
func _auto_set_resolution() -> void:
	if _frame_paths.is_empty():
		return
	var tex := _get_frame_texture(0)
	if tex and tex.get_width() > 0 and tex.get_height() > 0:
		var native_res := Vector2i(tex.get_width(), tex.get_height())
		var current_res: Vector2i = get_param_value("resolution")
		if native_res != current_res:
			set_param_value("resolution", native_res)
			if _viewport:
				_viewport.size = native_res
			GNLogger.info("ImageSequenceTOP", "'%s' resolution auto-set to %s" % [id, str(native_res)])


## Preloads all frame textures into the cache.
func _preload_all_frames() -> void:
	for fi in _frame_paths.size():
		_get_frame_texture(fi)
	GNLogger.info("ImageSequenceTOP", "'%s' preloaded %d frames" % [id, _frame_paths.size()])


## Returns a Texture2D for the given frame index, loading and caching on demand.
func _get_frame_texture(idx: int) -> Texture2D:
	if idx < 0 or idx >= _frame_paths.size():
		return null
	if _frame_cache.has(idx):
		return _frame_cache[idx] as Texture2D

	var path: String = _frame_paths[idx]
	if not ResourceLoader.exists(path):
		return null

	var loaded := ResourceLoader.load(path)
	var tex: Texture2D = null
	if loaded is Texture2D:
		tex = loaded as Texture2D
	elif loaded is Image:
		tex = ImageTexture.create_from_image(loaded as Image)

	if tex:
		_frame_cache[idx] = tex
	return tex


## Applies the loop mode to compute the actual frame index.
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
