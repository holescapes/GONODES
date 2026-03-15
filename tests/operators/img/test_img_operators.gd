extends Node
## Correctness tests for IMG operators.
##
## IMGs produce GNImageData (CPU Image). We can verify pixel values directly.

var _network: GNNetwork
var _engine: GNCookEngine


func before_each() -> void:
	_network = GNNetwork.new()
	_engine = GNCookEngine.new()
	_engine.network = _network
	_engine.cooking_enabled = false
	_engine.elapsed_time = 1.0
	_engine.frame_count = 60
	_engine.current_delta = 1.0 / 60.0
	add_child(_engine)


func after_each() -> void:
	if is_instance_valid(_engine):
		remove_child(_engine)
		_engine.queue_free()


func _make_node(node: GNNode, id: String) -> GNNode:
	node.initialize(id)
	_network.add_node(node)
	_engine.add_child(node)
	return node


func _cook_no_input(node: GNNode) -> GNData:
	var inputs: Array[GNData] = []
	node.execute_cook(inputs, _engine.frame_count)
	return node.cached_output


func _cook_with(node: GNNode, inputs: Array[GNData]) -> GNData:
	node.execute_cook(inputs, _engine.frame_count)
	return node.cached_output


# ═══════════════════════════════════════════════════════════════════════════════
# NoiseIMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_noise_img_produces_image() -> void:
	var node := _make_node(NoiseIMG.new(), "noise1")
	node.set_param_value("resolution", Vector2i(32, 32))
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "NoiseIMG output")
	GNTestAssert.assert_true(out is GNImageData, "is GNImageData")

func test_noise_img_resolution() -> void:
	var node := _make_node(NoiseIMG.new(), "noise1")
	node.set_param_value("resolution", Vector2i(64, 32))
	var out := _cook_no_input(node)
	if out is GNImageData:
		GNTestAssert.assert_eq(out.resolution, Vector2i(64, 32), "resolution matches")

func test_noise_img_has_valid_image() -> void:
	var node := _make_node(NoiseIMG.new(), "noise1")
	node.set_param_value("resolution", Vector2i(16, 16))
	var out := _cook_no_input(node)
	if out is GNImageData:
		GNTestAssert.assert_not_null(out.image, "image not null")
		GNTestAssert.assert_eq(out.image.get_width(), 16, "width")
		GNTestAssert.assert_eq(out.image.get_height(), 16, "height")

func test_noise_img_monochrome() -> void:
	var node := _make_node(NoiseIMG.new(), "noise1")
	node.set_param_value("resolution", Vector2i(16, 16))
	node.set_param_value("monochrome", true)
	var out := _cook_no_input(node)
	if out is GNImageData and out.image != null:
		var px: Color = out.image.get_pixel(8, 8)
		GNTestAssert.assert_approx(px.r, px.g, 0.001, "mono r==g")
		GNTestAssert.assert_approx(px.g, px.b, 0.001, "mono g==b")

func test_noise_img_different_seeds() -> void:
	var n1 := _make_node(NoiseIMG.new(), "noise_a")
	n1.set_param_value("resolution", Vector2i(16, 16))
	n1.set_param_value("seed", 0)
	var out1 := _cook_no_input(n1)

	var n2 := _make_node(NoiseIMG.new(), "noise_b")
	n2.set_param_value("resolution", Vector2i(16, 16))
	n2.set_param_value("seed", 42)
	var out2 := _cook_no_input(n2)

	if out1 is GNImageData and out2 is GNImageData and out1.image and out2.image:
		var px1: Color = out1.image.get_pixel(4, 4)
		var px2: Color = out2.image.get_pixel(4, 4)
		# Different seeds should (almost certainly) produce different pixels
		var diff := absf(px1.r - px2.r) + absf(px1.g - px2.g) + absf(px1.b - px2.b)
		GNTestAssert.assert_gt(diff, 0.001, "different seeds → different pixels")


# ═══════════════════════════════════════════════════════════════════════════════
# CheckerboardIMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_checkerboard_img_produces_image() -> void:
	var node := _make_node(CheckerboardIMG.new(), "check1")
	node.set_param_value("resolution", Vector2i(32, 32))
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "CheckerboardIMG output")
	GNTestAssert.assert_true(out is GNImageData, "is GNImageData")

func test_checkerboard_img_pattern_corners() -> void:
	var node := _make_node(CheckerboardIMG.new(), "check1")
	node.set_param_value("resolution", Vector2i(64, 64))
	node.set_param_value("cells_x", 2)
	node.set_param_value("cells_y", 2)
	node.set_param_value("color_a", Color.WHITE)
	node.set_param_value("color_b", Color.BLACK)
	node.set_param_value("softness", 0.0)
	var out := _cook_no_input(node)
	if out is GNImageData and out.image != null:
		# Top-left quadrant should be one color, top-right another
		var tl: Color = out.image.get_pixel(8, 8)
		var tr: Color = out.image.get_pixel(48, 8)
		# They should differ (one white, one black)
		var diff := absf(tl.r - tr.r)
		GNTestAssert.assert_gt(diff, 0.5, "checkerboard alternates")

func test_checkerboard_img_resolution() -> void:
	var node := _make_node(CheckerboardIMG.new(), "check1")
	node.set_param_value("resolution", Vector2i(128, 64))
	var out := _cook_no_input(node)
	if out is GNImageData:
		GNTestAssert.assert_eq(out.resolution, Vector2i(128, 64), "resolution matches")


