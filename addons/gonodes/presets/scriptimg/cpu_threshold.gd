# @input img Source image to process
# @param float threshold 0.5 Brightness threshold (0-1)
# @param color true_color #ffffff Color for pixels above threshold
# @param color false_color #000000 Color for pixels below threshold

func cook():
	var img_in = inputs[0] if inputs.size() > 0 else null
	if img_in == null or not (img_in is GNImageData) or img_in.image == null:
		return

	var src_img = img_in.image
	var res = Vector2i(src_img.get_width(), src_img.get_height())
	var img = Image.create(res.x, res.y, false, Image.FORMAT_RGBA8)
	var thr = par("threshold")
	var tc = par("true_color")
	var fc = par("false_color")

	for y in range(res.y):
		for x in range(res.x):
			var pixel = src_img.get_pixel(x, y)
			var brightness = pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114
			img.set_pixel(x, y, tc if brightness >= thr else fc)

	op.set_image(img)
