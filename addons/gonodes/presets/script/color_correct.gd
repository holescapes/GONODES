# @output img Output image
# @input img Source image to process
# @param float contrast 1.5 Contrast multiplier
# @param float brightness 0.0 Brightness offset (-1 to 1)
# @param float saturation 1.0 Saturation multiplier

func cook():
	var src = inputs[0] if inputs.size() > 0 else null
	if src == null or not (src is GNImageData):
		return
	var img = src.image.duplicate() as Image
	if img == null:
		return

	var contrast = par("contrast")
	var bright = par("brightness")
	var sat = par("saturation")

	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c = img.get_pixel(x, y)
			# Brightness
			c.r = clampf(c.r + bright, 0.0, 1.0)
			c.g = clampf(c.g + bright, 0.0, 1.0)
			c.b = clampf(c.b + bright, 0.0, 1.0)
			# Contrast around midpoint
			c.r = clampf((c.r - 0.5) * contrast + 0.5, 0.0, 1.0)
			c.g = clampf((c.g - 0.5) * contrast + 0.5, 0.0, 1.0)
			c.b = clampf((c.b - 0.5) * contrast + 0.5, 0.0, 1.0)
			# Saturation
			var gray = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			c.r = clampf(lerpf(gray, c.r, sat), 0.0, 1.0)
			c.g = clampf(lerpf(gray, c.g, sat), 0.0, 1.0)
			c.b = clampf(lerpf(gray, c.b, sat), 0.0, 1.0)
			img.set_pixel(x, y, c)

	op.set_image(img)
