class_name CheckerboardIMG
extends GNImgBase
## CPU-side checkerboard pattern generator.
## Produces a 2-color grid of configurable cell size.

func _init() -> void:
	node_type = "checkerboard"
	node_description = "CPU checkerboard pattern generator."


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
	var out := _prepare_image()

	var res: Vector2i = get_param_value("resolution")
	var cells_x: int = get_param_value("cells_x")
	var cells_y: int = get_param_value("cells_y")
	var col_a: Color = get_param_value("color_a")
	var col_b: Color = get_param_value("color_b")
	var softness: float = get_param_value("softness")

	var img := Image.create(res.x, res.y, false, Image.FORMAT_RGBA8)

	var cell_w: float = float(res.x) / float(maxi(cells_x, 1))
	var cell_h: float = float(res.y) / float(maxi(cells_y, 1))

	if softness <= 0.001:
		# Hard-edge checkerboard (fast path)
		for y in range(res.y):
			var row: int = int(float(y) / cell_h)
			for x in range(res.x):
				var col: int = int(float(x) / cell_w)
				if (row + col) % 2 == 0:
					img.set_pixel(x, y, col_a)
				else:
					img.set_pixel(x, y, col_b)
	else:
		# Soft-edge checkerboard
		var edge_width: float = softness * minf(cell_w, cell_h) * 0.5
		for y in range(res.y):
			var fy: float = float(y) / cell_h
			for x in range(res.x):
				var fx: float = float(x) / cell_w
				# Compute smooth checkerboard via triangle waves
				var tx := absf(fmod(fx, 2.0) - 1.0)
				var ty := absf(fmod(fy, 2.0) - 1.0)
				# Product of two triangle waves → checkerboard
				var checker := tx * 2.0 - 1.0
				checker *= ty * 2.0 - 1.0
				# Smoothstep at zero crossing
				var half := edge_width / minf(cell_w, cell_h)
				var t := clampf((checker / maxf(half, 0.001) + 1.0) * 0.5, 0.0, 1.0)
				# Smoothstep
				t = t * t * (3.0 - 2.0 * t)
				img.set_pixel(x, y, col_a.lerp(col_b, t))

	out.set_image(img)
	return out
