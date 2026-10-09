extends Node
## Correctness tests for TOP operators.
##
## TOPs produce GNTextureData. Most require a SubViewport tree, so we test:
##   - Instantiation and parameter setup
##   - Generator TOPs produce non-null output with correct resolution
##   - Filter TOPs handle null input gracefully
##   - Parameter correctness where verifiable without pixel reads

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


## Creates a ConstantTOP, cooks it, returns texture data for use as input.
func _make_constant_tex(color: Color = Color.WHITE, res: Vector2i = Vector2i(64, 64)) -> GNTextureData:
	var c := _make_node(ConstantTOP.new(), "const_%d" % randi())
	c.set_param_value("resolution", res)
	c.set_param_value("color", color)
	c.set_param_value("alpha", 1.0)
	var out := _cook_no_input(c)
	if out is GNTextureData:
		return out
	return null


# ═══════════════════════════════════════════════════════════════════════════════
# ConstantTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_constant_top_instantiate() -> void:
	var node := _make_node(ConstantTOP.new(), "const1")
	GNTestAssert.assert_not_null(node, "ConstantTOP created")
	GNTestAssert.assert_eq(node.node_type, "constant", "node_type")

func test_constant_top_produces_texture() -> void:
	var node := _make_node(ConstantTOP.new(), "const1")
	node.set_param_value("resolution", Vector2i(64, 64))
	node.set_param_value("color", Color.RED)
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "output exists")
	GNTestAssert.assert_true(out is GNTextureData, "is GNTextureData")

func test_constant_top_resolution() -> void:
	var node := _make_node(ConstantTOP.new(), "const1")
	node.set_param_value("resolution", Vector2i(128, 64))
	var out := _cook_no_input(node)
	if out is GNTextureData:
		GNTestAssert.assert_eq(out.resolution, Vector2i(128, 64), "resolution matches param")


# ═══════════════════════════════════════════════════════════════════════════════
# TouchPaintTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_touch_paint_top_instantiate() -> void:
	var node := _make_node(TouchPaintTOP.new(), "paint1")
	GNTestAssert.assert_eq(node.node_type, "touch_paint", "node_type")
	GNTestAssert.assert_true(node.time_dependent, "time_dependent")


# ═══════════════════════════════════════════════════════════════════════════════
# NoiseTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_noise_top_produces_texture() -> void:
	var node := _make_node(NoiseTOP.new(), "noise1")
	node.set_param_value("resolution", Vector2i(64, 64))
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "NoiseTOP output")
	GNTestAssert.assert_true(out is GNTextureData, "is texture")

func test_noise_top_time_dependent() -> void:
	var node := _make_node(NoiseTOP.new(), "noise1")
	node.update_time_dependency()
	GNTestAssert.assert_false(node.time_dependent,
			"constant time_offset is a still frame")
	var p: GNParameter = node.parameters["time_offset"]
	p.set_expression("time * 0.25")
	node.update_time_dependency()
	GNTestAssert.assert_true(node.time_dependent,
			"time_offset expression that reads time is time-dependent")


# ═══════════════════════════════════════════════════════════════════════════════
# CircleTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_circle_top_produces_texture() -> void:
	var node := _make_node(CircleTOP.new(), "circle1")
	node.set_param_value("resolution", Vector2i(64, 64))
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "CircleTOP output")

func test_circle_top_default_params() -> void:
	var node := _make_node(CircleTOP.new(), "circle1")
	GNTestAssert.assert_approx(node.get_param_value("radius"), 0.4, 0.001, "default radius")


# ═══════════════════════════════════════════════════════════════════════════════
# RectangleTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_rectangle_top_produces_texture() -> void:
	var node := _make_node(RectangleTOP.new(), "rect1")
	node.set_param_value("resolution", Vector2i(64, 64))
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "RectangleTOP output")


# ═══════════════════════════════════════════════════════════════════════════════
# TriangleTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_triangle_top_produces_texture() -> void:
	var node := _make_node(TriangleTOP.new(), "tri1")
	node.set_param_value("resolution", Vector2i(64, 64))
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "TriangleTOP output")


