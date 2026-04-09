extends Node
## Tests for GNUrlCache — URL detection, cache path generation, and basic lifecycle.
##
## NOTE: These tests exercise offline/unit logic only (no actual HTTP fetching).
## Network fetch integration is tested indirectly via operator URL tests.

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
	# Clear any stale in-memory cache between tests
	GNUrlCache.clear_memory_cache()


func after_each() -> void:
	if is_instance_valid(_engine):
		remove_child(_engine)
		_engine.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# is_url
# ═══════════════════════════════════════════════════════════════════════════════

func test_is_url_https() -> void:
	GNTestAssert.assert_true(GNUrlCache.is_url("https://example.com/model.glb"),
		"https:// is a URL")

func test_is_url_http() -> void:
	GNTestAssert.assert_true(GNUrlCache.is_url("http://example.com/img.png"),
		"http:// is a URL")

func test_is_url_with_leading_spaces() -> void:
	GNTestAssert.assert_true(GNUrlCache.is_url("  https://example.com/file.obj"),
		"leading spaces stripped")

func test_is_url_case_insensitive() -> void:
	GNTestAssert.assert_true(GNUrlCache.is_url("HTTPS://Example.COM/file.glb"),
		"uppercase HTTPS is a URL")

func test_is_url_local_path_false() -> void:
	GNTestAssert.assert_false(GNUrlCache.is_url("C:/Models/box.glb"),
		"local path is not a URL")

func test_is_url_res_path_false() -> void:
	GNTestAssert.assert_false(GNUrlCache.is_url("res://models/box.glb"),
		"res:// is not a URL")

func test_is_url_project_path_false() -> void:
	GNTestAssert.assert_false(GNUrlCache.is_url("project://models/box.glb"),
		"project:// is not a URL")

func test_is_url_empty_false() -> void:
	GNTestAssert.assert_false(GNUrlCache.is_url(""),
		"empty string is not a URL")

func test_is_url_ftp_false() -> void:
	GNTestAssert.assert_false(GNUrlCache.is_url("ftp://files.example.com/a.obj"),
		"ftp:// is not recognized as URL")


# ═══════════════════════════════════════════════════════════════════════════════
# _cache_path_for (deterministic hashing)
# ═══════════════════════════════════════════════════════════════════════════════

func test_cache_path_preserves_extension() -> void:
	var path: String = GNUrlCache._cache_path_for("https://example.com/model.glb")
	GNTestAssert.assert_true(path.ends_with(".glb"), "preserves .glb extension")

func test_cache_path_different_urls_differ() -> void:
	var p1: String = GNUrlCache._cache_path_for("https://a.com/1.png")
	var p2: String = GNUrlCache._cache_path_for("https://b.com/2.png")
	GNTestAssert.assert_true(p1 != p2, "different URLs produce different paths")

func test_cache_path_same_url_same_path() -> void:
	var p1: String = GNUrlCache._cache_path_for("https://a.com/file.obj")
	var p2: String = GNUrlCache._cache_path_for("https://a.com/file.obj")
	GNTestAssert.assert_eq(p1, p2, "same URL produces same path")

func test_cache_path_starts_with_cache_dir() -> void:
	var path: String = GNUrlCache._cache_path_for("https://a.com/f.png")
	GNTestAssert.assert_true(path.begins_with(GNUrlCache.CACHE_DIR),
		"path starts with cache dir")

func test_cache_path_query_params_stripped_from_ext() -> void:
	var path: String = GNUrlCache._cache_path_for("https://a.com/f.png?v=2&token=abc")
	GNTestAssert.assert_true(path.ends_with(".png"), "query params stripped from extension")

func test_cache_path_no_extension_uses_bin() -> void:
	var path: String = GNUrlCache._cache_path_for("https://a.com/resource")
	GNTestAssert.assert_true(path.ends_with(".bin"), "no-ext URL uses .bin fallback")


# ═══════════════════════════════════════════════════════════════════════════════
# invalidate / clear
# ═══════════════════════════════════════════════════════════════════════════════

func test_invalidate_clears_entry() -> void:
	# Manually inject a cache entry
	GNUrlCache._entries["https://test.com/a.glb"] = {
		"status": "ready", "path": "/tmp/a.glb", "error": ""
	}
	GNUrlCache.invalidate("https://test.com/a.glb")
	GNTestAssert.assert_false(GNUrlCache._entries.has("https://test.com/a.glb"),
		"entry removed after invalidate")

