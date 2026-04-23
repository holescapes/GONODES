# @input img Source image to analyze
# @output img  Brightness-adjusted image
# @output dat  Color statistics table
# @param float brightness 1.0 Output brightness multiplier
# @param float gamma 1.0 Gamma correction (1.0 = linear)

func cook():
	var src = inputs[0] if inputs.size() > 0 else null
	if src == null or not (src is GNImageData):
		return
	var img = src.image.duplicate() as Image
	if img == null:
		return

	var w = img.get_width()
	var h = img.get_height()
	var brt = par("brightness")
	var gam = maxf(par("gamma"), 0.01)

	var sum_r = 0.0
	var sum_g = 0.0
	var sum_b = 0.0
	var min_lum = 1.0
	var max_lum = 0.0
	var count = w * h

	for y in range(h):
		for x in range(w):
			var c = img.get_pixel(x, y)
			sum_r += c.r
			sum_g += c.g
			sum_b += c.b
			var lum = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			min_lum = minf(min_lum, lum)
			max_lum = maxf(max_lum, lum)

			var r = clampf(pow(c.r * brt, 1.0 / gam), 0.0, 1.0)
			var g = clampf(pow(c.g * brt, 1.0 / gam), 0.0, 1.0)
			var b = clampf(pow(c.b * brt, 1.0 / gam), 0.0, 1.0)
			img.set_pixel(x, y, Color(r, g, b, c.a))

	# Output 0: processed image
	outputs[0].set_image(img)

	# Output 1: statistics table
	outputs[1].set_headers(PackedStringArray(["metric", "value"]))
	outputs[1].append_row(PackedStringArray(["width", str(w)]))
	outputs[1].append_row(PackedStringArray(["height", str(h)]))
	outputs[1].append_row(PackedStringArray(["avg_red", "%.4f" % (sum_r / count)]))
	outputs[1].append_row(PackedStringArray(["avg_green", "%.4f" % (sum_g / count)]))
	outputs[1].append_row(PackedStringArray(["avg_blue", "%.4f" % (sum_b / count)]))
	outputs[1].append_row(PackedStringArray(["min_luminance", "%.4f" % min_lum]))
	outputs[1].append_row(PackedStringArray(["max_luminance", "%.4f" % max_lum]))
	outputs[1].append_row(PackedStringArray(["brightness", "%.2f" % brt]))
	outputs[1].append_row(PackedStringArray(["gamma", "%.2f" % gam]))
