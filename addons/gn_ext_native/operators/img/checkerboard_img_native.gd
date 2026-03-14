class_name CheckerboardIMGNative
extends GNImgBase
## Native-accelerated checkerboard generator — delegates to GNNativeCheckerboardImg (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "checkerboardimg"
	node_description = "CPU checkerboard pattern generator — native C++ accelerated."
	if ClassDB.class_exists("GNNativeCheckerboardImg"):
		_processor = ClassDB.instantiate("GNNativeCheckerboardImg")


func _init_ports() -> void:
	add_output("out", GNFamily.Type.IMG, "Checkerboard image")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(256, 256),
		"Resolution", "Output image size in pixels"))
	add_parameter(GNParameter.create_int("cells_x", 8, 1, 256,
		"Cells X", "Number of cells horizontally"))
	add_parameter(GNParameter.create_int("cells_y", 8, 1, 256,
		"Cells Y", "Number of cells vertically"))
	add_parameter(GNParameter.create_color("color_a", Color.WHITE,
		"Color A", "First checker color"))
	add_parameter(GNParameter.create_color("color_b", Color.BLACK,
		"Color B", "Second checker color"))
	add_parameter(GNParameter.create_float("softness", 0.0, 0.0, 1.0, 0.01,
		"Softness", "Anti-aliasing softness at cell edges (0 = hard)"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var res: Vector2i = get_param_value("resolution")
	var cells_x: int = get_param_value("cells_x")
	var cells_y: int = get_param_value("cells_y")
	var col_a: Color = get_param_value("color_a")
	var col_b: Color = get_param_value("color_b")
	var softness: float = get_param_value("softness")

	var result_image: Image
	if _processor != null:
		result_image = _processor.process(res.x, res.y, cells_x, cells_y,
			col_a, col_b, softness)
	else:
		result_image = _checkerboard_gdscript(res, cells_x, cells_y,
			col_a, col_b, softness)

	if result_image == null:
		return null

	var out := _prepare_image()
	out.image = result_image
	out.resolution = Vector2i(result_image.get_width(), result_image.get_height())
	out.format = result_image.get_format()
	return out


func _checkerboard_gdscript(res: Vector2i, cells_x: int, cells_y: int,
		col_a: Color, col_b: Color, softness: float) -> Image:
	var img := Image.create(res.x, res.y, false, Image.FORMAT_RGBA8)
	var cell_w: float = float(res.x) / float(maxi(cells_x, 1))
	var cell_h: float = float(res.y) / float(maxi(cells_y, 1))

	if softness <= 0.001:
		for y in range(res.y):
			var row: int = int(float(y) / cell_h)
			for x in range(res.x):
				var col: int = int(float(x) / cell_w)
				if (row + col) % 2 == 0:
					img.set_pixel(x, y, col_a)
				else:
					img.set_pixel(x, y, col_b)
	else:
		var edge_width: float = softness * minf(cell_w, cell_h) * 0.5
		for y in range(res.y):
			var fy: float = float(y) / cell_h
			for x in range(res.x):
				var fx: float = float(x) / cell_w
				var tx := absf(fmod(fx, 2.0) - 1.0)
				var ty := absf(fmod(fy, 2.0) - 1.0)
				var checker := tx * 2.0 - 1.0
				checker *= ty * 2.0 - 1.0
				var half := edge_width / minf(cell_w, cell_h)
				var t := clampf((checker / maxf(half, 0.001) + 1.0) * 0.5, 0.0, 1.0)
				t = t * t * (3.0 - 2.0 * t)
				img.set_pixel(x, y, col_a.lerp(col_b, t))

	return img
