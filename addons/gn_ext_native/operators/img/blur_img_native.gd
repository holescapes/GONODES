class_name BlurIMGNative
extends GNImgBase
## Native-accelerated box blur — delegates to GNNativeBlur (C++) when available,
## falls back to pure GDScript otherwise.

var _processor: RefCounted = null


func _init() -> void:
	node_type = "blurimg_native"
	node_description = "Box blur (native C++ accelerated)."
	if ClassDB.class_exists("GNNativeBlur"):
		_processor = ClassDB.instantiate("GNNativeBlur")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, true, "Image to blur")
	add_output("out", GNFamily.Type.IMG, "Blurred image")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("radius", 4, 1, 64, "Radius",
		"Blur kernel half-width in pixels"))
	add_parameter(GNParameter.create_int("passes", 1, 1, 4, "Passes",
		"Number of sequential blur passes (more ≈ Gaussian)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_img: GNImageData = _get_input_img(inputs, 0)
	if in_img == null or in_img.image == null:
		return null

	var radius: int = get_param_value("radius")
	var passes: int = get_param_value("passes")

	var result_image: Image
	if _processor != null:
		result_image = _processor.process(in_img.image, radius, passes)
	else:
		result_image = _blur_gdscript(in_img.image, radius, passes)

	if result_image == null:
		return null

	var out := _prepare_image()
	out.image = result_image
	out.resolution = Vector2i(result_image.get_width(), result_image.get_height())
	out.format = result_image.get_format()
	return out


func _blur_gdscript(img: Image, radius: int, passes: int) -> Image:
	var result := img.duplicate() as Image
	for _p in range(passes):
		result = _box_blur(result, radius)
	return result


func _box_blur(src: Image, radius: int) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var temp := Image.create_empty(w, h, false, src.get_format())
	var dst := Image.create_empty(w, h, false, src.get_format())
	var kernel: float = float(2 * radius + 1)

	# Horizontal pass
	for y in range(h):
		var rs := 0.0; var gs := 0.0; var bs := 0.0; var as_ := 0.0
		for kx in range(-radius, radius + 1):
			var p: Color = src.get_pixel(clampi(kx, 0, w - 1), y)
			rs += p.r; gs += p.g; bs += p.b; as_ += p.a
		temp.set_pixel(0, y, Color(rs / kernel, gs / kernel, bs / kernel, as_ / kernel))
		for x in range(1, w):
			var pa: Color = src.get_pixel(clampi(x + radius, 0, w - 1), y)
			var pr: Color = src.get_pixel(clampi(x - radius - 1, 0, w - 1), y)
			rs += pa.r - pr.r; gs += pa.g - pr.g; bs += pa.b - pr.b; as_ += pa.a - pr.a
			temp.set_pixel(x, y, Color(rs / kernel, gs / kernel, bs / kernel, as_ / kernel))

	# Vertical pass
	for x in range(w):
		var rs := 0.0; var gs := 0.0; var bs := 0.0; var as_ := 0.0
		for ky in range(-radius, radius + 1):
			var p: Color = temp.get_pixel(x, clampi(ky, 0, h - 1))
			rs += p.r; gs += p.g; bs += p.b; as_ += p.a
		dst.set_pixel(x, 0, Color(rs / kernel, gs / kernel, bs / kernel, as_ / kernel))
		for y in range(1, h):
			var pa: Color = temp.get_pixel(x, clampi(y + radius, 0, h - 1))
			var pr: Color = temp.get_pixel(x, clampi(y - radius - 1, 0, h - 1))
			rs += pa.r - pr.r; gs += pa.g - pr.g; bs += pa.b - pr.b; as_ += pa.a - pr.a
			dst.set_pixel(x, y, Color(rs / kernel, gs / kernel, bs / kernel, as_ / kernel))

	return dst
