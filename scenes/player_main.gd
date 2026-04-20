extends Control
## GONODES Player — Minimal runtime for exported patches.
##
## Loads a .gnpatch file + config.json, boots the cook engine, and runs the
## patch headlessly (no editor UI).  WindowOUT nodes open their own OS windows
## for display output.
##
## Usage:
##   GONODESPlayer.exe                     — looks for config.json next to exe
##   GONODESPlayer.exe --patch path.gnpatch — explicit patch path
##   GONODESPlayer.exe --rendering-method mobile  — force renderer (power users)
##
## Web usage:
##   The patch can be baked into the .pck (Full Export) or loaded from a URL
##   via the `patch_url` query parameter or config.json `patch_url` key.
##   Requires COOP/COEP headers for SharedArrayBuffer (threads):
##     Cross-Origin-Opener-Policy: same-origin
##     Cross-Origin-Embedder-Policy: require-corp
##
## config.json format:
##   {
##     "patch": "MyShow.gnpatch",
##     "patch_url": "https://example.com/patches/MyShow.gnpatch",
##     "settings": {
##       "log_level": 1,
##       "log_to_file": false,
##       "parallel_cook_enabled": false,
##       "max_cooks_per_frame": 0
##     }
##   }
##
## CLI overrides:
##   --patch <file.gnpatch>
##   --log-level <0-3>        (0=Debug, 1=Info, 2=Warn, 3=Error)
##   --log-file [path]        (enable file logging; default: gonodes.log next to exe)
##   --parallel-cook          (enable parallel cooking)
##   --max-cooks <N>          (0=unlimited)
##
## Rendering backend is automatic — Forward+ with fallback to Compatibility
## (OpenGL 3.3) via the fallback_to_opengl3 project setting baked into the .pck.
## Power users can override with --rendering-method on the command line.
## VSync and window settings are controlled by each WindowOUT in the patch.

const _CONFIG_FILE := "config.json"

var network: GNNetwork = null
var cook_engine: GNCookEngine = null

## Resolved absolute path to the .gnpatch file.
var _patch_path: String = ""

## Project directory (sibling folder to .gnpatch).
var _project: GNProjectManager = GNProjectManager.new()

## Parsed config dictionary.
var _config: Dictionary = {}

## URL for remote patch loading (web).
var _patch_url: String = ""

## Info label (shown only if no WindowOUT opens — fallback display).
var _info_label: Label = null

## Whether the debug info overlay is visible.  Toggle with F1.
var _debug_visible: bool = false

## JS↔GDScript bridge signals (web only — called via JavaScriptBridge.create_callback).
## Emitted when the player is ready to receive patches.
signal player_ready()
## Emitted when a patch has been loaded and cooking starts.
signal patch_loaded(patch_name: String)
## Emitted on errors.
signal player_error(message: String)


func _ready() -> void:
	# Initialize extension registry
	GNExtensionRegistry.instance().scan_extensions()
	GNExtensionRegistry.instance().scan_custom_assets()

	_parse_config()
	_apply_window_settings()

	if _patch_path.is_empty() and _patch_url.is_empty():
		# On web, try reading the patch_url from the URL query string
		if GNGpuContext.get_current_platform() == "web":
			_patch_url = _get_url_param("patch_url")

	# Register JS bridge callbacks (web only)
	if GNGpuContext.get_current_platform() == "web":
		_register_js_bridge()

	if not _patch_url.is_empty():
		# Load patch from URL (web)
		_setup_info_display()
		_update_info("Loading patch from URL...")
		_fetch_patch_from_url(_patch_url)
		return

	if _patch_path.is_empty():
		_show_error("No patch file specified.\n\nPlace a config.json next to the executable,\nor launch with --patch <file.gnpatch>")
		return

	_setup_info_display()
	_load_and_run()


# ═══════════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════════

