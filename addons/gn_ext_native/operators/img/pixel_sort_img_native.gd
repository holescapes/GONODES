class_name PixelSortIMGNative
extends GNImgBase
## Native-accelerated pixel sort — delegates to GNNativePixelSort (C++)
## when available, falls back to pure GDScript otherwise.

var _processor: RefCounted = null


func _init() -> void:
	node_type = "pixelsort"
	node_description = "Pixel-sorting glitch effect (native C++ accelerated)."
	if ClassDB.class_exists("GNNativePixelSort"):
		_processor = ClassDB.instantiate("GNNativePixelSort")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, true, "Source image")
	add_output("out", GNFamily.Type.IMG, "Pixel-sorted image")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("direction", 0, 0, 1,
		"Direction", "0 = Horizontal, 1 = Vertical"))
	add_parameter(GNParameter.create_int("sort_mode", 0, 0, 5,
		"Sort Mode", "0=Brightness, 1=Hue, 2=Saturation, 3=Red, 4=Green, 5=Blue"))
	add_parameter(GNParameter.create_float("threshold_low", 0.25, 0.0, 1.0, 0.01,
		"Threshold Low", "Minimum brightness to include in a span"))
	add_parameter(GNParameter.create_float("threshold_high", 0.8, 0.0, 1.0, 0.01,
		"Threshold High", "Maximum brightness to include in a span"))
	add_parameter(GNParameter.create_bool("reverse", false,
		"Reverse", "Sort spans in descending order"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_img: GNImageData = _get_input_img(inputs, 0)
	if in_img == null or in_img.image == null:
		return null

	var direction: int = get_param_value("direction")
	var sort_mode: int = get_param_value("sort_mode")
	var threshold_low: float = get_param_value("threshold_low")
	var threshold_high: float = get_param_value("threshold_high")
	var reverse: bool = get_param_value("reverse")

	var result_image: Image
	if _processor != null:
		result_image = _processor.process(in_img.image, direction, sort_mode,
			threshold_low, threshold_high, reverse)
	else:
		result_image = _sort_gdscript(in_img.image, direction, sort_mode,
			threshold_low, threshold_high, reverse)

	if result_image == null:
		return null

	var out := _prepare_image()
	out.image = result_image
	out.resolution = Vector2i(result_image.get_width(), result_image.get_height())
	out.format = result_image.get_format()
	return out


func _sort_gdscript(img: Image, direction: int, sort_mode: int,
		thr_low: float, thr_high: float, reverse: bool) -> Image:
	var result := img.duplicate() as Image
	var w := result.get_width()
	var h := result.get_height()
	var outer := h if direction == 0 else w
	var inner := w if direction == 0 else h

	for line in range(outer):
		var colors: Array[Color] = []
		var keys := PackedFloat32Array()
		colors.resize(inner)
		keys.resize(inner)
		for i in range(inner):
			var px: int = i if direction == 0 else line
			var py: int = line if direction == 0 else i
			colors[i] = result.get_pixel(px, py)
			keys[i] = _get_sort_key(colors[i], sort_mode)

		# Detect spans within threshold
		var i := 0
		while i < inner:
			var bright: float = _brightness(colors[i])
			if bright < thr_low or bright > thr_high:
				i += 1
				continue
			var span_start := i
			while i < inner:
				bright = _brightness(colors[i])
				if bright < thr_low or bright > thr_high:
					break
				i += 1
			# Sort span by insertion sort
			for j in range(span_start + 1, i):
				var kj := keys[j]
				var cj := colors[j]
				var k := j - 1
				while k >= span_start and ((not reverse and keys[k] > kj) or (reverse and keys[k] < kj)):
					keys[k + 1] = keys[k]
					colors[k + 1] = colors[k]
					k -= 1
				keys[k + 1] = kj
				colors[k + 1] = cj

		# Write back
		for idx in range(inner):
			var px: int = idx if direction == 0 else line
			var py: int = line if direction == 0 else idx
			result.set_pixel(px, py, colors[idx])
	return result


static func _brightness(c: Color) -> float:
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114


static func _get_sort_key(c: Color, mode: int) -> float:
	match mode:
		0: return _brightness(c)
		1: return c.h
		2: return c.s
		3: return c.r
		4: return c.g
		5: return c.b
	return _brightness(c)
