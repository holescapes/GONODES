class_name WindowOUT
extends GNOutBase
## Displays a TOP texture input in a standalone OS window.
## Supports multiple monitors, fullscreen/borderless/windowed modes,
## and positioning on any connected display.
##
## This is a terminal sink (no output ports) — display only.
## Multiple WindowOUT instances create multiple output windows.
## The Window node is a child of this GNNode in the scene tree —
## freed automatically when the node is removed.
##
## Interactive panels: when the input texture carries panel_sources from a
## PanelTOP, WindowOUT forwards mouse events to the panel's SubViewport.
## Motion events are remapped and pushed via push_input() for hover.
## Click events are manually dispatched to the hovered control because
## standalone SubViewports (without SubViewportContainer) don't deliver
## mouse-button GUI events to Controls via push_input in editor mode.
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

## Tracks which panel source viewports have received notify_mouse_entered.
## Key = SubViewport instance ID, Value = true.
var _vp_mouse_entered: Dictionary = {}

## The GNUiBase widget currently being dragged (press-held).
## Set on left mouse-down, cleared on release. During drag, all mouse events
## are forwarded to this widget regardless of hover state.
var _panel_active_widget: GNUiBase = null

## The GNPanelSource containing the active widget's SubViewport.
## Stored alongside _panel_active_widget for coordinate remapping during drag.
var _panel_active_source: GNPanelSource = null


func _init() -> void:
	node_type = "window"
	node_description = "Display a texture in a standalone OS window (VJ output)."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Texture to display in the window")


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
	var tex_in: GNTextureData = _get_input_top(inputs, 0)

	_ensure_window()

	# Sync window visibility with the "open" parameter
	var should_open: bool = get_param_value("open")
	if _window != null and _window.visible != should_open:
		_window.visible = should_open
		if should_open:
			GNLogger.info("WindowOUT", "'%s' output window re-opened via parameter" % id)

	# Apply lightweight params every frame (title, texture)
	if _window != null:
		_window.title = get_param_value("title")

	# Apply heavyweight window params only when OUR params changed
	# (not when upstream input changes mark us cook-dirty)
	if _window_params_dirty:
		_apply_window_params()
		_window_params_dirty = false

	# Feed the texture — direct GPU reference, zero-copy.
	if tex_in != null and tex_in.texture != null:
		if _display_rect.texture != tex_in.texture:
			_display_rect.texture = tex_in.texture
			GNLogger.debug("WindowOUT", "'%s' texture assigned (zero-copy GPU)" % id)
		_display_rect.queue_redraw()
		_display_rect.visible = true
	else:
		_display_rect.visible = false

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
	_window.close_requested.connect(_on_window_close_requested)
	_window.window_input.connect(_on_window_input)

	_display_rect = TextureRect.new()
	_display_rect.name = "Display"
	_display_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_display_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Must not consume mouse events — they need to reach window_input signal.
	_display_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.add_child(_display_rect)
	_display_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	add_child(_window)
	_window_created = true
	GNLogger.info("WindowOUT", "'%s' output window created: '%s'" % [id, _window.title])


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
	if _window:
		_window.visible = false
		set_param_value("open", false)
		GNLogger.info("WindowOUT", "'%s' output window hidden by user" % id)


## Called for input events inside the output window.
## ESC reverts fullscreen/borderless to windowed; mouse events forwarded to panels.
func _on_window_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		var mode_idx: int = get_param_value("window_mode")
		if mode_idx != WindowMode.WINDOWED:
			set_param_value("window_mode", WindowMode.WINDOWED)
			_window_params_dirty = true
			GNLogger.info("WindowOUT", "'%s' ESC — switched to windowed mode" % id)

	if event is InputEventMouse:
		_forward_to_panels(event as InputEventMouse)


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


# ═══════════════════════════════════════════════════════════════════════════════
# Panel Input Forwarding
# ═══════════════════════════════════════════════════════════════════════════════
#
# push_input() delivers mouse MOTION (hover) to SubViewport controls, but
# mouse BUTTON events don't reach controls' gui_input in standalone SubViewports.
#
# Solution: push_input for hover tracking, then delegate all button and drag
# events to the owning GNUiBase via handle_panel_input(). Each widget type
# handles its own input — no widget-specific logic lives here.