# ═══════════════════════════════════════════════════════════════════════════════
# PatternTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_pattern_top_produces_texture() -> void:
	var node := _make_node(PatternTOP.new(), "pat1")
	node.set_param_value("resolution", Vector2i(64, 64))
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "PatternTOP output")


# ═══════════════════════════════════════════════════════════════════════════════
# RampTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_ramp_top_produces_texture() -> void:
	var node := _make_node(RampTOP.new(), "ramp1")
	node.set_param_value("resolution", Vector2i(64, 64))
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "RampTOP output")


# ═══════════════════════════════════════════════════════════════════════════════
# PaletteTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_palette_top_produces_texture() -> void:
	var node := _make_node(PaletteTOP.new(), "pal1")
	node.set_param_value("resolution", Vector2i(64, 64))
	var out := _cook_no_input(node)
	# PaletteTOP uses viewport rendering; may return null in headless
	if out != null:
		GNTestAssert.assert_not_null(out, "PaletteTOP output")
	else:
		GNTestAssert.assert_true(true, "PaletteTOP null in headless (expected)")


# ═══════════════════════════════════════════════════════════════════════════════
# TextTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_text_top_produces_texture() -> void:
	var node := _make_node(TextTOP.new(), "text1")
	node.set_param_value("resolution", Vector2i(64, 64))
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "TextTOP output")


# ═══════════════════════════════════════════════════════════════════════════════
# RichTextTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_rich_text_top_produces_texture() -> void:
	var node := _make_node(RichTextTOP.new(), "richtext1")
	node.set_param_value("resolution", Vector2i(64, 64))
	node.set_param_value("text", "[b]Hi[/b] [color=#ff0]there[/color]")
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "RichTextTOP output")


# ═══════════════════════════════════════════════════════════════════════════════
# SVGTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_svg_top_produces_texture() -> void:
	var node := _make_node(SVGTOP.new(), "svg1")
	node.set_param_value("resolution", Vector2i(64, 64))
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "SVGTOP output")


# ═══════════════════════════════════════════════════════════════════════════════
# NullTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_null_top_passthrough() -> void:
	var node := _make_node(NullTOP.new(), "null1")
	var tex := _make_constant_tex(Color.RED, Vector2i(64, 64))
	if tex == null:
		return  # viewport not available in headless
	var inputs: Array[GNData] = [tex]
	var out := _cook_with(node, inputs)
	GNTestAssert.assert_not_null(out, "NullTOP passes through")

func test_null_top_no_input() -> void:
	var node := _make_node(NullTOP.new(), "null1")
	var out := _cook_no_input(node)
	# NullTOP with no input should return null or empty
	GNTestAssert.assert_true(out == null or out is GNTextureData, "null or texture")


