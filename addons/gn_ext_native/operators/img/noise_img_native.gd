class_name NoiseIMGNative
extends GNImgBase
## Native-accelerated procedural noise generator — delegates to GNNativeNoise (C++)
## when available, falls back to pure GDScript otherwise.

var _processor: RefCounted = null


func _init() -> void:
	node_type = "noise"
	node_description = "Procedural noise generator (native C++ accelerated)."
	if ClassDB.class_exists("GNNativeNoise"):
		_processor = ClassDB.instantiate("GNNativeNoise")


func _init_ports() -> void:
	add_output("out", GNFamily.Type.IMG, "Generated noise image")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512),
		"Resolution", "Output image resolution"))
	add_parameter(GNParameter.create_int("type", 0, 0, 1,
		"Noise Type", "0 = Value noise (smooth), 1 = White noise (random)"))
	add_parameter(GNParameter.create_float("scale", 4.0, 0.01, 100.0, 0.1,
		"Scale", "Spatial frequency (value noise)"))
	add_parameter(GNParameter.create_float("offset_x", 0.0, -1000.0, 1000.0, 0.1,
		"Offset X", "Horizontal offset"))
	add_parameter(GNParameter.create_float("offset_y", 0.0, -1000.0, 1000.0, 0.1,
		"Offset Y", "Vertical offset"))
	add_parameter(GNParameter.create_int("octaves", 4, 1, 8, "Octaves",
		"Fractal octave count"))
	add_parameter(GNParameter.create_float("persistence", 0.5, 0.0, 1.0, 0.01,
		"Persistence", "Amplitude decay per octave"))
	add_parameter(GNParameter.create_int("seed", 0, 0, 99999, "Seed", "Random seed"))
	add_parameter(GNParameter.create_bool("monochrome", true,
		"Monochrome", "Grayscale (true) or RGB (false)"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var res: Vector2i = get_param_value("resolution")
	var type: int = get_param_value("type")
	var scale: float = get_param_value("scale")
	var offset_x: float = get_param_value("offset_x")
	var offset_y: float = get_param_value("offset_y")
	var octaves: int = get_param_value("octaves")
	var persistence: float = get_param_value("persistence")
	var seed_val: int = get_param_value("seed")
	var monochrome: bool = get_param_value("monochrome")

	var result_image: Image
	if _processor != null:
		result_image = _processor.process(res.x, res.y, type, scale, offset_x,
			offset_y, octaves, persistence, seed_val, monochrome)
	else:
		result_image = _noise_gdscript(res, type, scale, offset_x, offset_y,
			octaves, persistence, seed_val, monochrome)

	if result_image == null:
		return null

	var out := _prepare_image()
	out.image = result_image
	out.resolution = Vector2i(result_image.get_width(), result_image.get_height())
	out.format = result_image.get_format()
	return out


func _noise_gdscript(res: Vector2i, type: int, scale: float,
		off_x: float, off_y: float, octaves: int, persistence: float,
		seed_val: int, monochrome: bool) -> Image:
	var img := Image.create_empty(res.x, res.y, false, Image.FORMAT_RGBA8)
	if type == 1:
		# White noise
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_val
		for y in range(res.y):
			for x in range(res.x):
				if monochrome:
					var v := rng.randf()
					img.set_pixel(x, y, Color(v, v, v, 1.0))
				else:
					img.set_pixel(x, y, Color(rng.randf(), rng.randf(), rng.randf(), 1.0))
	else:
		# Value noise via FastNoiseLite
		var noise := FastNoiseLite.new()
		noise.seed = seed_val
		noise.frequency = scale / float(res.x)
		noise.fractal_octaves = octaves
		noise.fractal_gain = persistence
		noise.noise_type = FastNoiseLite.TYPE_VALUE
		if monochrome:
			for y in range(res.y):
				for x in range(res.x):
					var v: float = (noise.get_noise_2d(x + off_x, y + off_y) + 1.0) * 0.5
					img.set_pixel(x, y, Color(v, v, v, 1.0))
		else:
			var noise_g := FastNoiseLite.new()
			noise_g.seed = seed_val + 1
			noise_g.frequency = noise.frequency
			noise_g.fractal_octaves = octaves
			noise_g.fractal_gain = persistence
			noise_g.noise_type = FastNoiseLite.TYPE_VALUE
			var noise_b := FastNoiseLite.new()
			noise_b.seed = seed_val + 2
			noise_b.frequency = noise.frequency
			noise_b.fractal_octaves = octaves
			noise_b.fractal_gain = persistence
			noise_b.noise_type = FastNoiseLite.TYPE_VALUE
			for y in range(res.y):
				for x in range(res.x):
					var r: float = (noise.get_noise_2d(x + off_x, y + off_y) + 1.0) * 0.5
					var g: float = (noise_g.get_noise_2d(x + off_x, y + off_y) + 1.0) * 0.5
					var b: float = (noise_b.get_noise_2d(x + off_x, y + off_y) + 1.0) * 0.5
					img.set_pixel(x, y, Color(r, g, b, 1.0))
	return img
