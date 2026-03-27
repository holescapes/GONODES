# @param vec2i resolution 256,256 Output image size
# @param int rings 8 Number of concentric rings
# @param float thickness 0.3 Ring line thickness (0-1)
# @param float speed 1.0 Rotation speed

func cook():
	var res := par("resolution")
	var img := Image.create(res.x, res.y, false, Image.FORMAT_RGBA8)
	var cx := res.x * 0.5
	var cy := res.y * 0.5
	var max_r := minf(cx, cy)
	var n_rings := par("rings")
	var thick := clampf(par("thickness"), 0.01, 1.0) * 0.5
	var t := time * par("speed")

	for y in range(res.y):
		for x in range(res.x):
			var dx := float(x) - cx
			var dy := float(y) - cy
			var dist := sqrt(dx * dx + dy * dy) / max_r
			var angle := atan2(dy, dx) + t

			# Concentric ring pattern
			var ring_val := fmod(dist * n_rings, 1.0)
			var ring := 1.0 if absf(ring_val - 0.5) < thick else 0.0

			# Angular spoke pattern blended
			var spoke := (sin(angle * 6.0) * 0.5 + 0.5) * 0.3

			var v := clampf(ring + spoke, 0.0, 1.0)
			var col := Color(v * 0.6, v * 0.8, v, 1.0)
			img.set_pixel(x, y, col)

	op.set_image(img)