# ═══════════════════════════════════════════════════════════════════════════════
# BlurIMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_blur_img_no_input() -> void:
	var node := _make_node(BlurIMG.new(), "blur1")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(out == null or out is GNImageData, "no crash")

func test_blur_img_smooths_edges() -> void:
	# Create a checkerboard and blur it — result should have less contrast
	var check := _make_node(CheckerboardIMG.new(), "check1")
	check.set_param_value("resolution", Vector2i(32, 32))
	check.set_param_value("cells_x", 2)
	check.set_param_value("cells_y", 2)
	check.set_param_value("softness", 0.0)
	var check_out := _cook_no_input(check)
	if check_out == null or not (check_out is GNImageData):
		return

	var blur := _make_node(BlurIMG.new(), "blur1")
	blur.set_param_value("radius", 3)
	blur.set_param_value("passes", 2)
	var out := _cook_with(blur, [check_out] as Array[GNData])
	if out is GNImageData and out.image != null:
		# Edge pixel (boundary between cells) should not be pure black or white
		var edge_px: Color = out.image.get_pixel(16, 8)
		GNTestAssert.assert_gt(edge_px.r, 0.05, "edge not pure black after blur")
		GNTestAssert.assert_lt(edge_px.r, 0.95, "edge not pure white after blur")


# ═══════════════════════════════════════════════════════════════════════════════
# EdgeDetectIMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_edge_detect_img_no_input() -> void:
	var node := _make_node(EdgeDetectIMG.new(), "edge1")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(out == null or out is GNImageData, "no crash")

func test_edge_detect_img_finds_edges() -> void:
	var check := _make_node(CheckerboardIMG.new(), "check1")
	check.set_param_value("resolution", Vector2i(32, 32))
	check.set_param_value("cells_x", 2)
	check.set_param_value("cells_y", 2)
	check.set_param_value("softness", 0.0)
	var check_out := _cook_no_input(check)
	if check_out == null or not (check_out is GNImageData):
		return

	var edge := _make_node(EdgeDetectIMG.new(), "edge1")
	edge.set_param_value("strength", 1.0)
	var out := _cook_with(edge, [check_out] as Array[GNData])
	if out is GNImageData and out.image != null:
		# Center of a solid quadrant should have low edge value
		var center_px: Color = out.image.get_pixel(8, 8)
		# Edge boundary should have higher value
		var edge_px: Color = out.image.get_pixel(16, 8)
		GNTestAssert.assert_gt(edge_px.r, center_px.r, "edge brightness > flat area")


# ═══════════════════════════════════════════════════════════════════════════════
# PixelSortIMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_pixel_sort_img_instantiate() -> void:
	var node := _make_node(PixelSortIMG.new(), "psort1")
	GNTestAssert.assert_eq(node.node_type, "pixel_sort", "node_type")

func test_pixel_sort_img_no_input() -> void:
	var node := _make_node(PixelSortIMG.new(), "psort1")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(out == null or out is GNImageData, "no crash")


# ═══════════════════════════════════════════════════════════════════════════════
# ImageFileInIMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_image_file_in_img_instantiate() -> void:
	var node := _make_node(ImageFileInIMG.new(), "filein1")
	GNTestAssert.assert_eq(node.node_type, "image_file_in", "node_type")

func test_image_file_in_img_no_file() -> void:
	var node := _make_node(ImageFileInIMG.new(), "filein1")
	var out := _cook_no_input(node)
	# No file specified → null or empty image
	GNTestAssert.assert_true(out == null or out is GNImageData, "no crash")


# ═══════════════════════════════════════════════════════════════════════════════
# ImageSequenceIMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_image_sequence_img_instantiate() -> void:
	var node := _make_node(ImageSequenceIMG.new(), "seq1")
	GNTestAssert.assert_eq(node.node_type, "image_sequence", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# ScriptIMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_script_img_instantiate() -> void:
	var node := _make_node(ScriptIMG.new(), "script1")
	GNTestAssert.assert_eq(node.node_type, "scriptimg", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# TOPtoIMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_top_to_img_instantiate() -> void:
	var node := _make_node(TOPtoIMG.new(), "t2i1")
	GNTestAssert.assert_eq(node.node_type, "top_to_img", "node_type")

func test_top_to_img_no_input() -> void:
	var node := _make_node(TOPtoIMG.new(), "t2i1")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(out == null or out is GNImageData, "no crash")


# ═══════════════════════════════════════════════════════════════════════════════
# ImgToTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_img_to_top_instantiate() -> void:
	var node := _make_node(ImgToTOP.new(), "i2t1")
	GNTestAssert.assert_eq(node.node_type, "img_to_top", "node_type")

func test_img_to_top_no_input() -> void:
	var node := _make_node(ImgToTOP.new(), "i2t1")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(out == null or out is GNTextureData, "no crash")


# ═══════════════════════════════════════════════════════════════════════════════
# WebcamIMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_webcam_img_instantiate() -> void:
	var node := _make_node(WebcamIMG.new(), "webcam1")
	GNTestAssert.assert_eq(node.node_type, "webcam", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# ScreenGrabIMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_screen_grab_img_instantiate() -> void:
	var node := _make_node(ScreenGrabIMG.new(), "sgrab1")
	GNTestAssert.assert_eq(node.node_type, "screen_grab", "node_type")
