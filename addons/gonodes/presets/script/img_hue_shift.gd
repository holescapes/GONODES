# @output img Hue-shifted image
# @input img Source image
# @param float hue_offset 0.0 Hue rotation (0-1 = 0-360 degrees)
# @param float saturation 1.0 Saturation multiplier
# @param float value_mult 1.0 Value/brightness multiplier

func cook():
	var src = inputs[0] if inputs.size() > 0 else null
	if src == null or not (src is GNImageData):
		return
	var img = src.image.duplicate() as Image
	if img == null:
		return

	var w = img.get_width()
	var h = img.get_height()
	var hue_off = par("hue_offset")
	var sat_mul = par("saturation")
	var val_mul = par("value_mult")

	for y in range(h):
		for x in range(w):
			var c = img.get_pixel(x, y)
			var hue = fmod(c.h + hue_off, 1.0)
			var sat = clampf(c.s * sat_mul, 0.0, 1.0)
			var val = clampf(c.v * val_mul, 0.0, 1.0)
			img.set_pixel(x, y, Color.from_hsv(hue, sat, val, c.a))

	op.set_image(img)