## Parses config.json and CLI arguments.  CLI args override config values.
func _parse_config() -> void:
	# 1. Try to load config.json from next to the executable
	var exe_dir := OS.get_executable_path().get_base_dir()
	var config_path := exe_dir.path_join(_CONFIG_FILE)

	if FileAccess.file_exists(config_path):
		var file := FileAccess.open(config_path, FileAccess.READ)
		if file != null:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				_config = json.data
			file.close()

	# 2. Resolve patch path from config
	var config_patch: String = _config.get("patch", "")
	if not config_patch.is_empty():
		if config_patch.is_absolute_path():
			_patch_path = config_patch
		else:
			# Relative to exe directory
			_patch_path = exe_dir.path_join(config_patch)

	# 2b. Resolve patch URL from config (web)
	var config_url: String = _config.get("patch_url", "")
	if not config_url.is_empty():
		_patch_url = config_url

	# 3. CLI overrides — --patch <path> takes priority
	var args := OS.get_cmdline_args()
	for i in range(args.size()):
		if args[i] == "--patch" and i + 1 < args.size():
			var p: String = args[i + 1]
			if p.is_absolute_path():
				_patch_path = p
			else:
				_patch_path = exe_dir.path_join(p)
		elif args[i] == "--log-level" and i + 1 < args.size():
			_config_settings()["log_level"] = int(args[i + 1])
		elif args[i] == "--parallel-cook":
			_config_settings()["parallel_cook_enabled"] = true
		elif args[i] == "--max-cooks" and i + 1 < args.size():
			_config_settings()["max_cooks_per_frame"] = int(args[i + 1])
		elif args[i] == "--log-file":
			# Optional path argument — if next arg doesn't look like a flag, use it
			if i + 1 < args.size() and not args[i + 1].begins_with("--"):
				_config_settings()["log_file"] = args[i + 1]
			else:
				_config_settings()["log_to_file"] = true


## Returns the settings sub-dictionary from config, creating it if absent.
func _config_settings() -> Dictionary:
	if not _config.has("settings"):
		_config["settings"] = {}
	return _config["settings"]


## Applies runtime settings from config.json to the cook engine and logger.
## Called after cook_engine is created but before add_child.
## CLI args override config values (already merged in _parse_config).
func _apply_runtime_settings() -> void:
	var s: Dictionary = _config_settings()
	cook_engine.parallel_cook_enabled = s.get("parallel_cook_enabled", false)
	cook_engine.max_cooks_per_frame = s.get("max_cooks_per_frame", 0)
	var log_lvl: int = s.get("log_level", 1)
	GNLogger.level = log_lvl as GNLogger.Level

	# File logging — explicit path wins, then boolean toggle
	var log_file_path: String = s.get("log_file", "")
	if not log_file_path.is_empty():
		GNLogger.set_log_file(log_file_path)
	elif s.get("log_to_file", false):
		var exe_dir := OS.get_executable_path().get_base_dir()
		GNLogger.set_log_file(exe_dir.path_join("gonodes.log"))


## Applies startup settings to the main window.
## VSync, display settings, and window layout are handled by each WindowOUT
## node in the patch — not by config.json.
func _apply_window_settings() -> void:
	var win := get_window()
	if win == null:
		return

	# Auto-title from patch filename (e.g. "GONODES — MyShow")
	var patch_name: String = _config.get("patch", "")
	if not patch_name.is_empty():
		win.title = "GONODES — %s" % patch_name.get_basename()
	else:
		win.title = "GONODES Player"


# ═══════════════════════════════════════════════════════════════════════════════
# Patch Loading & Cook Engine
# ═══════════════════════════════════════════════════════════════════════════════

