class_name WindowTOP
extends GNTopBase
## Displays a TOP texture input in a standalone OS window.
## Supports multiple monitors, fullscreen/borderless/windowed modes,
## and positioning on any connected display.
##
## This is a terminal node (no output ports) — it's a display sink.
## Multiple WindowTOP instances create multiple output windows.
## The Window node is a child of this GNNode in the scene tree —
## freed automatically when the node is removed.
##
## NOTE: Always use the 'monitor' parameter to assign the output display.
## Manually dragging the window to another screen causes tearing because
## Windows DWM doesn't re-sync the GPU swapchain to the new display.

## Window mode options matching Godot's Window.Mode.
enum WindowMode { WINDOWED, FULLSCREEN, BORDERLESS }

## The OS-level Window node.
var _window: Window = null

## TextureRect inside the window that shows the TOP texture.
var _display_rect: TextureRect = null

## Whether the window has been created.
var _window_created: bool = false

## Whether window-level params need re-applying (set by own param changes only).
var _window_params_dirty: bool = true


func _init() -> void:
	node_type = "window"
	is_sink = true
	node_description = "Display a texture in a standalone OS window (VJ output)."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Texture to display in the window")
	# No outputs — this is a display sink


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("open", false, "Open", "Show/hide the output window"))
	add_parameter(GNParameter.create_string("title", "GONODES Output", "Title", "Window title bar text"))

	# Monitor selection — 0 = primary, 1 = secondary, etc.
	add_parameter(GNParameter.create_int("monitor", 0, 0, 8, "", "Target display index (0 = primary)"))

	add_parameter(GNParameter.create_enum("window_mode",
		PackedStringArray(["Windowed", "Fullscreen", "Borderless"]), 0, "", "Window display mode"))

	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "", "Window resolution in pixels"))

	# Position: (-1, -1) = auto-center on target monitor
	add_parameter(GNParameter.create_vector2i("position", Vector2i(-1, -1), "", "Window position (-1,-1 = auto center)"))

	add_parameter(GNParameter.create_bool("always_on_top", false, "", "Keep window above all other windows"))
	add_parameter(GNParameter.create_bool("vsync", true, "", "Enable vertical sync"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null

	_ensure_window()

	# Sync window visibility with the "open" parameter
	var should_open: bool = get_param_value("open")
	if _window != null and _window.visible != should_open:
		_window.visible = should_open
		if should_open:
			GNLogger.info("WindowTOP", "'%s' output window re-opened via parameter" % id)

	# Apply lightweight params every frame (title, texture)
	if _window != null:
		_window.title = get_param_value("title")

	# Apply heavyweight window params only when OUR params changed
	# (not when upstream input changes mark us cook-dirty)
	if _window_params_dirty:
		_apply_window_params()
		_window_params_dirty = false

	# Feed the texture — direct GPU reference, zero-copy.
	# SubViewport.get_texture() returns a ViewportTexture with a direct RID
	# to the GPU render target. No path resolution needed when assigned
	# programmatically, so it works across Viewport boundaries.
	if tex_in != null and tex_in.texture != null:
		if _display_rect.texture != tex_in.texture:
			_display_rect.texture = tex_in.texture
			GNLogger.debug("WindowTOP", "'%s' texture assigned (zero-copy GPU)" % id)
		# Force the output window to present this frame's content immediately.
		# Without this, the separate Window viewport may not redraw every frame
		# because Godot only auto-redraws when it detects a property change on
		# the TextureRect — but ViewportTexture updates in-place via its RID.
		_display_rect.queue_redraw()
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
	# ESC key exits fullscreen/borderless back to windowed mode.
	# Input events in a child Window stay in that window's viewport tree,
	# so we must listen directly on the Window rather than from _process().
	_window.window_input.connect(_on_window_input)

	# Create TextureRect stretching to fill the window
	_display_rect = TextureRect.new()
	_display_rect.name = "Display"
	_display_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_display_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_window.add_child(_display_rect)

	# Must be called AFTER adding to tree — the property setter anchors_preset
	# only sets anchors but not offsets, leaving the rect at 0×0.
	_display_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

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

	# Apply V-Sync — standard VSYNC_ENABLED for tear-free output.
	# The queue_redraw() call in _cook() ensures the output window redraws
	# every cook frame, keeping it in sync with the viewer panel.
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
			# Borderless fills the target monitor (native Godot behaviour)
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
	# Hide instead of destroying — flip the "open" param so the inspector
	# reflects the current state and the user can toggle it back on.
	if _window:
		_window.visible = false
		set_param_value("open", false)
		GNLogger.info("WindowTOP", "'%s' output window hidden by user" % id)


## Called for input events inside the output window.
## ESC reverts fullscreen/borderless back to windowed mode.
func _on_window_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		var mode_idx: int = get_param_value("window_mode")
		if mode_idx != WindowMode.WINDOWED:
			set_param_value("window_mode", WindowMode.WINDOWED)
			_window_params_dirty = true
			GNLogger.info("WindowTOP", "'%s' ESC — switched to windowed mode" % id)


## Override: mark window params dirty when our own parameters change.
func _on_parameter_changed(p_name: String, _new_value: Variant) -> void:
	super._on_parameter_changed(p_name, _new_value)
	_window_params_dirty = true


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