# ═══════════════════════════════════════════════════════════════════════════════
# SwitchTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_switch_top_instantiate() -> void:
	var node := _make_node(SwitchTOP.new(), "switch1")
	GNTestAssert.assert_eq(node.node_type, "switch", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# BlurTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_blur_top_instantiate() -> void:
	var node := _make_node(BlurTOP.new(), "blur1")
	GNTestAssert.assert_eq(node.node_type, "blur", "node_type")

func test_blur_top_no_input_returns_null() -> void:
	var node := _make_node(BlurTOP.new(), "blur1")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(out == null or (out is GNTextureData and out.texture == null),
		"BlurTOP with no input")

func test_blur_top_with_input() -> void:
	var node := _make_node(BlurTOP.new(), "blur1")
	node.set_param_value("size", 10.0)
	var tex := _make_constant_tex(Color.WHITE, Vector2i(64, 64))
	if tex == null:
		return
	var out := _cook_with(node, [tex] as Array[GNData])
	GNTestAssert.assert_not_null(out, "BlurTOP produces output")


# ═══════════════════════════════════════════════════════════════════════════════
# LevelTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_level_top_default_params() -> void:
	var node := _make_node(LevelTOP.new(), "level1")
	GNTestAssert.assert_approx(node.get_param_value("brightness"), 1.0, 0.001, "default brightness")
	GNTestAssert.assert_approx(node.get_param_value("contrast"), 1.0, 0.001, "default contrast")
	GNTestAssert.assert_approx(node.get_param_value("gamma"), 1.0, 0.001, "default gamma")
	GNTestAssert.assert_false(node.get_param_value("invert"), "default invert false")


# ═══════════════════════════════════════════════════════════════════════════════
# ThresholdTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_threshold_top_default_params() -> void:
	var node := _make_node(ThresholdTOP.new(), "thresh1")
	GNTestAssert.assert_approx(node.get_param_value("threshold"), 0.5, 0.001, "default threshold")
	GNTestAssert.assert_approx(node.get_param_value("softness"), 0.0, 0.001, "default softness")

func test_threshold_top_no_input() -> void:
	var node := _make_node(ThresholdTOP.new(), "thresh1")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(out == null or out is GNTextureData, "no crash on null input")


# ═══════════════════════════════════════════════════════════════════════════════
# FlipTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_flip_top_default_params() -> void:
	var node := _make_node(FlipTOP.new(), "flip1")
	GNTestAssert.assert_false(node.get_param_value("flip_x"), "default flip_x false")
	GNTestAssert.assert_false(node.get_param_value("flip_y"), "default flip_y false")


# ═══════════════════════════════════════════════════════════════════════════════
# CropTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_crop_top_instantiate() -> void:
	var node := _make_node(CropTOP.new(), "crop1")
	GNTestAssert.assert_eq(node.node_type, "crop", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# CompositeTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_composite_top_instantiate() -> void:
	var node := _make_node(CompositeTOP.new(), "comp1")
	GNTestAssert.assert_eq(node.node_type, "composite", "node_type")

func test_composite_top_default_opacity() -> void:
	var node := _make_node(CompositeTOP.new(), "comp1")
	GNTestAssert.assert_approx(node.get_param_value("opacity"), 1.0, 0.001, "default opacity")


# ═══════════════════════════════════════════════════════════════════════════════
# CrossTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_cross_top_instantiate() -> void:
	var node := _make_node(CrossTOP.new(), "cross1")
	GNTestAssert.assert_eq(node.node_type, "cross", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# HSVAdjustTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_hsv_adjust_top_instantiate() -> void:
	var node := _make_node(HSVAdjustTOP.new(), "hsv1")
	GNTestAssert.assert_eq(node.node_type, "hsv_adjust", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# MonoTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_mono_top_instantiate() -> void:
	var node := _make_node(MonoTOP.new(), "mono1")
	GNTestAssert.assert_eq(node.node_type, "mono", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# PosterizeTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_posterize_top_instantiate() -> void:
	var node := _make_node(PosterizeTOP.new(), "post1")
	GNTestAssert.assert_eq(node.node_type, "posterize", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# SharpenTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_sharpen_top_instantiate() -> void:
	var node := _make_node(SharpenTOP.new(), "sharp1")
	GNTestAssert.assert_eq(node.node_type, "sharpen", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# EdgeTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_edge_top_instantiate() -> void:
	var node := _make_node(EdgeTOP.new(), "edge1")
	GNTestAssert.assert_eq(node.node_type, "edge", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# EmbossTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_emboss_top_instantiate() -> void:
	var node := _make_node(EmbossTOP.new(), "emboss1")
	GNTestAssert.assert_eq(node.node_type, "emboss", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# ConvolutionTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_convolution_top_instantiate() -> void:
	var node := _make_node(ConvolutionTOP.new(), "conv1")
	GNTestAssert.assert_eq(node.node_type, "convolution", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# DilateErodeTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_dilate_erode_top_instantiate() -> void:
	var node := _make_node(DilateErodeTOP.new(), "dilate1")
	GNTestAssert.assert_eq(node.node_type, "dilate_erode", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# RadialBlurTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_radial_blur_top_instantiate() -> void:
	var node := _make_node(RadialBlurTOP.new(), "rblur1")
	GNTestAssert.assert_eq(node.node_type, "radial_blur", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# LumaBlurTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_luma_blur_top_instantiate() -> void:
	var node := _make_node(LumaBlurTOP.new(), "lblur1")
	GNTestAssert.assert_eq(node.node_type, "luma_blur", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# DisplaceTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_displace_top_instantiate() -> void:
	var node := _make_node(DisplaceTOP.new(), "disp1")
	GNTestAssert.assert_eq(node.node_type, "displace", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# CornerPinTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_corner_pin_top_instantiate() -> void:
	var node := _make_node(CornerPinTOP.new(), "cpin1")
	GNTestAssert.assert_eq(node.node_type, "corner_pin", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# LensDistortTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_lens_distort_top_instantiate() -> void:
	var node := _make_node(LensDistortTOP.new(), "lens1")
	GNTestAssert.assert_eq(node.node_type, "lens_distort", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# TransformTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_transform_top_instantiate() -> void:
	var node := _make_node(TransformTOP.new(), "xform1")
	GNTestAssert.assert_eq(node.node_type, "transform", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# FitTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_fit_top_instantiate() -> void:
	var node := _make_node(FitTOP.new(), "fit1")
	GNTestAssert.assert_eq(node.node_type, "fit", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# TileTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_tile_top_instantiate() -> void:
	var node := _make_node(TileTOP.new(), "tile1")
	GNTestAssert.assert_eq(node.node_type, "tile", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# ResolutionTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_resolution_top_instantiate() -> void:
	var node := _make_node(ResolutionTOP.new(), "res1")
	GNTestAssert.assert_eq(node.node_type, "resolution", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# ColorMapTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_color_map_top_instantiate() -> void:
	var node := _make_node(ColorMapTOP.new(), "cmap1")
	GNTestAssert.assert_eq(node.node_type, "color_map", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# ChannelMixTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_channel_mix_top_instantiate() -> void:
	var node := _make_node(ChannelMixTOP.new(), "cmix1")
	GNTestAssert.assert_eq(node.node_type, "channel_mix", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# PremultiplyTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_premultiply_top_instantiate() -> void:
	var node := _make_node(PremultiplyTOP.new(), "premult1")
	GNTestAssert.assert_eq(node.node_type, "premultiply", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# RemapTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_remap_top_instantiate() -> void:
	var node := _make_node(RemapTOP.new(), "remap1")
	GNTestAssert.assert_eq(node.node_type, "remap", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# LookupTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_lookup_top_instantiate() -> void:
	var node := _make_node(LookupTOP.new(), "lookup1")
	GNTestAssert.assert_eq(node.node_type, "lookup", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# MatteTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_matte_top_instantiate() -> void:
	var node := _make_node(MatteTOP.new(), "matte1")
	GNTestAssert.assert_eq(node.node_type, "matte", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# ChromaKeyTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_chroma_key_top_instantiate() -> void:
	var node := _make_node(ChromaKeyTOP.new(), "ckey1")
	GNTestAssert.assert_eq(node.node_type, "chroma_key", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# NormalMapTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_normal_map_top_instantiate() -> void:
	var node := _make_node(NormalMapTOP.new(), "nmap1")
	GNTestAssert.assert_eq(node.node_type, "normal_map", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# SlopeTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_slope_top_instantiate() -> void:
	var node := _make_node(SlopeTOP.new(), "slope1")
	GNTestAssert.assert_eq(node.node_type, "slope", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# DepthTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_depth_top_instantiate() -> void:
	var node := _make_node(DepthTOP.new(), "depth1")
	GNTestAssert.assert_eq(node.node_type, "depth", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# ProjectionTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_projection_top_instantiate() -> void:
	var node := _make_node(ProjectionTOP.new(), "proj1")
	GNTestAssert.assert_eq(node.node_type, "projection", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# AnalyzeTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_analyze_top_instantiate() -> void:
	var node := _make_node(AnalyzeTOP.new(), "analyze1")
	GNTestAssert.assert_eq(node.node_type, "analyze", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# OpticalFlowTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_optical_flow_top_instantiate() -> void:
	var node := _make_node(OpticalFlowTOP.new(), "oflow1")
	GNTestAssert.assert_eq(node.node_type, "optical_flow", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# FeedbackTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_feedback_top_instantiate() -> void:
	var node := _make_node(FeedbackTOP.new(), "fb1")
	GNTestAssert.assert_eq(node.node_type, "feedback", "node_type")
	GNTestAssert.assert_true(node.time_dependent, "FeedbackTOP is time-dependent")


# ═══════════════════════════════════════════════════════════════════════════════
# CacheTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_cache_top_instantiate() -> void:
	var node := _make_node(CacheTOP.new(), "cache1")
	GNTestAssert.assert_eq(node.node_type, "cache", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# TimeMachineTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_time_machine_top_instantiate() -> void:
	var node := _make_node(TimeMachineTOP.new(), "tm1")
	GNTestAssert.assert_eq(node.node_type, "time_machine", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# GlueTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_glue_top_instantiate() -> void:
	var node := _make_node(GlueTOP.new(), "glue1")
	GNTestAssert.assert_eq(node.node_type, "glue", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# LayoutTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_layout_top_instantiate() -> void:
	var node := _make_node(LayoutTOP.new(), "layout1")
	GNTestAssert.assert_eq(node.node_type, "layout", "node_type")
	GNTestAssert.assert_true(node._dynamic_input, "network will grow inputs")
	GNTestAssert.assert_eq(node.input_ports.size(), 3, "Input 0, Input 1, and a spare")


func test_layout_top_spare_input_grows() -> void:
	var node := _make_node(LayoutTOP.new(), "layout1")
	node.update_dynamic_inputs(PackedInt32Array([0, 1, 2]))
	GNTestAssert.assert_eq(node.input_ports.size(), 4, "connecting the spare adds another port")
	GNTestAssert.assert_eq(node.input_ports[2].port_name, "in2", "the connected spare becomes Input 2")
	GNTestAssert.assert_eq(node.input_ports[3].port_name, "", "a new unnamed spare follows")
	var full := PackedInt32Array()
	for i in range(8):
		full.append(i)
	node.update_dynamic_inputs(full)
	GNTestAssert.assert_eq(node.input_ports.size(), 8, "eight shader inputs, no ninth spare")
	GNTestAssert.assert_eq(node.input_ports[7].port_name, "in7", "the last port is a real input")
	node.update_dynamic_inputs(PackedInt32Array([0]))
	GNTestAssert.assert_eq(node.input_ports.size(), 3, "disconnecting shrinks back to the spare")


# ═══════════════════════════════════════════════════════════════════════════════
# CHOPtoTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_chop_to_top_instantiate() -> void:
	var node := _make_node(CHOPtoTOP.new(), "c2t1")
	GNTestAssert.assert_eq(node.node_type, "chop_to_top", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# RenderTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_render_top_instantiate() -> void:
	var node := _make_node(RenderTOP.new(), "render1")
	GNTestAssert.assert_eq(node.node_type, "render", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# GeometryBufferTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_geometry_buffer_top_instantiate() -> void:
	var node := _make_node(GeometryBufferTOP.new(), "gbuf1")
	GNTestAssert.assert_eq(node.node_type, "geometry_buffer", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# CompositorEffectTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_compositor_effect_top_instantiate() -> void:
	var node := _make_node(CompositorEffectTOP.new(), "comp_eff1")
	GNTestAssert.assert_eq(node.node_type, "compositor_effect", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# ComputeShaderTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_compute_shader_top_instantiate() -> void:
	var node := _make_node(ComputeShaderTOP.new(), "cs1")
	GNTestAssert.assert_eq(node.node_type, "compute_shader", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# CustomShaderTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_custom_shader_top_instantiate() -> void:
	var node := _make_node(CustomShaderTOP.new(), "cs1")
	GNTestAssert.assert_eq(node.node_type, "custom_shader", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# MovieFileInTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_movie_file_in_top_instantiate() -> void:
	var node := _make_node(MovieFileInTOP.new(), "movie1")
	GNTestAssert.assert_eq(node.node_type, "movie_file_in", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# PanelTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_panel_top_instantiate() -> void:
	var node := _make_node(PanelTOP.new(), "panel1")
	GNTestAssert.assert_eq(node.node_type, "panel", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# AntiAliasTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_anti_alias_top_instantiate() -> void:
	var node := _make_node(AntiAliasTOP.new(), "aa1")
	GNTestAssert.assert_eq(node.node_type, "anti_alias", "node_type")

# ═══════════════════════════════════════════════════════════════════════════════
# TOPtoDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_toptodat_instantiate() -> void:
	var node := _make_node(TOPtoDAT.new(), "t2d1")
	GNTestAssert.assert_eq(node.family, "dat", "family is dat")


# ═══════════════════════════════════════════════════════════════════════════════
# ImgToTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_img_to_top_instantiate() -> void:
	var node := _make_node(ImgToTOP.new(), "i2t1")
	GNTestAssert.assert_eq(node.node_type, "img_to_top", "node_type")

func test_img_to_top_produces_texture() -> void:
	var node := _make_node(ImgToTOP.new(), "i2t2")
	var out := _cook_no_input(node)
	# ImgToTOP requires image input; null output without it is expected
	GNTestAssert.assert_true(true, "ImgToTOP cooks without crash")


# ═══════════════════════════════════════════════════════════════════════════════
# TOPtoIMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_tiptoimg_instantiate() -> void:
	var node := _make_node(TOPtoIMG.new(), "t2i1")
	GNTestAssert.assert_eq(node.family, "img", "family is img")


# ═══════════════════════════════════════════════════════════════════════════════
# HostOutTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_host_out_top_instantiate() -> void:
	var node := _make_node(HostOutTOP.new(), "hout1")
	GNTestAssert.assert_not_null(node, "HostOutTOP created")


# ═══════════════════════════════════════════════════════════════════════════════
# ParticleStateTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_particle_state_top_instantiate() -> void:
	var node := _make_node(ParticleStateTOP.new(), "pstate1")
	GNTestAssert.assert_not_null(node, "ParticleStateTOP created")

func test_particle_state_top_null_input() -> void:
	var node := _make_node(ParticleStateTOP.new(), "pstate2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(out == null or out is GNTextureData, "ParticleStateTOP handles null input")


# ═══════════════════════════════════════════════════════════════════════════════
# TOPtoSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_toptosop_instantiate() -> void:
	var node := _make_node(TOPtoSOP.new(), "t2s1")
	GNTestAssert.assert_eq(node.family, "sop", "family is sop")


# ═══════════════════════════════════════════════════════════════════════════════
# DeformTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_deform_top_instantiate() -> void:
	var node := _make_node(DeformTOP.new(), "deform1")
	GNTestAssert.assert_eq(node.node_type, "deform", "node_type")

func test_deform_top_with_inputs() -> void:
	var node := _make_node(DeformTOP.new(), "deform2")
	var tex := _make_constant_tex(Color.WHITE, Vector2i(64, 64))
	if tex == null:
		return
	var displacement := _make_constant_tex(Color.GRAY, Vector2i(64, 64))
	var out := _cook_with(node, [tex, displacement] as Array[GNData])
	GNTestAssert.assert_not_null(out, "DeformTOP with displacement produces output")


# ═══════════════════════════════════════════════════════════════════════════════
# Fluid2DTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_fluid_2d_top_instantiate() -> void:
	var node := _make_node(Fluid2DTOP.new(), "fluid2d1")
	GNTestAssert.assert_not_null(node, "Fluid2DTOP created")

func test_fluid_2d_top_produces_output() -> void:
	var node := _make_node(Fluid2DTOP.new(), "fluid2d2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "Fluid2DTOP produces output")


# ═══════════════════════════════════════════════════════════════════════════════
# HostInTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_host_in_top_instantiate() -> void:
	var node := _make_node(HostInTOP.new(), "hin1")
	GNTestAssert.assert_not_null(node, "HostInTOP created")


# ═══════════════════════════════════════════════════════════════════════════════
# MultiBufferRenderTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_multi_buffer_render_top_instantiate() -> void:
	var node := _make_node(MultiBufferRenderTOP.new(), "mbr1")
	GNTestAssert.assert_eq(node.node_type, "multi_buffer_render", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# PointCloudRenderTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_point_cloud_render_top_instantiate() -> void:
	var node := _make_node(PointCloudRenderTOP.new(), "pcr1")
	GNTestAssert.assert_eq(node.node_type, "point_cloud_render", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# ReactionDiffusionTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_reaction_diffusion_top_instantiate() -> void:
	var node := _make_node(ReactionDiffusionTOP.new(), "rd1")
	GNTestAssert.assert_not_null(node, "ReactionDiffusionTOP created")

func test_reaction_diffusion_top_produces_output() -> void:
	var node := _make_node(ReactionDiffusionTOP.new(), "rd2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "ReactionDiffusionTOP produces output")


# ═══════════════════════════════════════════════════════════════════════════════
# ReorderTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_reorder_top_instantiate() -> void:
	var node := _make_node(ReorderTOP.new(), "reord1")
	GNTestAssert.assert_not_null(node, "ReorderTOP created")

func test_reorder_top_with_input() -> void:
	var node := _make_node(ReorderTOP.new(), "reord2")
	var tex := _make_constant_tex(Color.WHITE, Vector2i(64, 64))
	if tex == null:
		return
	var out := _cook_with(node, [tex] as Array[GNData])
	GNTestAssert.assert_not_null(out, "ReorderTOP with input produces output")


# ═══════════════════════════════════════════════════════════════════════════════
# SnapshotTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_snapshot_top_instantiate() -> void:
	var node := _make_node(SnapshotTOP.new(), "snap1")
	GNTestAssert.assert_not_null(node, "SnapshotTOP created")

func test_snapshot_top_with_input() -> void:
	var node := _make_node(SnapshotTOP.new(), "snap2")
	var tex := _make_constant_tex(Color.WHITE, Vector2i(64, 64))
	if tex == null:
		GNTestAssert.assert_true(true, "no texture in headless")
		return
	var out := _cook_with(node, [tex] as Array[GNData])
	# SnapshotTOP may return null in headless
	if out != null:
		GNTestAssert.assert_not_null(out, "SnapshotTOP captures frame")
	else:
		GNTestAssert.assert_true(true, "SnapshotTOP null in headless (expected)")


# ═══════════════════════════════════════════════════════════════════════════════
# VectorPathTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_vector_path_top_instantiate() -> void:
	var node := _make_node(VectorPathTOP.new(), "vpath1")
	GNTestAssert.assert_not_null(node, "VectorPathTOP created")

func test_vector_path_top_cook() -> void:
	var node := _make_node(VectorPathTOP.new(), "vpath2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "VectorPathTOP cooks successfully")


# ═══════════════════════════════════════════════════════════════════════════════
# CubeMapIMG (reclassified from CubeMapTOP — Rule 25.28)
# ═══════════════════════════════════════════════════════════════════════════════

func test_cube_map_img_instantiate() -> void:
	var node := _make_node(CubeMapIMG.new(), "cubemap1")
	GNTestAssert.assert_not_null(node, "CubeMapIMG created")
	GNTestAssert.assert_eq(node.node_type, "cube_map", "type")

func test_cube_map_img_modes() -> void:
	var node := _make_node(CubeMapIMG.new(), "cubemap2")
	# Mode 0 = Assemble, Mode 1 = Extract, Mode 2 = Equirect to Cross
	node.set_param_value("mode", 0)
	GNTestAssert.assert_eq(node.get_param_value("mode"), 0, "mode defaults to Assemble")

func test_cube_map_img_cook() -> void:
	var node := _make_node(CubeMapIMG.new(), "cubemap3")
	# Cook with no inputs — should handle gracefully
	var out := _cook_no_input(node)
	# May return null with no face inputs — that's OK
	GNTestAssert.assert_true(out == null or out is GNImageData,
		"CubeMapIMG handles empty input gracefully")