## Loads the patch and starts the cook engine.
func _load_and_run() -> void:
	# Load the network from the .gnpatch file
	network = GNNetwork.new()
	var err := network.load_from_file(_patch_path)
	if err != OK:
		_show_error("Failed to load patch:\n%s\n\nError code: %d" % [_patch_path, err])
		return

	# Set up project folder (assets live in sibling folder)
	_project.set_from_patch_path(_patch_path)

	# Create and configure the cook engine
	cook_engine = GNCookEngine.new()
	cook_engine.name = "CookEngine"
	cook_engine.network = network
	cook_engine.project_dir = _project.project_dir
	_apply_runtime_settings()
	add_child(cook_engine)

	cook_engine.frame_cooked.connect(_on_frame_cooked)
	cook_engine.cook_error.connect(_on_cook_error)

	# Force all WindowOUTs open — in the editor the user toggles "open" manually,
	# but in the Player every display window should appear automatically.
	_force_open_window_tops()

	# In player mode, all structural sinks (WindowOUT, file outputs, etc.) are
	# auto-detected by the cook engine via GNNode.is_sink.  No UI sinks needed.
	cook_engine.set_active_sinks([])

	var ver: String = ProjectSettings.get_setting("application/config/version", "dev")
	_update_info("GONODES v%s | %s (%d nodes)" % [
		ver, _patch_path.get_file(), network.get_node_count()])

	print("[GONODES Player v%s] Loaded: %s (%d nodes, %d connections)" % [
		ver, _patch_path, network.get_node_count(), network.get_connection_count()])


# ═══════════════════════════════════════════════════════════════════════════════
# Runtime Callbacks
# ═══════════════════════════════════════════════════════════════════════════════

func _on_frame_cooked(frame: int, cook_time_ms: float) -> void:
	# Light status update every 60 frames
	if frame % 60 == 0:
		var ver: String = ProjectSettings.get_setting("application/config/version", "dev")
		_update_info("GONODES v%s | Frame %d | Cook %.1fms | %s" % [
			ver, frame, cook_time_ms, _patch_path.get_file()])


func _on_cook_error(node_id: String, error_message: String) -> void:
	push_warning("[GONODES Player] Cook error on '%s': %s" % [node_id, error_message])


## Handle hotkeys:
##   Escape — quit the player
##   F1     — toggle debug info overlay
##   F11    — toggle fullscreen
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				print("[GONODES Player] Escape pressed — quitting.")
				get_tree().quit()
			KEY_F1:
				_debug_visible = not _debug_visible
				if _info_label != null:
					_info_label.visible = _debug_visible
			KEY_F11:
				var win := get_window()
				if win != null:
					if win.mode == Window.MODE_FULLSCREEN:
						win.mode = Window.MODE_WINDOWED
					else:
						win.mode = Window.MODE_FULLSCREEN


# ═══════════════════════════════════════════════════════════════════════════════
# UI Helpers (minimal — player has almost no UI)
# ═══════════════════════════════════════════════════════════════════════════════

## Force every WindowOUT in the network to open automatically.
## In the editor the user toggles "open" manually; in the Player all display
## windows should appear immediately on launch.
func _force_open_window_tops() -> void:
	if network == null:
		return
	var count: int = 0
	for node in network.nodes.values():
		if node.node_type == "window":
			node.set_param_value("open", true)
			count += 1
	if count > 0:
		print("[GONODES Player] Auto-opened %d WindowOUT(s)." % count)


## Sets up a minimal info label for debug overlay (hidden by default, F1 to show).
func _setup_info_display() -> void:
	_info_label = Label.new()
	_info_label.name = "InfoLabel"
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_info_label.anchors_preset = PRESET_FULL_RECT
	_info_label.add_theme_font_size_override("font_size", 14)
	_info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_info_label.text = "Loading patch..."
	_info_label.visible = _debug_visible
	add_child(_info_label)


func _update_info(text: String) -> void:
	if _info_label != null:
		_info_label.text = text


## Shows a fatal error message and stops.
func _show_error(message: String) -> void:
	var lbl := Label.new()
	lbl.text = message
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.anchors_preset = PRESET_FULL_RECT
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	add_child(lbl)
	push_error("[GONODES Player] %s" % message)
	player_error.emit(message)


# ═══════════════════════════════════════════════════════════════════════════════
# Web Runtime — URL Patch Loading & JS Bridge
# ═══════════════════════════════════════════════════════════════════════════════

