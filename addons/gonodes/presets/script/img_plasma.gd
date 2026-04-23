# @output img Animated plasma texture
# @param vec2i resolution 256,256 Output size
# @param float scale 3.0 Pattern scale
# @param float speed 1.0 Animation speed
# @param float contrast 1.5 Color contrast

func cook():
	var res = par("resolution")
	var img = Image.create(res.x, res.y, false, Image.FORMAT_RGBA8)
	var sc = par("scale")
	var t = time * par("speed")
	var con = par("contrast")

	for y in range(res.y):
		for x in range(res.x):
			var u = float(x) / float(res.x) * sc
			var v = float(y) / float(res.y) * sc

			var v1 = sin(u * 3.0 + t)
			var v2 = sin(v * 4.0 - t * 0.7)
			var v3 = sin((u + v) * 2.5 + t * 1.3)
			var v4 = sin(sqrt(u * u + v * v) * 5.0 - t * 0.5)
			var val = (v1 + v2 + v3 + v4) * 0.25

			var r = clampf((sin(val * TAU) * 0.5 + 0.5) * con, 0.0, 1.0)
			var g = clampf((sin(val * TAU + TAU / 3.0) * 0.5 + 0.5) * con, 0.0, 1.0)
			var b = clampf((sin(val * TAU + TAU * 2.0 / 3.0) * 0.5 + 0.5) * con, 0.0, 1.0)
			img.set_pixel(x, y, Color(r, g, b, 1.0))

	op.set_image(img)
