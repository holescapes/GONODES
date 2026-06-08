class_name PixelSortIMG
extends GNImgBase
## CPU-side pixel sorting effect.
## Sorts spans of pixels by brightness along rows or columns, producing
## the distinctive glitch art "data-bending" look.
##
## Threshold controls which pixels start/stop a sorted span:
## only pixels whose brightness falls in [threshold_low, threshold_high]
## are sorted.  Pixels outside that range act as span boundaries.

enum SortDirection { HORIZONTAL, VERTICAL }
enum SortMode { BRIGHTNESS, HUE, SATURATION, RED, GREEN, BLUE }


func _init() -> void:
	node_type = "pixel_sort"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, false, "Input image", "In")
	add_output("out", GNFamily.Type.IMG, "Pixel-sorted image", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("direction", 0, 0, 1,
		"Direction", "0 = Horizontal (sort rows), 1 = Vertical (sort columns)"))
	add_parameter(GNParameter.create_int("sort_mode", 0, 0, 5,
		"Sort Mode", "0=Brightness 1=Hue 2=Saturation 3=Red 4=Green 5=Blue"))
	add_parameter(GNParameter.create_float("threshold_low", 0.1, 0.0, 1.0, 0.01,
		"Threshold Low", "Minimum brightness to include in a sort span"))
	add_parameter(GNParameter.create_float("threshold_high", 0.9, 0.0, 1.0, 0.01,
		"Threshold High", "Maximum brightness to include in a sort span"))
	add_parameter(GNParameter.create_bool("reverse", false,
		"Reverse", "Sort in descending order"))


func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_image()

	var src := _get_input_img(inputs, 0)
	if src == null or src.image == null:
		return out

	var direction: int = get_param_value("direction")
	var sort_mode: int = get_param_value("sort_mode")
	var threshold_low: float = get_param_value("threshold_low")
	var threshold_high: float = get_param_value("threshold_high")
	var reverse: bool = get_param_value("reverse")

	# COW: duplicate only when upstream output is shared (fan-out)
	var src_data := _mutable_input(src) as GNImageData
	var img: Image = src_data.image
	var w: int = img.get_width()
	var h: int = img.get_height()

	if w == 0 or h == 0:
		out.set_image(img)
		return out

	if direction == SortDirection.HORIZONTAL:
		for y in range(h):
			_sort_line_horizontal(img, y, w, sort_mode, threshold_low,
				threshold_high, reverse)
	else:
		for x in range(w):
			_sort_line_vertical(img, x, h, sort_mode, threshold_low,
				threshold_high, reverse)

	out.set_image(img)
	return out


func _sort_line_horizontal(img: Image, y: int, w: int, sort_mode: int,
		t_low: float, t_high: float, reverse: bool) -> void:
	# Collect pixels and their sort keys
	var pixels: Array[Color] = []
	var keys: PackedFloat32Array = PackedFloat32Array()
	pixels.resize(w)
	keys.resize(w)
	for x in range(w):
		pixels[x] = img.get_pixel(x, y)
		keys[x] = _get_sort_key(pixels[x], sort_mode)

	# Find and sort spans
	var span_start: int = -1
	for x in range(w):
		var b := _get_brightness(pixels[x])
		var in_range := b >= t_low and b <= t_high
		if in_range and span_start == -1:
			span_start = x
		elif (not in_range or x == w - 1) and span_start != -1:
			var span_end: int = x if not in_range else x + 1
			_sort_span(pixels, keys, span_start, span_end, reverse)
			span_start = -1

	# Write back
	for x in range(w):
		img.set_pixel(x, y, pixels[x])


func _sort_line_vertical(img: Image, x: int, h: int, sort_mode: int,
		t_low: float, t_high: float, reverse: bool) -> void:
	var pixels: Array[Color] = []
	var keys: PackedFloat32Array = PackedFloat32Array()
	pixels.resize(h)
	keys.resize(h)
	for y in range(h):
		pixels[y] = img.get_pixel(x, y)
		keys[y] = _get_sort_key(pixels[y], sort_mode)

	var span_start: int = -1
	for y in range(h):
		var b := _get_brightness(pixels[y])
		var in_range := b >= t_low and b <= t_high
		if in_range and span_start == -1:
			span_start = y
		elif (not in_range or y == h - 1) and span_start != -1:
			var span_end: int = y if not in_range else y + 1
			_sort_span(pixels, keys, span_start, span_end, reverse)
			span_start = -1

	for y in range(h):
		img.set_pixel(x, y, pixels[y])


## Sorts a contiguous span of the arrays in-place by key using insertion sort
## (good for the typically short spans in pixel sorting).
func _sort_span(pixels: Array[Color], keys: PackedFloat32Array,
		start: int, end: int, reverse: bool) -> void:
	if end - start <= 1:
		return
	# Insertion sort — efficient for small spans
	for i in range(start + 1, end):
		var key_i := keys[i]
		var pix_i := pixels[i]
		var j := i - 1
		if reverse:
			while j >= start and keys[j] < key_i:
				keys[j + 1] = keys[j]
				pixels[j + 1] = pixels[j]
				j -= 1
		else:
			while j >= start and keys[j] > key_i:
				keys[j + 1] = keys[j]
				pixels[j + 1] = pixels[j]
				j -= 1
		keys[j + 1] = key_i
		pixels[j + 1] = pix_i


func _get_brightness(c: Color) -> float:
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114


func _get_sort_key(c: Color, mode: int) -> float:
	match mode:
		SortMode.BRIGHTNESS:
			return c.r * 0.299 + c.g * 0.587 + c.b * 0.114
		SortMode.HUE:
			return c.h
		SortMode.SATURATION:
			return c.s
		SortMode.RED:
			return c.r
		SortMode.GREEN:
			return c.g
		SortMode.BLUE:
			return c.b
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114
