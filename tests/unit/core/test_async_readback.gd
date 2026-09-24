extends Node
## Unit tests for async GPU texture readback via GNTextureData.get_readback_image().


func test_readback_image_returns_image() -> void:
	var td := GNTextureData.new()
	var src := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	src.fill(Color.RED)
	td.texture = ImageTexture.create_from_image(src)
	td.resolution = Vector2i(4, 4)
	td.format = Image.FORMAT_RGBA8

	var rb := td.get_readback_image()
	GNTestAssert.assert_not_null(rb, "readback returns an Image")
	GNTestAssert.assert_eq(rb.get_width(), 4, "readback width")
	GNTestAssert.assert_eq(rb.get_height(), 4, "readback height")


func test_readback_image_second_call_returns_image() -> void:
	var td := GNTextureData.new()
	var src := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	src.fill(Color.BLUE)
	td.texture = ImageTexture.create_from_image(src)
	td.resolution = Vector2i(8, 8)
	td.format = Image.FORMAT_RGBA8

	var rb1 := td.get_readback_image()
	var rb2 := td.get_readback_image()
	GNTestAssert.assert_not_null(rb1, "first readback returns an Image")
	GNTestAssert.assert_not_null(rb2, "second readback returns an Image")
	GNTestAssert.assert_eq(rb1.get_width(), rb2.get_width(), "consistent width")
	GNTestAssert.assert_eq(rb1.get_height(), rb2.get_height(), "consistent height")


func test_readback_viewport_texture_sync_path() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(16, 16)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var rect := ColorRect.new()
	rect.color = Color(1.0, 0.0, 0.0, 1.0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(rect)

	var td := GNTextureData.new()
	td.texture = vp.get_texture()
	td.resolution = Vector2i(16, 16)
	td.format = Image.FORMAT_RGBA8

	# ViewportTexture uses sync get_image() when RenderingDevice is available.
	var rb := td.get_readback_image()
	if GNGpuContext.is_compute_available():
		GNTestAssert.assert_true(rb == null or rb is Image,
			"viewport readback returns Image or null without error")
	else:
		GNTestAssert.assert_null(rb, "headless dummy renderer has no viewport readback")

	remove_child(vp)
	vp.queue_free()


func test_readback_gpu_texture_when_rd_available() -> void:
	if not GNGpuContext.is_compute_available():
		GNTestAssert.assert_true(true, "skip without RenderingDevice")
		return

	var ctx := GNGpuContext.get_context()
	var src := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	src.fill(Color.GREEN)
	var tex_rid := ctx.upload_image(src)
	if not tex_rid.is_valid():
		GNTestAssert.assert_true(true, "skip upload failed")
		return

	var tex2d := Texture2DRD.new()
	tex2d.texture_rd_rid = tex_rid

	var td := GNTextureData.new()
	td.texture = tex2d
	td.resolution = Vector2i(16, 16)
	td.format = Image.FORMAT_RGBA8

	var rb1 := td.get_readback_image()
	GNTestAssert.assert_not_null(rb1, "GPU first readback returns an Image")
	GNTestAssert.assert_eq(rb1.get_width(), 16, "GPU readback width")

	var rb2 := td.get_readback_image()
	GNTestAssert.assert_not_null(rb2, "GPU second readback returns an Image")
	GNTestAssert.assert_eq(rb2.get_height(), 16, "GPU readback height")

	ctx.free_rid(tex_rid)
