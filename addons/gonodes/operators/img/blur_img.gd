class_name BlurIMG
extends GNImgBase
## CPU-side box blur filter for Image data.
## Applies a configurable-radius box blur.  For GPU blur, use BlurTOP.

func _init() -> void:
	node_type = "blurimg"
	node_description = "CPU box blur filter. Separate horizontal/vertical passes."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, false, "Input image")
	add_output("out", GNFamily.Type.IMG, "Blurred image")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("radius", 3, 1, 64,
		"Radius", "Blur kernel radius in pixels (actual kernel = 2*radius+1)"))
	add_parameter(GNParameter.create_int("passes", 1, 1, 4,
		"Passes", "Number of blur passes (more = smoother, approximates Gaussian)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_image()

	var src := _get_input_img(inputs, 0)
	if src == null or src.image == null:
		return out

	var radius: int = get_param_value("radius")
	var passes: int = get_param_value("passes")

	# COW: duplicate only when upstream output is shared (fan-out)
	var src_data := _mutable_input(src) as GNImageData
	var img: Image = src_data.image
	var w: int = img.get_width()
	var h: int = img.get_height()

	if w == 0 or h == 0:
		out.set_image(img)
		return out

	for _pass in range(passes):
		img = _box_blur(img, w, h, radius)

	out.set_image(img)
	return out


## Two-pass separable box blur: horizontal → vertical
func _box_blur(src: Image, w: int, h: int, radius: int) -> Image:
	var temp := Image.create(w, h, false, src.get_format())
	var dst := Image.create(w, h, false, src.get_format())
	var kernel_size: float = float(2 * radius + 1)

	# Horizontal pass → temp
	for y in range(h):
		var r_sum: float = 0.0
		var g_sum: float = 0.0
		var b_sum: float = 0.0
		var a_sum: float = 0.0
		# Seed the accumulator with the first kernel window
		for kx in range(-radius, radius + 1):
			var sx: int = clampi(kx, 0, w - 1)
			var p := src.get_pixel(sx, y)
			r_sum += p.r; g_sum += p.g; b_sum += p.b; a_sum += p.a
		temp.set_pixel(0, y, Color(r_sum / kernel_size, g_sum / kernel_size,
			b_sum / kernel_size, a_sum / kernel_size))
		# Slide the window
		for x in range(1, w):
			var add_x: int = clampi(x + radius, 0, w - 1)
			var rem_x: int = clampi(x - radius - 1, 0, w - 1)
			var pa := src.get_pixel(add_x, y)
			var pr := src.get_pixel(rem_x, y)
			r_sum += pa.r - pr.r
			g_sum += pa.g - pr.g
			b_sum += pa.b - pr.b
			a_sum += pa.a - pr.a
			temp.set_pixel(x, y, Color(r_sum / kernel_size, g_sum / kernel_size,
				b_sum / kernel_size, a_sum / kernel_size))

	# Vertical pass → dst
	for x in range(w):
		var r_sum: float = 0.0
		var g_sum: float = 0.0
		var b_sum: float = 0.0
		var a_sum: float = 0.0
		for ky in range(-radius, radius + 1):
			var sy: int = clampi(ky, 0, h - 1)
			var p := temp.get_pixel(x, sy)
			r_sum += p.r; g_sum += p.g; b_sum += p.b; a_sum += p.a
		dst.set_pixel(x, 0, Color(r_sum / kernel_size, g_sum / kernel_size,
			b_sum / kernel_size, a_sum / kernel_size))
		for y in range(1, h):
			var add_y: int = clampi(y + radius, 0, h - 1)
			var rem_y: int = clampi(y - radius - 1, 0, h - 1)
			var pa := temp.get_pixel(x, add_y)
			var pr := temp.get_pixel(x, rem_y)
			r_sum += pa.r - pr.r
			g_sum += pa.g - pr.g
			b_sum += pa.b - pr.b
			a_sum += pa.a - pr.a
			dst.set_pixel(x, y, Color(r_sum / kernel_size, g_sum / kernel_size,
				b_sum / kernel_size, a_sum / kernel_size))

	return dst
