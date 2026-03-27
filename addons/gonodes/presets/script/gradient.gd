# @param vec2i resolution 256,256 Output image size
# @param color color_a #ff0000 Gradient start color
# @param color color_b #0000ff Gradient end color
# @param bool vertical false Gradient direction (false=horizontal)

func cook():
	var res = par("resolution")
	var img = Image.create(res.x, res.y, false, Image.FORMAT_RGBA8)
	var ca = par("color_a")
	var cb = par("color_b")
	var vert = par("vertical")

	for y in range(res.y):
		for x in range(res.x):
			var t = float(y) / float(res.y) if vert else float(x) / float(res.x)
			img.set_pixel(x, y, ca.lerp(cb, t))

	op.set_image(img)
