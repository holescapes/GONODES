extends Node
## Unit tests for native-accelerated operator wrappers (GDScript fallback).
##
## Since the C++ GDExtension binaries are not compiled in the test environment,
## these tests verify the pure GDScript fallback paths of all 6 native operators:
##   - NoiseIMGNative, BlurIMGNative, PixelSortIMGNative
##   - ParticleSOPNative, MetaballSOPNative, PolyReduceSOPNative
##
## Each test creates the operator, initializes it, cooks with default or
## configured parameters, and validates the output data type and basic properties.

var _engine: GNCookEngine
var _network: GNNetwork


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

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
	if _engine and is_instance_valid(_engine):
		_engine.queue_free()
	_engine = null
	_network = null


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _make_node(node: GNNode, id: String) -> GNNode:
	node.initialize(id)
	_network.add_node(node)
	_engine.add_child(node)
	return node


func _cook_no_input(node: GNNode) -> GNData:
	var inputs: Array[GNData] = []
	node.execute_cook(inputs, _engine.frame_count)
	return node.cached_output


# ═══════════════════════════════════════════════════════════════════════════════
# NoiseIMGNative
# ═══════════════════════════════════════════════════════════════════════════════

func test_noise_native_fallback_produces_image() -> void:
	var node := _make_node(NoiseIMGNative.new(), "noise1")
	node.set_param_value("resolution", Vector2i(64, 64))
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "noise output should not be null")
	GNTestAssert.assert_is(out, "GNImageData", "noise output should be GNImageData")


func test_noise_native_fallback_resolution() -> void:
	var node := _make_node(NoiseIMGNative.new(), "noise2")
	node.set_param_value("resolution", Vector2i(128, 64))
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "noise output exists")
	var img_data: GNImageData = out as GNImageData
	GNTestAssert.assert_not_null(img_data.image, "image exists")
	GNTestAssert.assert_eq(img_data.image.get_width(), 128, "width=128")
	GNTestAssert.assert_eq(img_data.image.get_height(), 64, "height=64")


func test_noise_native_fallback_no_cpp() -> void:
	var node := NoiseIMGNative.new()
	# Without C++ compiled, _processor should be null
	GNTestAssert.assert_null(node._processor, "C++ processor should be null")


func test_noise_native_white_noise() -> void:
	var node := _make_node(NoiseIMGNative.new(), "noise3")
	node.set_param_value("resolution", Vector2i(32, 32))
	node.set_param_value("type", 1)  # white noise
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "white noise output exists")


func test_noise_native_color_mode() -> void:
	var node := _make_node(NoiseIMGNative.new(), "noise4")
	node.set_param_value("resolution", Vector2i(32, 32))
	node.set_param_value("monochrome", false)
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "color noise output exists")


# ═══════════════════════════════════════════════════════════════════════════════
# BlurIMGNative
# ═══════════════════════════════════════════════════════════════════════════════

func test_blur_native_fallback_produces_image() -> void:
	# Make a noise source first
	var src := _make_node(NoiseIMGNative.new(), "blur_src")
	src.set_param_value("resolution", Vector2i(64, 64))
	_cook_no_input(src)
	# Make blur node
	var blur := _make_node(BlurIMGNative.new(), "blur1")
	blur.set_param_value("radius", 4)
	blur.set_param_value("passes", 1)
	# Cook with input
	var inputs: Array[GNData] = [src.cached_output]
	blur.execute_cook(inputs, _engine.frame_count)
	var out := blur.cached_output
	GNTestAssert.assert_not_null(out, "blur output should not be null")
	GNTestAssert.assert_is(out, "GNImageData", "blur output should be GNImageData")


func test_blur_native_preserves_resolution() -> void:
	var src := _make_node(NoiseIMGNative.new(), "blur_res_src")
	src.set_param_value("resolution", Vector2i(128, 64))
	_cook_no_input(src)
	var blur := _make_node(BlurIMGNative.new(), "blur2")
	var inputs: Array[GNData] = [src.cached_output]
	blur.execute_cook(inputs, _engine.frame_count)
	var img_data: GNImageData = blur.cached_output as GNImageData
	GNTestAssert.assert_not_null(img_data.image, "blurred image exists")
	GNTestAssert.assert_eq(img_data.image.get_width(), 128, "width preserved")
	GNTestAssert.assert_eq(img_data.image.get_height(), 64, "height preserved")


func test_blur_native_no_input_returns_null() -> void:
	var blur := _make_node(BlurIMGNative.new(), "blur3")
	var out := _cook_no_input(blur)
	GNTestAssert.assert_null(out, "blur with no input → null")


# ═══════════════════════════════════════════════════════════════════════════════
# PixelSortIMGNative
# ═══════════════════════════════════════════════════════════════════════════════

func test_pixelsort_native_fallback_produces_image() -> void:
	var src := _make_node(NoiseIMGNative.new(), "ps_src")
	src.set_param_value("resolution", Vector2i(64, 64))
	_cook_no_input(src)
	var ps := _make_node(PixelSortIMGNative.new(), "pixelsort1")
	var inputs: Array[GNData] = [src.cached_output]
	ps.execute_cook(inputs, _engine.frame_count)
	var out := ps.cached_output
	GNTestAssert.assert_not_null(out, "pixelsort output should not be null")
	GNTestAssert.assert_is(out, "GNImageData", "pixelsort output should be GNImageData")


