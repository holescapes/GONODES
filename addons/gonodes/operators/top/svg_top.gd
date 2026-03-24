class_name SVGTOP
extends GNTopBase
## Renders an SVG file or inline SVG markup to a texture.
## Uses Godot's built-in SVG import for rasterization at arbitrary resolution.

var _image_texture: ImageTexture = null
var _last_path: String = ""
var _last_res: Vector2i = Vector2i.ZERO


func _init() -> void:
	node_type = "svg"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Rendered SVG texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "",
		"Output texture resolution"))
	add_parameter(GNParameter.create_string("svg_path", "", "SVG File",
		"Path to an .svg file (res:// or user://)"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var res: Vector2i = get_param_value("resolution")
	var svg_path: String = get_param_value("svg_path")

	_ensure_viewport(res)
	if _viewport.size != res:
		_viewport.size = res

	if svg_path.is_empty() or not FileAccess.file_exists(svg_path):
		_cached_tex_data.resolution = res
		return _cached_tex_data

	# Only reload when path or resolution changes
	if svg_path != _last_path or res != _last_res:
		var img := Image.new()
		var err: int = img.load(svg_path)
		if err != OK:
			GNLogger.warn("SVGTOP", "'%s' — failed to load SVG: %s" % [id, svg_path])
			_cached_tex_data.resolution = res
			return _cached_tex_data

		img.resize(res.x, res.y, Image.INTERPOLATE_LANCZOS)

		if _image_texture == null:
			_image_texture = ImageTexture.create_from_image(img)
		else:
			_image_texture.update(img)

		_last_path = svg_path
		_last_res = res

	if _image_texture != null:
		_cached_tex_data.texture = _image_texture

	_cached_tex_data.resolution = res
	return _cached_tex_data