func test_clear_memory_cache_removes_all() -> void:
	GNUrlCache._entries["https://test.com/b.glb"] = {
		"status": "ready", "path": "/tmp/b.glb", "error": ""
	}
	GNUrlCache._entries["https://test.com/c.png"] = {
		"status": "error", "path": "", "error": "fail"
	}
	GNUrlCache.clear_memory_cache()
	GNTestAssert.assert_eq(GNUrlCache._entries.size(), 0,
		"all entries cleared")


# ═══════════════════════════════════════════════════════════════════════════════
# resolve_url — with pre-seeded cache
# ═══════════════════════════════════════════════════════════════════════════════

func test_resolve_url_returns_ready_for_cached_entry() -> void:
	var url := "https://test.com/cached.glb"
	GNUrlCache._entries[url] = {
		"status": "ready", "path": "user://gonodes_url_cache/abc.glb", "error": ""
	}
	var dummy_node := Node.new()
	_engine.add_child(dummy_node)
	var result: Dictionary = GNUrlCache.resolve_url(url, dummy_node)
	GNTestAssert.assert_eq(result.status, "ready", "status is ready")
	GNTestAssert.assert_eq(result.path, "user://gonodes_url_cache/abc.glb",
		"cached path returned")
	dummy_node.queue_free()

func test_resolve_url_returns_error_for_failed_entry() -> void:
	var url := "https://test.com/fail.glb"
	GNUrlCache._entries[url] = {
		"status": "error", "path": "", "error": "HTTP 404"
	}
	var dummy_node := Node.new()
	_engine.add_child(dummy_node)
	var result: Dictionary = GNUrlCache.resolve_url(url, dummy_node)
	GNTestAssert.assert_eq(result.status, "error", "status is error")
	GNTestAssert.assert_true(result.error.contains("404"), "error message preserved")
	dummy_node.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# Operator URL integration (offline — cook with URL returns placeholder)
# ═══════════════════════════════════════════════════════════════════════════════

func _make_node(node: GNNode, nid: String) -> GNNode:
	node.initialize(nid)
	_network.add_node(node)
	_engine.add_child(node)
	return node

func _cook_no_input(node: GNNode) -> GNData:
	var inputs: Array[GNData] = []
	node.execute_cook(inputs, _engine.frame_count)
	return node.cached_output


func test_filein_sop_url_pending_returns_empty_geo() -> void:
	var node := _make_node(FileInSOP.new(), "filein_url1")
	node.set_param_value("file", "https://example.com/model.glb")
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "pending fetch returns non-null geo")
	GNTestAssert.assert_true(out is GNGeoData, "output is GNGeoData")

func test_filein_sop_url_cached_uses_local_path() -> void:
	var url := "https://example.com/model.glb"
	GNUrlCache._entries[url] = {
		"status": "ready", "path": "user://gonodes_url_cache/fake.glb", "error": ""
	}
	var node := _make_node(FileInSOP.new(), "filein_url2")
	node.set_param_value("file", url)
	# Will try to load the fake path (which won't exist) but should not crash
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "cached URL path does not crash")

func test_filein_sop_local_path_unaffected() -> void:
	var node := _make_node(FileInSOP.new(), "filein_url3")
	node.set_param_value("file", "C:/nonexistent/model.obj")
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "local path still works")


func test_imagefilein_img_url_pending_returns_empty() -> void:
	var node := _make_node(ImageFileInIMG.new(), "imgurl1")
	node.set_param_value("file", "https://example.com/photo.png")
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "pending fetch returns non-null")
	GNTestAssert.assert_true(out is GNImageData, "output is GNImageData")

func test_imagefilein_img_url_cached_uses_local_path() -> void:
	var url := "https://example.com/photo.png"
	GNUrlCache._entries[url] = {
		"status": "ready", "path": "user://gonodes_url_cache/fake.png", "error": ""
	}
	var node := _make_node(ImageFileInIMG.new(), "imgurl2")
	node.set_param_value("file", url)
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "cached URL path does not crash")

func test_imagefilein_img_local_path_unaffected() -> void:
	var node := _make_node(ImageFileInIMG.new(), "imgurl3")
	node.set_param_value("file", "C:/nonexistent/image.png")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(out == null or out is GNImageData, "local path still works")


func test_audiofilein_chop_url_pending_returns_empty() -> void:
	var node := _make_node(AudioFileInCHOP.new(), "audiourl1")
	node.set_param_value("file", "https://example.com/audio.wav")
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "pending fetch returns non-null")

func test_audiofilein_chop_local_path_unaffected() -> void:
	var node := _make_node(AudioFileInCHOP.new(), "audiourl2")
	node.set_param_value("file", "C:/nonexistent/audio.wav")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "local path does not crash")
