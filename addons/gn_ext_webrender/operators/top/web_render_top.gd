class_name WebRenderTOP
extends GNTopBase
## Renders a web page (HTML/CSS/JS) to a texture via Chromium Embedded Framework.
##
## Requires the gdCEF GDExtension (Lecrapouille/gdcef).
## Place the `cef_artifacts` folder inside the extension directory
## (`addons/gn_ext_webrender/cef_artifacts/`), or build from the
## bundled source in `addons/gn_ext_webrender/native/gdcef/`.
##
## Modes:
##   • URL — loads a web page from a URL
##   • HTML — renders inline HTML/CSS/JS content directly
##
## The rendered page is output as a GNTextureData each cook frame.


# ═══════════════════════════════════════════════════════════════════════════════
# Internals
# ═══════════════════════════════════════════════════════════════════════════════

## Shared GDCEF node — one per scene tree, lazily created.
static var _cef_node: Node = null
static var _cef_initialized := false

## This operator's browser instance.
var _browser: Node = null

## Offscreen TextureRect used by gdCEF as a render target.
var _tex_rect: TextureRect = null

## Tracks the last loaded URL / HTML to avoid reloading every cook.
var _last_url: String = ""
var _last_html: String = ""
var _last_res: Vector2i = Vector2i.ZERO


func _init() -> void:
	node_type = "webrender"
	time_dependent = true
	node_description = "Render a web page (URL or inline HTML) to a texture via Chromium (gdCEF)."


func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "linux"])


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Rendered web page")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["URL", "HTML"]), 0,
		"Mode", "Load from URL or render inline HTML"))
	add_parameter(GNParameter.create_string("url",
		"https://godotengine.org", "URL",
		"Web page URL to render (URL mode)"))
	add_parameter(GNParameter.create_string("html", """<!DOCTYPE html>
<html><body style="background:#222;color:#eee;font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0">
<h1>WebRenderTOP</h1></body></html>""",
		"HTML", "Inline HTML content (HTML mode)"))
	add_parameter(GNParameter.create_vector2i("resolution",
		Vector2i(1280, 720), "Resolution",
		"Browser viewport size in pixels"))
	add_parameter(GNParameter.create_int("fps", 30, 1, 120,
		"FPS", "Browser rendering frame rate"))
	add_parameter(GNParameter.create_string("javascript", "",
		"JavaScript", "Execute JS snippet each cook (optional)"))
	add_parameter(GNParameter.create_bool("active", true,
		"Active", "Enable/disable rendering"))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(_inputs: Array[GNData]) -> GNData:
	if not _is_cef_available():
		node_warning = "gdCEF not available. Place cef_artifacts/ in addons/gn_ext_webrender/."
		return null

	if not get_param_value("active"):
		return _cached_tex_data

	var res: Vector2i = get_param_value("resolution")
	var mode: int = get_param_value("mode")

	# Lazy-init the shared GDCEF singleton
	_ensure_cef_node()
	if not _cef_initialized:
		node_warning = "CEF failed to initialize."
		return null

	# Create or resize browser
	_ensure_browser(res)
	if _browser == null:
		node_warning = "Failed to create CEF browser."
		return null

	# Load content
	match mode:
		0:  # URL
			var url: String = get_param_value("url")
			if url != _last_url:
				_browser.call("load_url", url)
				_last_url = url
				_last_html = ""
		1:  # HTML
			var html: String = get_param_value("html")
			if html != _last_html:
				_browser.call("load_data_uri", html, "text/html")
				_last_html = html
				_last_url = ""

	# Execute optional JavaScript
	var js: String = get_param_value("javascript")
	if not js.is_empty():
		_browser.call("execute_javascript", js)

	# Read the rendered texture
	var browser_tex: ImageTexture = _browser.call("get_texture") as ImageTexture
	if browser_tex == null:
		return _cached_tex_data

	if _cached_tex_data == null:
		_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = browser_tex
	_cached_tex_data.resolution = res
	return _cached_tex_data


# ═══════════════════════════════════════════════════════════════════════════════
# CEF lifecycle helpers
# ═══════════════════════════════════════════════════════════════════════════════

static func _is_cef_available() -> bool:
	return ClassDB.class_exists(&"GDCEF") and ClassDB.class_exists(&"GdBrowserView")


