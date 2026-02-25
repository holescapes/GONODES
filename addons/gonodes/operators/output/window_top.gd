class_name WindowTOP
extends GNNode
## Displays a TOP texture input in a standalone OS window.
## Supports multiple monitors, fullscreen/borderless/windowed modes,
## and positioning on any connected display.
##
## This is a terminal node (no output ports) — it's a display sink.
## Multiple WindowTOP instances create multiple output windows.
## The Window node is a child of this GNNode in the scene tree —
## freed automatically when the node is removed.

## Window mode options matching Godot's Window.Mode.
enum WindowMode { WINDOWED, FULLSCREEN, BORDERLESS }

## The OS-level Window node.
var _window: Window = null

## TextureRect inside the window that shows the TOP texture.
var _display_rect: TextureRect = null

## Whether the window has been created.
var _window_created: bool = false


func _init() -> void:
	node_type = "window"
	family = GNFamily.Type.TOP


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP)
	# No outputs — this is a display sink


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("title", "GONODES Output", "Title"))

	# Monitor selection — 0 = primary, 1 = secondary, etc.
	add_parameter(GNParameter.create_int("monitor", 0, 0, 8))

	add_parameter(GNParameter.create_enum("window_mode",
		PackedStringArray(["Windowed", "Fullscreen", "Borderless"]), 0))

	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(1920, 1080)))

	# Position: (-1, -1) = auto-center on target monitor
	add_parameter(GNParameter.create_vector2i("position", Vector2i(-1, -1)))

	add_parameter(GNParameter.create_bool("always_on_top", false))
	add_parameter(GNParameter.create_bool("vsync", true))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null

	_ensure_window()

	# Apply parameters
	_apply_window_params()

	# Feed the texture — this is a live GPU reference (zero-copy)
	if tex_in != null and tex_in.texture != null:
		_display_rect.texture = tex_in.texture
		_display_rect.visible = true
	else:
		_display_rect.visible = false

	# WindowTOP has no output — it's a display sink
	return null


## Lazily creates the Window + TextureRect for display output.
## Window is added as a child of this Node — it becomes a separate OS window.
func _ensure_window() -> void:
	if _window_created:
		return

	_window = Window.new()
	_window.name = "GNOutput_%s" % id
	_window.title = "GONODES Output"
	_window.size = Vector2i(1920, 1080)
	_window.min_size = Vector2i(160, 120)
	# Prevent the window from stealing main window focus on close
	_window.close_requested.connect(_on_window_close_requested)

	# Create TextureRect stretching to fill the window
	_display_rect = TextureRect.new()
	_display_rect.name = "Display"
	_display_rect.anchors_preset = Control.PRESET_FULL_RECT
	_display_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_display_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_window.add_child(_display_rect)

	# Add as child of this Node — Godot creates it as a separate OS window
	add_child(_window)

	_window_created = true
	GNLogger.info("WindowTOP", "'%s' output window created: '%s'" % [id, _window.title])


## Applies current parameter values to the Window node.
func _apply_window_params() -> void:
	if _window == null:
		return

	var title_val: String = get_param_value("title")
	var monitor_idx: int = get_param_value("monitor")
	var mode_idx: int = get_param_value("window_mode")
	var res: Vector2i = get_param_value("resolution")
	var pos: Vector2i = get_param_value("position")
	var on_top: bool = get_param_value("always_on_top")
	var vsync_val: bool = get_param_value("vsync")

	_window.title = title_val
	_window.always_on_top = on_top

	# Apply V-Sync
	if vsync_val:
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED, _window.get_window_id())
	else:
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_DISABLED, _window.get_window_id())

	# Apply window mode
	match mode_idx:
		WindowMode.WINDOWED:
			_window.mode = Window.MODE_WINDOWED
			_window.borderless = false
			if _window.size != res:
				_window.size = res
		WindowMode.FULLSCREEN:
			_window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		WindowMode.BORDERLESS:
			_window.mode = Window.MODE_WINDOWED
			_window.borderless = true
			# Set to monitor's full resolution in borderless mode
			var screen_count := DisplayServer.get_screen_count()
			var target_monitor := clampi(monitor_idx, 0, screen_count - 1)
			var screen_size := DisplayServer.screen_get_size(target_monitor)
			_window.size = screen_size

	# Position the window on the target monitor
	_position_on_monitor(monitor_idx, pos, mode_idx)


## Positions the window on the specified monitor.
func _position_on_monitor(monitor_idx: int, pos: Vector2i, mode_idx: int) -> void:
	var screen_count := DisplayServer.get_screen_count()
	if screen_count == 0:
		return

	var target_monitor := clampi(monitor_idx, 0, screen_count - 1)
	var screen_pos := DisplayServer.screen_get_position(target_monitor)
	var screen_size := DisplayServer.screen_get_size(target_monitor)

	if pos == Vector2i(-1, -1):
		# Auto-center on target monitor
		if mode_idx == WindowMode.WINDOWED:
			var win_size := _window.size
			var centered := screen_pos + (screen_size - win_size) / 2
			_window.position = centered
		else:
			_window.position = screen_pos
	else:
		# Explicit position relative to the target monitor's origin
		_window.position = screen_pos + pos


## Called when the user clicks the window's close button.
func _on_window_close_requested() -> void:
	# Hide instead of destroying — the window can be re-shown
	if _window:
		_window.visible = false
		GNLogger.info("WindowTOP", "'%s' output window hidden by user" % id)


## Returns info about all connected displays (for UI picker / expression use).
static func get_display_info() -> Array[Dictionary]:
	var displays: Array[Dictionary] = []
	for i in range(DisplayServer.get_screen_count()):
		displays.append({
			"index": i,
			"position": DisplayServer.screen_get_position(i),
			"size": DisplayServer.screen_get_size(i),
		})
	return displays
