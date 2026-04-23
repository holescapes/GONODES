# @output img Output image
# @param vec2i resolution 256,256 Output image size
# @param float scale 4.0 Noise scale
# @param int octaves 4 Number of octaves
# @param float persistence 0.5 Amplitude reduction per octave
# @param float speed 0.5 Animation speed

func cook():
	var res = par("resolution")
	var img = Image.create(res.x, res.y, false, Image.FORMAT_RGBA8)

	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 1.0 / maxf(par("scale"), 0.01) * 0.01
	noise.fractal_octaves = par("octaves")
	noise.fractal_gain = par("persistence")

	var t = time * par("speed")

	for y in range(res.y):
		for x in range(res.x):
			var nx = float(x) / float(res.x) * par("scale")
			var ny = float(y) / float(res.y) * par("scale")
			var v = noise.get_noise_3d(nx, ny, t) * 0.5 + 0.5
			img.set_pixel(x, y, Color(v, v, v, 1.0))

	op.set_image(img)
