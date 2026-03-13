class_name GpuBlurIMG
extends GNImgComputeBase
## GPU-accelerated Gaussian blur for Image data via compute shader.
##
## Two-pass separable Gaussian blur (horizontal then vertical) running on
## the RenderingDevice.  Falls back to CPU box blur when compute is
## unavailable (Compatibility renderer).


func _init() -> void:
	node_type = "gpublurimg"
	node_description = "GPU Gaussian blur for IMG data. Separable two-pass compute shader."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, false, "Input image")
	add_output("out", GNFamily.Type.IMG, "Blurred image")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("radius", 4, 1, 64,
		"Radius", "Blur kernel radius in pixels"))
	add_parameter(GNParameter.create_int("passes", 1, 1, 4,
		"Passes", "Number of blur passes (more = smoother)"))


func _get_shader_path() -> String:
	return "res://addons/gonodes/shaders/img/blur_img.glsl"


func _dispatch_compute(ctx: GNGpuContext, input_rids: Array[RID],
		output_rid: RID, width: int, height: int) -> void:
	if input_rids.is_empty() or not input_rids[0].is_valid():
		return

	var radius: int = get_param_value("radius")
	var passes: int = get_param_value("passes")
	var groups_x: int = ceili(width / 16.0)
	var groups_y: int = ceili(height / 16.0)

	# We need a ping-pong pair for two-pass separable blur
	var tex_a: RID = input_rids[0]
	var tex_b: RID = output_rid
	# Create a temporary intermediate texture for the horizontal pass
	var tex_temp: RID = ctx.create_texture_2d(width, height)

	for _pass in range(passes):
		# Horizontal pass: tex_a → tex_temp
		_dispatch_pass(ctx, tex_a, tex_temp, width, height, radius, 0, groups_x, groups_y)

		# Vertical pass: tex_temp → tex_b
		_dispatch_pass(ctx, tex_temp, tex_b, width, height, radius, 1, groups_x, groups_y)

		# For subsequent passes, read from output back into the temp
		if _pass < passes - 1:
			tex_a = tex_b
			# Swap tex_b to a fresh intermediate so we don't read/write same texture
			# Actually tex_temp is already available as intermediate

	ctx.free_rid(tex_temp)


func _dispatch_pass(ctx: GNGpuContext, src_rid: RID, dst_rid: RID,
		width: int, height: int, radius: int, direction: int,
		groups_x: int, groups_y: int) -> void:
	var rd := ctx.rd

	# Build push constants (4 ints = 16 bytes)
	var pc := PackedByteArray()
	pc.resize(16)
	pc.encode_s32(0, width)
	pc.encode_s32(4, height)
	pc.encode_s32(8, radius)
	pc.encode_s32(12, direction)

	# Create uniform set: binding 0 = input, binding 1 = output
	var u_in := ctx.uniform_image(0, src_rid)
	var u_out := ctx.uniform_image(1, dst_rid)
	var uniform_set := rd.uniform_set_create([u_in, u_out], _shader_rid, 0)

	ctx.dispatch(_shader_rid, uniform_set, groups_x, groups_y, 1, pc)

	rd.free_rid(uniform_set)


func _cook_cpu(inputs: Array[GNData]) -> GNData:
	# Simple CPU fallback — use the same approach as BlurIMG
	var out := _prepare_image()
	var src := _get_input_img(inputs, 0)
	if src == null or src.image == null:
		return out

	var radius: int = get_param_value("radius")
	var img: Image = src.image.duplicate()
	var w := img.get_width()
	var h := img.get_height()

	if w == 0 or h == 0:
		out.set_image(img)
		return out

	# Simple box blur as CPU fallback
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)

	for y in range(h):
		for x in range(w):
			var r_sum := 0.0
			var g_sum := 0.0
			var b_sum := 0.0
			var a_sum := 0.0
			var count := 0
			for ky in range(-radius, radius + 1):
				for kx in range(-radius, radius + 1):
					var sx := clampi(x + kx, 0, w - 1)
					var sy := clampi(y + ky, 0, h - 1)
					var p := img.get_pixel(sx, sy)
					r_sum += p.r
					g_sum += p.g
					b_sum += p.b
					a_sum += p.a
					count += 1
			img.set_pixel(x, y, Color(
				r_sum / count, g_sum / count,
				b_sum / count, a_sum / count))

	out.set_image(img)
	node_warning = "GPU compute unavailable — using CPU fallback (slow)"
	return out
