class_name ImageFileInTOP
extends GNTopBase
## Loads an image or texture resource from the project and outputs it as a TOP texture.
## Similar to TouchDesigner's Movie File In TOP for still images.
##
## Supports all Godot-importable image formats: PNG, JPG, WebP, BMP, TGA, SVG,
## HDR, EXR, and Godot texture resources (.tres/.res).
## The image is rendered into a SubViewport via TextureRect for resolution control.

var _tex_rect: TextureRect = null
var _bg: ColorRect = null
var _loaded_file_path: String = ""
var _loaded_texture: Texture2D = null


func _init() -> void:
	node_type = "imagefilein"
	node_description = "Loads an image/texture from project resources (PNG, JPG, WebP, HDR, EXR, SVG, etc.)."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Loaded image texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_file("file", "",
		PackedStringArray(["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.tga",
			"*.svg", "*.hdr", "*.exr", "*.tres", "*.res"]),
		"", "Image or texture file path. Must be inside the project directory."))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "",
		"Output resolution. Image is fit into this size."))
	add_parameter(GNParameter.create_enum("fit_mode",
		PackedStringArray(["Stretch", "Keep Aspect", "Keep Aspect Centered",
			"Keep Aspect Covered", "Tile"]),
		2, "", "How the image fits into the output resolution"))
	add_parameter(GNParameter.create_color("bg_color", Color.BLACK, "",
		"Background color visible behind transparent or non-covering images"))
	add_parameter(GNParameter.create_bool("filter", true, "",
		"Enable bilinear filtering (smooth scaling). Off = nearest-neighbor (pixelated)."))


func _cook(_inputs: Array[GNData]) -> GNData:
	_setup_viewport()

	var file_path: String = get_param_value("file")
	var res: Vector2i = get_param_value("resolution")
	var fit: int = get_param_value("fit_mode")
	var bg_col: Color = get_param_value("bg_color")
	var do_filter: bool = get_param_value("filter")

	# Update viewport size
	if _viewport.size != res:
		_viewport.size = res

	_bg.color = bg_col

	# Load image if path changed
	_apply_image_file(file_path)

	# Fit mode → TextureRect stretch_mode
	match fit:
		0:
			_tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
		1:
			_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		2:
			_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		3:
			_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		4:
			_tex_rect.stretch_mode = TextureRect.STRETCH_TILE

	# Filtering
	if do_filter:
		_tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	else:
		_tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

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

	# TextureRect for displaying the loaded image
	_tex_rect = TextureRect.new()
	_tex_rect.name = "ImageRect"
	_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_viewport.add_child(_tex_rect)
	_tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _apply_image_file(file_path: String) -> void:
	if file_path == _loaded_file_path:
		return
	_loaded_file_path = file_path

	if file_path.is_empty():
		_tex_rect.texture = null
		_loaded_texture = null
		GNLogger.debug("ImageFileInTOP", "'%s' cleared image" % id)
		return

	if not ResourceLoader.exists(file_path):
		GNLogger.warn("ImageFileInTOP", "'%s' image file not found: %s" % [id, file_path])
		_tex_rect.texture = null
		_loaded_texture = null
		return

	var loaded := ResourceLoader.load(file_path)
	if loaded is Texture2D:
		_loaded_texture = loaded as Texture2D
		_tex_rect.texture = _loaded_texture
		# Auto-set resolution to match the source image dimensions
		var native_res := Vector2i(_loaded_texture.get_width(), _loaded_texture.get_height())
		if native_res.x > 0 and native_res.y > 0:
			var current_res: Vector2i = get_param_value("resolution")
			if native_res != current_res:
				set_param_value("resolution", native_res)
				if _viewport:
					_viewport.size = native_res
		GNLogger.info("ImageFileInTOP", "'%s' loaded texture: %s (%dx%d)" % [
			id, file_path, _loaded_texture.get_width(), _loaded_texture.get_height()])
	elif loaded is Image:
		# Raw Image — convert to ImageTexture
		var img := loaded as Image
		_loaded_texture = ImageTexture.create_from_image(img)
		_tex_rect.texture = _loaded_texture
		# Auto-set resolution to match source
		var native_res := Vector2i(img.get_width(), img.get_height())
		if native_res.x > 0 and native_res.y > 0:
			var current_res: Vector2i = get_param_value("resolution")
			if native_res != current_res:
				set_param_value("resolution", native_res)
				if _viewport:
					_viewport.size = native_res
		GNLogger.info("ImageFileInTOP", "'%s' loaded image: %s (%dx%d)" % [
			id, file_path, img.get_width(), img.get_height()])
	else:
		GNLogger.warn("ImageFileInTOP", "'%s' resource is not a Texture2D or Image: %s" % [
			id, file_path])
		_tex_rect.texture = null
		_loaded_texture = null
