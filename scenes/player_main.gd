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
## config.json format:
##   {
##     "patch": "MyShow.gnpatch"
##   }
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

## Info label (shown only if no WindowOUT opens — fallback display).
var _info_label: Label = null

## Whether the debug info overlay is visible.  Toggle with F1.
var _debug_visible: bool = false


func _ready() -> void:
	# Initialize extension registry
	GNExtensionRegistry.instance().scan_extensions()
	GNExtensionRegistry.instance().scan_custom_assets()

	_parse_config()
	_apply_window_settings()

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

	# 3. CLI overrides — --patch <path> takes priority
	var args := OS.get_cmdline_args()
	for i in range(args.size()):
		if args[i] == "--patch" and i + 1 < args.size():
			var p: String = args[i + 1]
			if p.is_absolute_path():
				_patch_path = p
			else:
				_patch_path = exe_dir.path_join(p)


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
	add_child(cook_engine)

	cook_engine.frame_cooked.connect(_on_frame_cooked)
	cook_engine.cook_error.connect(_on_cook_error)

	# Force all WindowOUTs open — in the editor the user toggles "open" manually,
	# but in the Player every display window should appear automatically.
	_force_open_window_tops()

	# In player mode, all structural sinks (WindowOUT, file outputs, etc.) are
	# auto-detected by the cook engine via GNNode.is_sink.  No UI sinks needed.
	cook_engine.set_active_sinks([])

	_update_info("Running: %s (%d nodes)" % [
		_patch_path.get_file(), network.get_node_count()])

	print("[GONODES Player] Loaded: %s (%d nodes, %d connections)" % [
		_patch_path, network.get_node_count(), network.get_connection_count()])


# ═══════════════════════════════════════════════════════════════════════════════
# Runtime Callbacks
# ═══════════════════════════════════════════════════════════════════════════════

func _on_frame_cooked(frame: int, cook_time_ms: float) -> void:
	# Light status update every 60 frames
	if frame % 60 == 0:
		_update_info("Frame %d | Cook %.1fms | %s" % [
			frame, cook_time_ms, _patch_path.get_file()])


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