## Fetches a .gnpatch file from a URL via HTTPRequest (web/desktop).
func _fetch_patch_from_url(url: String) -> void:
	var http := HTTPRequest.new()
	http.name = "PatchFetcher"
	add_child(http)
	http.request_completed.connect(_on_patch_url_fetched.bind(http))
	var err := http.request(url)
	if err != OK:
		_show_error("Failed to start HTTP request: %d\nURL: %s" % [err, url])
		http.queue_free()


## Callback when URL fetch completes.
func _on_patch_url_fetched(result: int, response_code: int, _headers: PackedStringArray,
		body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_show_error("Failed to fetch patch from URL.\nHTTP %d (result: %d)\nURL: %s" % [
			response_code, result, _patch_url])
		return

	# Parse the JSON patch data directly from the response body
	var json_str: String = body.get_string_from_utf8()
	if json_str.is_empty():
		_show_error("Empty response from patch URL.")
		return

	network = GNNetwork.new()
	var json := JSON.new()
	if json.parse(json_str) != OK or not (json.data is Dictionary):
		_show_error("Failed to parse patch data from URL.\n%s" % json.get_error_message())
		return

	network.from_dict(json.data)

	# Set up cook engine
	cook_engine = GNCookEngine.new()
	cook_engine.name = "CookEngine"
	cook_engine.network = network
	add_child(cook_engine)

	cook_engine.frame_cooked.connect(_on_frame_cooked)
	cook_engine.cook_error.connect(_on_cook_error)

	_force_open_window_tops()
	cook_engine.set_active_sinks([])

	var patch_name: String = _patch_url.get_file()
	var ver2: String = ProjectSettings.get_setting("application/config/version", "dev")
	_update_info("GONODES v%s | %s (%d nodes)" % [ver2, patch_name, network.get_node_count()])
	patch_loaded.emit(patch_name)

	print("[GONODES Player v%s] Loaded from URL: %s (%d nodes)" % [
		ver2, _patch_url, network.get_node_count()])


## Reads a query parameter from the browser URL (web only).
## Falls back to empty string on non-web platforms.
func _get_url_param(param_name: String) -> String:
	if GNGpuContext.get_current_platform() != "web":
		return ""
	# Use JavaScriptBridge to read URL search params
	var js_code := "new URLSearchParams(window.location.search).get('%s') || ''" % param_name
	var result = JavaScriptBridge.eval(js_code)
	if result is String:
		return result
	return ""


## Registers JavaScript-callable functions for the JS↔GDScript bridge.
## Allows host pages to control the player:
##   window.gonodesLoadPatch(url) — load a patch from URL
##   window.gonodesSetParam(nodeId, paramName, value) — set a parameter
func _register_js_bridge() -> void:
	if GNGpuContext.get_current_platform() != "web":
		return
	# Expose a callback for dynamic patch loading
	var load_cb := JavaScriptBridge.create_callback(_js_load_patch)
	JavaScriptBridge.eval("window.gonodesLoadPatch = %s" % str(load_cb))
	var param_cb := JavaScriptBridge.create_callback(_js_set_param)
	JavaScriptBridge.eval("window.gonodesSetParam = %s" % str(param_cb))
	player_ready.emit()


## JS callback: window.gonodesLoadPatch(url)
func _js_load_patch(args: Array) -> void:
	if args.size() < 1 or not (args[0] is String):
		return
	var url: String = args[0]
	if url.is_empty():
		return
	_patch_url = url
	_fetch_patch_from_url(url)


## JS callback: window.gonodesSetParam(nodeId, paramName, value)
func _js_set_param(args: Array) -> void:
	if args.size() < 3:
		return
	var node_id: String = str(args[0])
	var param_name: String = str(args[1])
	var value = args[2]
	if cook_engine != null and network != null:
		var node: GNNode = network.nodes.get(node_id, null)
		if node != null:
			node.set_param_value(param_name, value)
