class_name ImageFileInIMG
extends GNImgBase
## Loads an image file from the project as a CPU-side Image.
##
## Pure CPU buffer — no SubViewport.  Supported formats: PNG, JPG, WebP, BMP,
## TGA, SVG, HDR, EXR, KTX/KTX2 (ETC2 and other VRAM-compressed formats when
## present), and Godot texture resources (.tres/.res).
##
## KTX2/ETC2 Images stay compressed until ImgToTOP uploads them — on GLES/
## mobile GPUs that support ETC2 this is a GPU-native path (no pixel decode).
## Resizing a compressed image decompresses it first (CPU cost).
##
## The **file** parameter also accepts HTTP/HTTPS URLs.  When a URL is provided,
## the image is fetched asynchronously via GNUrlCache, cached on disk, and loaded
## on the next cook once the download completes.
##
## When **async_load** is ON, disk loads run on a worker thread; the previous
## good image (if any) is held until the new path is ready.  While a load is
## in flight the node sets [member GNNode.keep_dirty_after_cook] so the next
## cook frame picks up the result without blanket [member time_dependent].
##
## Chain → ImgToTOP if you need a GPU texture downstream.

## Path of the currently loaded file — avoids reloading every cook.
var _loaded_file_path: String = ""

## Cached CPU image to avoid reloading when path hasn't changed.
var _loaded_image: Image = null

## Async load state.
var _async_path: String = ""
var _async_pending: bool = false
var _async_result: Image = null
var _async_mutex: Mutex = Mutex.new()
var _async_thread: Thread = null
var _load_ready: bool = false


func _init() -> void:
	node_type = "image_file_in"
	thread_safe = false  # URL fetching / thread join uses main-thread ownership


func _init_ports() -> void:
	add_output("out", GNFamily.Type.IMG, "Loaded CPU image")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_file("file", "",
		PackedStringArray(["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.tga",
			"*.svg", "*.hdr", "*.exr", "*.ktx", "*.ktx2", "*.tres", "*.res"]),
		"File", "Image or texture file path (KTX/KTX2 keeps ETC2 when present)."))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(0, 0),
		"Resolution", "Resize to this resolution. (0, 0) = native size."))
	add_parameter(GNParameter.create_bool("async_load", false,
		"Async Load", "Load from disk on a background thread; hold last image until ready."))
	add_parameter(GNParameter.create_bool("reload", false,
		"Reload", "Force reload from disk on next cook (auto-resets to false)."))


func _cook(_inputs: Array[GNData]) -> GNData:
	var out := _prepare_image()

	var file_path: String = get_param_value("file")
	var res: Vector2i = get_param_value("resolution")
	var force_reload: bool = get_param_value("reload")
	var async_load: bool = get_param_value("async_load")

	# Force reload acts as a pulse — reset immediately.
	if force_reload:
		set_param_value("reload", false)
		_loaded_file_path = ""
		_loaded_image = null
		_cancel_async()

	# URL support — fetch via cache, cook with local path once ready
	if GNUrlCache.is_url(file_path):
		var result: Dictionary = GNUrlCache.resolve_url(file_path, self)
		match result.status:
			"ready":
				file_path = result.path
			"pending":
				_load_ready = false
				# Re-queue next frame — execute_cook clears dirty after _cook
				request_keep_dirty()
				return out
			"error":
				GNLogger.warn("ImageFileInIMG", "'%s' — URL fetch error: %s" % [id, result.error])
				_load_ready = false
				return out

	# Apply finished async job (if any) before deciding whether to kick a new one
	_poll_async()

	# Load image if path changed.
	if file_path != _loaded_file_path:
		if async_load and not file_path.is_empty():
			_start_async_load(file_path)
			_loaded_file_path = file_path  # claim path; image may arrive later
			_load_ready = false
		else:
			_cancel_async()
			_loaded_image = _load_image(file_path)
			_loaded_file_path = file_path
			_load_ready = _loaded_image != null
			if _loaded_image != null and res == Vector2i.ZERO:
				var native := Vector2i(_loaded_image.get_width(), _loaded_image.get_height())
				if native.x > 0 and native.y > 0:
					set_param_value("resolution", native)
					res = native

	# Not time_dependent — re-queue while a worker load is in flight.
	# keep_dirty_after_cook survives execute_cook's clear_dirty (and resets
	# the input-hash guard so the follow-up cook is not skipped).
	if _is_async_pending():
		node_warning = "Loading…"
		request_keep_dirty()
		if _loaded_image == null:
			return out
		# else fall through and hold the previous good image

	if _loaded_image == null:
		_load_ready = false
		return out

	_load_ready = true
	node_warning = ""

	# Work on a copy so the cached source isn't mutated by resize.
	var img := _loaded_image.duplicate() as Image

	# Resize if a non-zero resolution is requested and differs from native.
	if res != Vector2i.ZERO and Vector2i(img.get_width(), img.get_height()) != res:
		img = GNResourceLoader.ensure_cpu_editable_image(img)
		img.resize(res.x, res.y, Image.INTERPOLATE_BILINEAR)

	out.set_image(img)
	return out


