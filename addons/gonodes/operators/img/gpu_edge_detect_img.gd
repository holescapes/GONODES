class_name GpuEdgeDetectIMG
extends GNImgComputeBase
## GPU-accelerated Sobel edge detection for Image data via compute shader.
##
## Runs a 3x3 Sobel convolution on the RenderingDevice to produce a
## grayscale edge map.  Falls back to CPU when compute is unavailable.


func _init() -> void:
	node_type = "gpuedgedetectimg"
	node_description = "GPU Sobel edge detection for IMG data. Compute shader."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, false, "Input image")
	add_output("out", GNFamily.Type.IMG, "Edge-detected image")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("strength", 1.0, 0.1, 10.0, 0.1,
		"Strength", "Edge detection strength multiplier"))


func _get_shader_path() -> String:
	return "res://addons/gonodes/shaders/img/edge_detect_img.glsl"


func _dispatch_compute(ctx: GNGpuContext, input_rids: Array[RID],
		output_rid: RID, width: int, height: int) -> void:
	if input_rids.is_empty() or not input_rids[0].is_valid():
		return

	var strength: float = get_param_value("strength")
	var groups_x: int = ceili(width / 16.0)
	var groups_y: int = ceili(height / 16.0)

	# Build push constants: 2 ints + 1 float + 1 int padding = 16 bytes
	var pc := PackedByteArray()
	pc.resize(16)
	pc.encode_s32(0, width)
	pc.encode_s32(4, height)
	pc.encode_float(8, strength)
	pc.encode_s32(12, 0)

	var u_in := ctx.uniform_image(0, input_rids[0])
	var u_out := ctx.uniform_image(1, output_rid)
	var uniform_set := ctx.rd.uniform_set_create([u_in, u_out], _shader_rid, 0)

	ctx.dispatch(_shader_rid, uniform_set, groups_x, groups_y, 1, pc)

	ctx.rd.free_rid(uniform_set)


func _cook_cpu(inputs: Array[GNData]) -> GNData:
	# Simple CPU Sobel fallback
	var out := _prepare_image()
	var src := _get_input_img(inputs, 0)
	if src == null or src.image == null:
		return out

	var strength: float = get_param_value("strength")
	var img: Image = src.image.duplicate()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)

	var w := img.get_width()
	var h := img.get_height()
	if w == 0 or h == 0:
		out.set_image(img)
		return out

	var result := Image.create(w, h, false, Image.FORMAT_RGBA8)

	for y in range(h):
		for x in range(w):
			var tl := img.get_pixel(maxi(x - 1, 0), maxi(y - 1, 0)).get_luminance()
			var tc := img.get_pixel(x, maxi(y - 1, 0)).get_luminance()
			var tr := img.get_pixel(mini(x + 1, w - 1), maxi(y - 1, 0)).get_luminance()
			var ml := img.get_pixel(maxi(x - 1, 0), y).get_luminance()
			var mr := img.get_pixel(mini(x + 1, w - 1), y).get_luminance()
			var bl := img.get_pixel(maxi(x - 1, 0), mini(y + 1, h - 1)).get_luminance()
			var bc := img.get_pixel(x, mini(y + 1, h - 1)).get_luminance()
			var br := img.get_pixel(mini(x + 1, w - 1), mini(y + 1, h - 1)).get_luminance()
			var gx := -tl - 2.0 * ml - bl + tr + 2.0 * mr + br
			var gy := -tl - 2.0 * tc - tr + bl + 2.0 * bc + br
			var edge := clampf(sqrt(gx * gx + gy * gy) * strength, 0.0, 1.0)
			result.set_pixel(x, y, Color(edge, edge, edge, 1.0))

	out.set_image(result)
	node_warning = "GPU compute unavailable — using CPU fallback (slow)"
	return out
