class_name EdgeDetectIMG
extends GNImgBase
## CPU-side edge detection filter using Sobel or Prewitt operators.
## Outputs a grayscale edge-strength image.

enum KernelType { SOBEL, PREWITT }


func _init() -> void:
	node_type = "edgedetectimg"
	node_description = "CPU edge detection (Sobel / Prewitt). Outputs grayscale edges."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, false, "Input image")
	add_output("out", GNFamily.Type.IMG, "Edge-detected image")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("kernel", 0, 0, 1,
		"Kernel", "0 = Sobel, 1 = Prewitt"))
	add_parameter(GNParameter.create_float("strength", 1.0, 0.1, 10.0, 0.1,
		"Strength", "Edge intensity multiplier"))
	add_parameter(GNParameter.create_bool("invert", false,
		"Invert", "Invert output (white background, dark edges)"))
	add_parameter(GNParameter.create_bool("color_edges", false,
		"Color Edges", "Output gradient direction as color (R=Gx, G=Gy, B=magnitude)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_image()

	var src := _get_input_img(inputs, 0)
	if src == null or src.image == null:
		return out

	var kernel_type: int = get_param_value("kernel")
	var strength: float = get_param_value("strength")
	var invert: bool = get_param_value("invert")
	var color_edges: bool = get_param_value("color_edges")

	var src_img := src.image
	var w: int = src_img.get_width()
	var h: int = src_img.get_height()
	if w < 3 or h < 3:
		out.set_image(src_img.duplicate())
		return out

	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)

	# Precompute luminance buffer for faster access
	var lum := PackedFloat32Array()
	lum.resize(w * h)
	for y in range(h):
		for x in range(w):
			var p := src_img.get_pixel(x, y)
			lum[y * w + x] = p.r * 0.299 + p.g * 0.587 + p.b * 0.114

	# Kernel weights
	var kx: Array[float]
	var ky: Array[float]
	if kernel_type == KernelType.PREWITT:
		kx = [-1.0, 0.0, 1.0, -1.0, 0.0, 1.0, -1.0, 0.0, 1.0]
		ky = [-1.0, -1.0, -1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0]
	else:  # Sobel
		kx = [-1.0, 0.0, 1.0, -2.0, 0.0, 2.0, -1.0, 0.0, 1.0]
		ky = [-1.0, -2.0, -1.0, 0.0, 0.0, 0.0, 1.0, 2.0, 1.0]

	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var gx: float = 0.0
			var gy: float = 0.0
			var ki: int = 0
			for ky_off in range(-1, 2):
				for kx_off in range(-1, 2):
					var l := lum[(y + ky_off) * w + (x + kx_off)]
					gx += l * kx[ki]
					gy += l * ky[ki]
					ki += 1

			var mag := sqrtf(gx * gx + gy * gy) * strength

			if color_edges:
				# Encode gradient direction as color
				var r := clampf(absf(gx) * strength, 0.0, 1.0)
				var g := clampf(absf(gy) * strength, 0.0, 1.0)
				var b := clampf(mag, 0.0, 1.0)
				if invert:
					img.set_pixel(x, y, Color(1.0 - r, 1.0 - g, 1.0 - b, 1.0))
				else:
					img.set_pixel(x, y, Color(r, g, b, 1.0))
			else:
				mag = clampf(mag, 0.0, 1.0)
				if invert:
					mag = 1.0 - mag
				img.set_pixel(x, y, Color(mag, mag, mag, 1.0))

	# Fill border pixels (edges can't be computed with a 3×3 kernel)
	for x in range(w):
		img.set_pixel(x, 0, img.get_pixel(clampi(x, 1, w - 2), 1))
		img.set_pixel(x, h - 1, img.get_pixel(clampi(x, 1, w - 2), h - 2))
	for y in range(h):
		img.set_pixel(0, y, img.get_pixel(1, clampi(y, 1, h - 2)))
		img.set_pixel(w - 1, y, img.get_pixel(w - 2, clampi(y, 1, h - 2)))

	out.set_image(img)
	return out