func is_load_ready() -> bool:
	return _load_ready and _loaded_image != null


# ─── File Loading ──────────────────────────────────────────────────────────────

func _load_image(file_path: String) -> Image:
	if file_path.is_empty():
		return null

	var img := GNResourceLoader.load_image(file_path, project_dir)
	if img != null:
		GNLogger.info("ImageFileInIMG",
			"'%s': loaded Image: %s (%dx%d)" % [
				id, file_path, img.get_width(), img.get_height()])
	else:
		GNLogger.warn("ImageFileInIMG",
			"'%s': file not found or invalid: %s" % [id, file_path])
	return img


# ─── Async disk load ───────────────────────────────────────────────────────────

func _is_async_pending() -> bool:
	_async_mutex.lock()
	var pending: bool = _async_pending
	_async_mutex.unlock()
	return pending


func _start_async_load(path: String) -> void:
	_cancel_async()
	_async_mutex.lock()
	_async_path = path
	_async_pending = true
	_async_result = null
	_async_mutex.unlock()
	var proj: String = project_dir
	_async_thread = Thread.new()
	_async_thread.start(func():
		var img: Image = GNResourceLoader.load_image(path, proj)
		_async_mutex.lock()
		_async_result = img
		_async_pending = false
		_async_mutex.unlock()
	)


func _poll_async() -> void:
	_async_mutex.lock()
	var pending: bool = _async_pending
	var result: Image = _async_result
	var path: String = _async_path
	_async_mutex.unlock()

	if pending:
		return

	# Join finished worker (must be on main / cook thread)
	if _async_thread != null and not _async_thread.is_alive():
		_async_thread.wait_to_finish()
		_async_thread = null

	if path.is_empty():
		return

	if result != null and path == _loaded_file_path:
		_loaded_image = result
		_async_mutex.lock()
		_async_result = null
		_async_path = ""
		_async_mutex.unlock()
		_load_ready = true
		var res: Vector2i = get_param_value("resolution")
		if res == Vector2i.ZERO:
			var native := Vector2i(_loaded_image.get_width(), _loaded_image.get_height())
			if native.x > 0 and native.y > 0:
				set_param_value("resolution", native)
		GNLogger.info("ImageFileInIMG",
			"'%s': async loaded %s (%dx%d)" % [
				id, path, _loaded_image.get_width(), _loaded_image.get_height()])
	elif result == null and path == _loaded_file_path \
			and _async_thread == null and _loaded_image == null:
		node_warning = "Load failed: %s" % path
		_async_mutex.lock()
		_async_path = ""
		_async_mutex.unlock()


func _cancel_async() -> void:
	if _async_thread != null:
		if _async_thread.is_alive():
			_async_thread.wait_to_finish()
		_async_thread = null
	_async_mutex.lock()
	_async_pending = false
	_async_result = null
	_async_path = ""
	_async_mutex.unlock()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cancel_async()
