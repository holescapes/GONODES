class_name ImageFileInIMG
extends GNImgBase
## Loads an image file from the project as a CPU-side Image.
##
## Pure CPU — no SubViewport, no GPU upload.  All Godot-importable image
## formats are supported: PNG, JPG, WebP, BMP, TGA, SVG, HDR, EXR,
## and Godot texture resources (.tres/.res).
##
## The **file** parameter also accepts HTTP/HTTPS URLs.  When a URL is provided,
## the image is fetched asynchronously via GNUrlCache, cached on disk, and loaded
## on the next cook once the download completes.
##
## Chain → ImgToTOP if you need a GPU texture downstream.

## Path of the currently loaded file — avoids reloading every cook.
var _loaded_file_path: String = ""

## Cached CPU image to avoid reloading when path hasn't changed.
var _loaded_image: Image = null


func _init() -> void:
	node_type = "image_file_in"
	thread_safe = false  # URL fetching uses HTTPRequest / scene tree


func _init_ports() -> void:
	add_output("out", GNFamily.Type.IMG, "Loaded CPU image")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_file("file", "Path to the file",
		PackedStringArray(["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.tga",
			"*.svg", "*.hdr", "*.exr", "*.tres", "*.res"]),
		"", "Image or texture file path."))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(0, 0),
		"Resolution", "Resize to this resolution. (0, 0) = native size."))
	add_parameter(GNParameter.create_bool("reload", false,
		"Reload", "Force reload from disk on next cook (auto-resets to false)."))


func _cook(_inputs: Array[GNData]) -> GNData:
	var out := _prepare_image()

	var file_path: String = get_param_value("file")
	var res: Vector2i = get_param_value("resolution")
	var force_reload: bool = get_param_value("reload")

	# Force reload acts as a pulse — reset immediately.
	if force_reload:
		set_param_value("reload", false)
		_loaded_file_path = ""
		_loaded_image = null

	# URL support — fetch via cache, cook with local path once ready
	if GNUrlCache.is_url(file_path):
		var result: Dictionary = GNUrlCache.resolve_url(file_path, self)
		match result.status:
			"ready":
				file_path = result.path
			"pending":
				return out  # placeholder until download completes
			"error":
				GNLogger.warn("ImageFileInIMG", "'%s' — URL fetch error: %s" % [id, result.error])
				return out

	# Load image if path changed.
	if file_path != _loaded_file_path:
		_loaded_image = _load_image(file_path)
		_loaded_file_path = file_path

		# Auto-set resolution from native size on first load.
		if _loaded_image != null and res == Vector2i.ZERO:
			var native := Vector2i(_loaded_image.get_width(), _loaded_image.get_height())
			if native.x > 0 and native.y > 0:
				set_param_value("resolution", native)
				res = native

	if _loaded_image == null:
		return out

	# Work on a copy so the cached source isn't mutated by resize.
	# (This is a local cache, not an upstream shared output, so always copy.)
	var img := _loaded_image.duplicate() as Image

	# Resize if a non-zero resolution is requested and differs from native.
	if res != Vector2i.ZERO and Vector2i(img.get_width(), img.get_height()) != res:
		img.resize(res.x, res.y, Image.INTERPOLATE_BILINEAR)

	out.set_image(img)
	return out


# ─── File Loading ──────────────────────────────────────────────────────────────

## Loads an image from the given path, handling both Image and Texture2D
## resources. Returns null on failure.
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
