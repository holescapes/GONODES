class_name NoiseIMG
extends GNImgBase
## CPU-side procedural noise image generator.
## Supports Perlin-like value noise and white noise.
## For GPU noise textures, use NoiseTOP instead.

enum NoiseType { VALUE, WHITE }

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	node_type = "noise"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.IMG, "Noise image")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(256, 256),
		"Resolution", "Output image size in pixels"))
	add_parameter(GNParameter.create_int("type", 0, 0, 1,
		"Noise Type", "0 = Value noise (smooth), 1 = White noise (random)"))
	add_parameter(GNParameter.create_float("scale", 4.0, 0.01, 100.0, 0.1,
		"Scale", "Spatial frequency of the noise (lower = larger features)"))
	add_parameter(GNParameter.create_float("offset_x", 0.0, null, null, 0.1,
		"Offset X", "Horizontal offset (animate for scrolling)"))
	add_parameter(GNParameter.create_float("offset_y", 0.0, null, null, 0.1,
		"Offset Y", "Vertical offset (animate for scrolling)"))
	add_parameter(GNParameter.create_int("octaves", 4, 1, 8,
		"Octaves", "Number of noise layers (value noise only)"))
	add_parameter(GNParameter.create_float("persistence", 0.5, 0.0, 1.0, 0.01,
		"Persistence", "Amplitude falloff per octave (value noise only)"))
	add_parameter(GNParameter.create_int("seed", 0, 0, 99999,
		"Seed", "Random seed"))
	add_parameter(GNParameter.create_bool("monochrome", true,
		"Monochrome", "True = grayscale, False = RGB noise"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var out := _prepare_image()

	var res: Vector2i = get_param_value("resolution")
	var noise_type: int = get_param_value("type")
	var scale: float = get_param_value("scale")
	var off_x: float = get_param_value("offset_x")
	var off_y: float = get_param_value("offset_y")
	var octaves: int = get_param_value("octaves")
	var persistence: float = get_param_value("persistence")
	var seed_val: int = get_param_value("seed")
	var mono: bool = get_param_value("monochrome")

	var img := Image.create(res.x, res.y, false, Image.FORMAT_RGBA8)

	if noise_type == NoiseType.WHITE:
		_rng.seed = seed_val
		_generate_white_noise(img, res, mono)
	else:
		_generate_value_noise(img, res, scale, off_x, off_y, octaves, persistence,
			seed_val, mono)

	out.set_image(img)
	return out


func _generate_white_noise(img: Image, res: Vector2i, mono: bool) -> void:
	for y in range(res.y):
		for x in range(res.x):
			if mono:
				var v := _rng.randf()
				img.set_pixel(x, y, Color(v, v, v, 1.0))
			else:
				img.set_pixel(x, y, Color(_rng.randf(), _rng.randf(), _rng.randf(), 1.0))


func _generate_value_noise(img: Image, res: Vector2i, scale: float,
		off_x: float, off_y: float, octaves: int, persistence: float,
		seed_val: int, mono: bool) -> void:
	# Use Godot's built-in FastNoiseLite for multi-octave value noise
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.seed = seed_val
	noise.frequency = scale / float(maxi(res.x, 1))
	noise.fractal_octaves = octaves
	noise.fractal_gain = persistence

	var noise_g: FastNoiseLite = null
	var noise_b: FastNoiseLite = null
	if not mono:
		noise_g = FastNoiseLite.new()
		noise_g.noise_type = FastNoiseLite.TYPE_SIMPLEX
		noise_g.seed = seed_val + 1000
		noise_g.frequency = noise.frequency
		noise_g.fractal_octaves = octaves
		noise_g.fractal_gain = persistence
		noise_b = FastNoiseLite.new()
		noise_b.noise_type = FastNoiseLite.TYPE_SIMPLEX
		noise_b.seed = seed_val + 2000
		noise_b.frequency = noise.frequency
		noise_b.fractal_octaves = octaves
		noise_b.fractal_gain = persistence

	for y in range(res.y):
		for x in range(res.x):
			var nx := float(x) + off_x * float(res.x)
			var ny := float(y) + off_y * float(res.y)
			# FastNoiseLite returns -1..1, remap to 0..1
			var r := noise.get_noise_2d(nx, ny) * 0.5 + 0.5
			if mono:
				img.set_pixel(x, y, Color(r, r, r, 1.0))
			else:
				var g := noise_g.get_noise_2d(nx, ny) * 0.5 + 0.5
				var b := noise_b.get_noise_2d(nx, ny) * 0.5 + 0.5
				img.set_pixel(x, y, Color(r, g, b, 1.0))