## Forwards mouse events to interactive PanelTOP SubViewports.
## Normalizes window coords → texture coords → panel-local coords.
func _forward_to_panels(event: InputEventMouse) -> void:
	if _window == null or _display_rect == null:
		return

	var tex_data: GNTextureData = _get_upstream_tex_data()
	if tex_data == null or tex_data.panel_sources.is_empty():
		return

	# Map window mouse position → texture pixel coordinates.
	var window_size := Vector2(_window.size)
	var mouse_pos := event.position
	var norm := Vector2(mouse_pos.x / window_size.x, mouse_pos.y / window_size.y)
	var tex_pos := Vector2(norm.x * tex_data.resolution.x,
		norm.y * tex_data.resolution.y)

	# ── Active drag: forward all events to the captured widget ────────────
	if _panel_active_widget != null and is_instance_valid(_panel_active_widget):
		if _panel_active_source != null and _panel_active_source.viewport != null:
			var vp_pos: Vector2 = _panel_active_source.transform * tex_pos
			_push_hover(vp_pos, _panel_active_source)
			var vp_event := _make_viewport_event(event, vp_pos)
			_panel_active_widget.handle_panel_input(vp_event)
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
				_panel_active_widget = null
				_panel_active_source = null
		return

	# ── No drag: hit-test panel sources, first hit wins ───────────────────
	for ps in tex_data.panel_sources:
		var source: GNPanelSource = ps as GNPanelSource
		if source == null or source.viewport == null:
			continue

		var local: Variant = source.hit_test(tex_pos)
		if local == null:
			var vp_id := source.viewport.get_instance_id()
			if _vp_mouse_entered.has(vp_id):
				source.viewport.notify_mouse_exited()
				_vp_mouse_entered.erase(vp_id)
			continue

		var local_pos: Vector2 = local as Vector2

		# Ensure viewport knows mouse is inside.
		var vp_id := source.viewport.get_instance_id()
		if not _vp_mouse_entered.has(vp_id):
			source.viewport.notify_mouse_entered()
			_vp_mouse_entered[vp_id] = true

		# Push motion for hover tracking.
		_push_hover(local_pos, source)

		# ── Overlay takes priority when active ──────────────────────────
		if source.viewport.has_meta("gn_panel_overlay"):
			var panel = source.viewport.get_meta("gn_panel_overlay")
			if panel != null and panel.is_overlay_active():
				if event is InputEventMouseButton:
					var overlay_mb := event as InputEventMouseButton
					if overlay_mb.button_index == MOUSE_BUTTON_LEFT and not overlay_mb.pressed:
						var overlay_rect: Rect2 = panel.get_overlay_rect()
						if overlay_rect.has_point(local_pos):
							var vp_event := _make_viewport_event(event, local_pos)
							var owner: GNUiBase = panel.get_overlay_owner()
							if owner != null and is_instance_valid(owner):
								owner._handle_overlay_input(vp_event)
						else:
							panel.hide_overlay()
				return  # Overlay consumes all events when active

		# On left press, capture the widget under cursor for drag tracking.
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				var hovered := source.viewport.gui_get_hovered_control()
				var widget := _find_ui_owner(hovered)
				if widget != null:
					_panel_active_widget = widget
					_panel_active_source = source
					var vp_event := _make_viewport_event(event, local_pos)
					widget.handle_panel_input(vp_event)

		return  # First hit consumes the event


## Pushes a synthetic motion event to the SubViewport for hover tracking.
func _push_hover(vp_pos: Vector2, source: GNPanelSource) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = vp_pos
	motion.global_position = vp_pos
	motion.window_id = 0
	source.viewport.push_input(motion, true)


## Creates a viewport-local version of an input event at the given position.
func _make_viewport_event(event: InputEventMouse, vp_pos: Vector2) -> InputEventMouse:
	var offset := vp_pos - event.position
	var xform := Transform2D(0.0, offset)
	var remapped := event.xformed_by(xform) as InputEventMouse
	remapped.window_id = 0
	return remapped


## Finds the GNUiBase that owns a Control by checking metadata.
## Walks up the parent tree to handle internal children of complex widgets.
func _find_ui_owner(control: Control) -> GNUiBase:
	var current: Node = control
	while current != null:
		if current.has_meta("gn_ui_owner"):
			return current.get_meta("gn_ui_owner") as GNUiBase
		current = current.get_parent()
	return null


## Retrieves the upstream GNTextureData (for panel_sources access).
func _get_upstream_tex_data() -> GNTextureData:
	var engine: GNCookEngine = get_parent() as GNCookEngine \
		if get_parent() is GNCookEngine else null
	if engine == null or engine.network == null:
		return null

	var conns: Array = engine.network.get_input_connections(id)
	if conns.is_empty():
		return null

	var conn: GNConnection = conns[0]
	var upstream: GNNode = engine.network.nodes.get(conn.from_node, null)
	if upstream == null or not (upstream.cached_output is GNTextureData):
		return null

	return upstream.cached_output as GNTextureData