func _ensure_cef_node() -> void:
	if _cef_initialized:
		return

	if _cef_node != null and is_instance_valid(_cef_node):
		_cef_initialized = true
		return

	# Create the shared GDCEF node and add it to the scene tree
	_cef_node = ClassDB.instantiate(&"GDCEF")
	if _cef_node == null:
		GNLogger.error("WebRenderTOP", "Failed to instantiate GDCEF node")
		return

	# Must be in tree before initialize()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		GNLogger.error("WebRenderTOP", "No scene tree available for GDCEF")
		return

	tree.root.call_deferred("add_child", _cef_node)
	# Cannot call initialize until the node is actually in the tree;
	# defer the initialization to next frame.
	_cef_node.set_meta("_gn_pending_init", true)

	# Try initialize immediately if already in tree
	if _cef_node.is_inside_tree():
		_do_cef_init()
	else:
		_cef_node.tree_entered.connect(_do_cef_init, CONNECT_ONE_SHOT)


func _do_cef_init() -> void:
	if _cef_initialized:
		return
	var ok: bool = _cef_node.call("initialize", {"incognito": true})
	if ok:
		_cef_initialized = true
		GNLogger.info("WebRenderTOP", "CEF initialized successfully")
	else:
		GNLogger.error("WebRenderTOP", "CEF initialization failed: %s" % str(_cef_node.call("get_error")))


func _ensure_browser(res: Vector2i) -> void:
	if _browser != null and is_instance_valid(_browser):
		# Resize if resolution changed
		if res != _last_res:
			_browser.call("resize", Vector2(res.x, res.y))
			_tex_rect.size = Vector2(res.x, res.y)
			_last_res = res
		return

	# Create an off-screen TextureRect for gdCEF to render into
	_tex_rect = TextureRect.new()
	_tex_rect.size = Vector2(res.x, res.y)
	_tex_rect.visible = false
	_cef_node.add_child(_tex_rect)

	var fps: int = get_param_value("fps")
	_browser = _cef_node.call("create_browser", "about:blank", _tex_rect, {
		"frame_rate": fps,
		"javascript": true,
		"webgl": true,
	})

	if _browser == null:
		GNLogger.error("WebRenderTOP", "'%s': create_browser failed" % id)
		return

	_last_res = res
	_last_url = ""
	_last_html = ""


func _on_node_removed() -> void:
	if _browser != null and is_instance_valid(_browser):
		_browser.call("close")
		_browser = null
	if _tex_rect != null and is_instance_valid(_tex_rect):
		_tex_rect.queue_free()
		_tex_rect = null


# ═══════════════════════════════════════════════════════════════════════════════
# Viewer Input Forwarding
# ═══════════════════════════════════════════════════════════════════════════════

## Forwards mouse and keyboard events from the viewer to the CEF browser.
## Returns true if the event was consumed (viewer skips pan/zoom).
func handle_viewer_input(event: InputEvent, local_pos: Vector2, viewer = null, port_index: int = 0) -> bool:
	if _browser == null or not is_instance_valid(_browser):
		return false

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_browser.call("set_mouse_left_down")
				else:
					_browser.call("set_mouse_left_up")
			MOUSE_BUTTON_RIGHT:
				if mb.pressed:
					_browser.call("set_mouse_right_down")
				else:
					_browser.call("set_mouse_right_up")
			MOUSE_BUTTON_MIDDLE:
				if mb.pressed:
					_browser.call("set_mouse_middle_down")
				else:
					_browser.call("set_mouse_middle_up")
			MOUSE_BUTTON_WHEEL_UP:
				_browser.call("set_mouse_wheel_vertical", 2,
					mb.shift_pressed, mb.ctrl_pressed, mb.alt_pressed)
			MOUSE_BUTTON_WHEEL_DOWN:
				_browser.call("set_mouse_wheel_vertical", -2,
					mb.shift_pressed, mb.ctrl_pressed, mb.alt_pressed)
			_:
				return false
		return true

	elif event is InputEventMouseMotion:
		# Map viewer local position to browser pixel coordinates
		var res: Vector2i = get_param_value("resolution")
		var bx: int = clampi(int(local_pos.x), 0, res.x - 1)
		var by: int = clampi(int(local_pos.y), 0, res.y - 1)
		_browser.call("set_mouse_moved", bx, by)
		return true

	elif event is InputEventKey:
		var ke := event as InputEventKey
		var code: int = ke.unicode if ke.unicode != 0 else ke.keycode
		_browser.call("set_key_pressed", code, ke.pressed,
			ke.shift_pressed, ke.alt_pressed, ke.is_command_or_control_pressed())
		return true

	return false