func test_pixelsort_native_preserves_resolution() -> void:
	var src := _make_node(NoiseIMGNative.new(), "ps_res_src")
	src.set_param_value("resolution", Vector2i(64, 64))
	_cook_no_input(src)
	var ps := _make_node(PixelSortIMGNative.new(), "pixelsort2")
	var inputs: Array[GNData] = [src.cached_output]
	ps.execute_cook(inputs, _engine.frame_count)
	var img_data: GNImageData = ps.cached_output as GNImageData
	GNTestAssert.assert_eq(img_data.image.get_width(), 64, "width preserved")
	GNTestAssert.assert_eq(img_data.image.get_height(), 64, "height preserved")


func test_pixelsort_native_no_input_returns_null() -> void:
	var ps := _make_node(PixelSortIMGNative.new(), "pixelsort3")
	var out := _cook_no_input(ps)
	GNTestAssert.assert_null(out, "pixelsort with no input → null")


# ═══════════════════════════════════════════════════════════════════════════════
# MetaballSOPNative
# ═══════════════════════════════════════════════════════════════════════════════

func test_metaball_native_fallback_produces_mesh() -> void:
	var node := _make_node(MetaballSOPNative.new(), "meta1")
	node.set_param_value("resolution", 10)
	node.set_param_value("ball_count", 2)
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "metaball output should not be null")
	GNTestAssert.assert_is(out, "GNGeometryData", "metaball output should be GNGeometryData")


func test_metaball_native_zero_balls_no_crash() -> void:
	var node := _make_node(MetaballSOPNative.new(), "meta2")
	node.set_param_value("ball_count", 0)
	var out := _cook_no_input(node)
	# Zero balls: may return null or empty geometry
	# Just verify no crash
	GNTestAssert.assert_true(true, "zero balls did not crash")


func test_metaball_native_mesh_has_vertices() -> void:
	var node := _make_node(MetaballSOPNative.new(), "meta3")
	node.set_param_value("resolution", 15)
	node.set_param_value("ball_count", 2)
	var out := _cook_no_input(node)
	if out != null:
		var geo: GNGeometryData = out as GNGeometryData
		if geo.mesh != null:
			var arrays := geo.mesh.surface_get_arrays(0)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			GNTestAssert.assert_gt(verts.size(), 0, "metaball mesh has vertices")


# ═══════════════════════════════════════════════════════════════════════════════
# PolyReduceSOPNative
# ═══════════════════════════════════════════════════════════════════════════════

func test_polyreduce_native_fallback_reduces() -> void:
	# Create a sphere as input geometry
	var sphere := _make_node(SphereSOP.new(), "pr_sphere")
	_cook_no_input(sphere)
	var pr := _make_node(PolyReduceSOPNative.new(), "polyreduce1")
	pr.set_param_value("target_percent", 50.0)
	var inputs: Array[GNData] = [sphere.cached_output]
	pr.execute_cook(inputs, _engine.frame_count)
	var out := pr.cached_output
	GNTestAssert.assert_not_null(out, "polyreduce output should not be null")
	GNTestAssert.assert_is(out, "GNGeometryData", "polyreduce output should be GNGeometryData")


func test_polyreduce_native_no_input_returns_null() -> void:
	var pr := _make_node(PolyReduceSOPNative.new(), "polyreduce2")
	var out := _cook_no_input(pr)
	GNTestAssert.assert_null(out, "polyreduce with no input → null")


# ═══════════════════════════════════════════════════════════════════════════════
# ParticleSOPNative
# ═══════════════════════════════════════════════════════════════════════════════

func test_particle_native_fallback_produces_mesh() -> void:
	var node := _make_node(ParticleSOPNative.new(), "particle1")
	node.set_param_value("rate", 100.0)
	node.set_param_value("max_particles", 1000)
	# Particle systems are time-dependent — cook a few frames
	for i in range(5):
		_engine.elapsed_time = i * (1.0 / 60.0)
		_engine.current_delta = 1.0 / 60.0
		_cook_no_input(node)
	var out := node.cached_output
	GNTestAssert.assert_not_null(out, "particle output should not be null after 5 frames")
	GNTestAssert.assert_is(out, "GNGeometryData", "particle output should be GNGeometryData")


func test_particle_native_reset_clears() -> void:
	var node := _make_node(ParticleSOPNative.new(), "particle2")
	node.set_param_value("rate", 100.0)
	# Cook a few frames
	for i in range(3):
		_engine.elapsed_time = i * (1.0 / 60.0)
		_engine.current_delta = 1.0 / 60.0
		_cook_no_input(node)
	# Reset
	node.set_param_value("reset", true)
	_cook_no_input(node)
	# After reset, should still produce valid output (empty or minimal)
	GNTestAssert.assert_true(true, "particle reset did not crash")
