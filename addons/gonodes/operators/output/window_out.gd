class_name WindowOUT
extends GNOutBase
## Displays a TOP texture and/or interactive UI panel in a standalone OS window.
## Supports multiple monitors, fullscreen/borderless/windowed modes,
## and positioning on any connected display.
##
## This is a terminal sink (no output ports) — display only.
## Multiple WindowOUT instances create multiple output windows.
## The Window node is a child of this GNNode in the scene tree —
## freed automatically when the node is removed.
##
## Two input ports:
##   Port 0 (TOP "in"):     Background texture — pixels only, no interaction.
##   Port 1 (UI  "panel"):  Interactive UI panel — Controls parented directly
##                           in the Window for native Godot input routing.
##
## Users compose TOPs upstream (CompositeTOP, LayoutTOP, etc.) and wire a
## single composed texture. For UI, users compose widgets with ContainerUI
## and wire one composed UI context. WindowOUT is a terminal sink, not a
## compositor.
##
## NOTE: Always use the 'monitor' parameter to assign the output display.
## Manually dragging the window to another screen may cause tearing because
## Windows DWM doesn't re-sync the GPU swapchain to the new display.
## When 'monitor' is changed, WindowOUT positions the Window directly on the
## target display before presenting, avoiding the DWM handoff issue.
##
## DPI: Godot's DisplayServer returns screen positions/sizes in logical
## (DPI-scaled) coordinates, so multi-monitor setups with mixed DPI scales
## work correctly — no manual DPI compensation is needed.

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

## Previous layout-affecting param values — used to skip repositioning
## when only cosmetic params (always_on_top, vsync, title) change.
var _prev_monitor: int = -1
var _prev_position: Vector2i = Vector2i(-2, -2)
var _prev_window_mode: int = -1
var _prev_resolution: Vector2i = Vector2i(-1, -1)

## Root container for UI widget layout — direct child of Window.
var _panel_ui_root: BoxContainer = null

## Controls currently adopted into the panel root.
var _managed_controls: Array[Control] = []

## Previous frame's managed controls for stable diff.
var _prev_managed: Array[Control] = []

## Overlay system for dropdowns, color pickers, etc.
var _overlay_layer: CanvasLayer = null
var _overlay_root: Control = null
var _overlay_bg: ColorRect = null
var _overlay_active: bool = false
var _overlay_owner: GNUiBase = null

## Track open WindowOUT instances for multi-window validation on mobile/web.
static var _open_instance_ids: Dictionary = {}

## Static registry: node_id → WindowOUT reference.  Input CHOPs look up windows here.
static var _input_registry: Dictionary = {}

## ID of the WindowOUT whose Window most recently received focus.
static var _last_focused_window: String = ""

# ── Per-window input state (updated from _on_window_input) ──────────────────
## Keyboard: keycode (Key) → true when pressed.
var _input_keys: Dictionary = {}
## Mouse position in local window coordinates.
var _input_mouse_pos: Vector2 = Vector2.ZERO
## Mouse button states: MOUSE_BUTTON_LEFT/RIGHT/MIDDLE → bool.
var _input_mouse_buttons: Dictionary = {}
## Accumulated scroll impulse (decays per frame like MouseInCHOP).
var _input_scroll: float = 0.0
## Touch points: finger index → {x, y, pressure, rel_x, rel_y, phase}.
var _input_touches: Dictionary = {}
## True while this window has OS keyboard/mouse focus.
var _input_has_focus: bool = false
## Window size (updated every cook so CHOPs can normalize).
var _input_window_size: Vector2 = Vector2(512, 512)

## Whether this WindowOUT runs in embedded mode (mobile/web).
## Embedded mode parents display into the main viewport instead of a Window.
var _embedded_mode: bool = false

## Main viewport container for embedded mode (Control in scene tree root).
var _embedded_root: Control = null


func _init() -> void:
	node_type = "window"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Texture to display in the window", "In")
	add_input("panel", GNFamily.Type.UI, false, "Interactive UI panel (native input routing)", "Panel")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("open", false, "Open", "Show/hide the output window"))
	add_parameter(GNParameter.create_string("title", "GONODES Output", "Title", "Window title bar text"))

	# Monitor selection — 0 = primary, 1 = secondary, etc.
	add_parameter(GNParameter.create_int("monitor", 0, 0, 8, "Monitor", "Target display index (0 = primary)"))

	add_parameter(GNParameter.create_enum("window_mode",
		PackedStringArray(["Windowed", "Fullscreen", "Borderless"]), 0, "", "Window display mode"))

	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "Resolution", "Window resolution in pixels"))

	# Position: (-1, -1) = auto-center on target monitor
	add_parameter(GNParameter.create_vector2i("position", Vector2i(-1, -1), "Position", "Window position (-1,-1 = auto center)"))

	add_parameter(GNParameter.create_bool("always_on_top", false, "Always On Top", "Keep window above all other windows"))
	add_parameter(GNParameter.create_bool("vsync", true, "Vsync", "Enable vertical sync"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)

	var should_open: bool = get_param_value("open")

	# Track open WindowOUT instances and warn on mobile/web if >1
	if should_open:
		_open_instance_ids[id] = true
		_input_registry[id] = self
	else:
		_open_instance_ids.erase(id)
		_input_registry.erase(id)

	var platform := GNGpuContext.get_current_platform()
	var _is_single_window := platform in ["android", "ios", "web"]
	if _is_single_window and _open_instance_ids.size() > 1 and should_open:
		node_warning = "Multiple WindowOUT nodes open — %s supports only one window. Only the first will display." % platform.capitalize()

	_embedded_mode = _is_single_window

	_ensure_window()

	if _embedded_mode:
		# Embedded mode — show/hide the fullscreen Control in the main viewport
		if _embedded_root != null:
			_embedded_root.visible = should_open
	else:
		# Desktop mode — Window node
		if _window != null and _window.visible != should_open:
			_window.visible = should_open
			if should_open:
				GNLogger.info("WindowOUT", "'%s' output window re-opened via parameter" % id)

	# Apply heavyweight window params only when OUR params changed
	# (not when upstream input changes mark us cook-dirty)
	if _window_params_dirty and not _embedded_mode:
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

	# Update cached window size for input CHOPs normalisation
	if _window != null and not _embedded_mode:
		_input_window_size = Vector2(_window.size)
	elif _embedded_root != null:
		var vp: Window = Engine.get_main_loop().root if Engine.get_main_loop() != null else null
		if vp != null:
			_input_window_size = Vector2(vp.get_visible_rect().size)

	# Decay per-frame impulse values (scroll, ended touches)
	_decay_input_state()

	# Adopt interactive UI panel from port 1
	_update_panel_layer(inputs)

	return null


## Lazily creates the display infrastructure.
## Desktop: Window + TextureRect + panel UI root (separate OS window).
## Mobile/Web: fullscreen Control in the main viewport (embedded mode).
func _ensure_window() -> void:
	if _window_created:
		return

	if _embedded_mode:
		_ensure_embedded()
		return

	_window = Window.new()
	_window.name = "GNOutput_%s" % id
	_window.title = "GONODES Output"
	var init_res: Vector2i = get_param_value("resolution")
	_window.size = init_res if init_res.x > 0 and init_res.y > 0 else Vector2i(512, 512)
	_window.min_size = Vector2i(160, 120)
	# GNNode sets process_mode = PROCESS_MODE_DISABLED which propagates to
	# children and blocks Godot's internal GUI dispatch on the Window.
	# Override to ALWAYS so the Window independently processes input.
	_window.process_mode = Node.PROCESS_MODE_ALWAYS
	_window.close_requested.connect(_on_window_close_requested)
	_window.window_input.connect(_on_window_input)
	_window.focus_entered.connect(_on_window_focus_entered)
	_window.focus_exited.connect(_on_window_focus_exited)

	# Background texture layer (z=0)
	_display_rect = TextureRect.new()
	_display_rect.name = "Display"
	_display_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_display_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.add_child(_display_rect)
	_display_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Root container for UI widget layout — direct child of Window.
	# Godot natively routes mouse, keyboard, and focus to Controls in a Window.
	_panel_ui_root = VBoxContainer.new()
	_panel_ui_root.name = "UIRoot"
	_panel_ui_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel_ui_root.visible = false  # Hidden until a UI is wired
	_window.add_child(_panel_ui_root)
	_panel_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Overlay layer (CanvasLayer 100) — sits above the panel for dropdowns, etc.
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "OverlayLayer"
	_overlay_layer.layer = 100
	_window.add_child(_overlay_layer)

	_overlay_root = Control.new()
	_overlay_root.name = "OverlayRoot"
	_overlay_root.visible = false
	_overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_layer.add_child(_overlay_root)

	_overlay_bg = ColorRect.new()
	_overlay_bg.name = "OverlayBG"
	_overlay_bg.color = Color(0, 0, 0, 0.3)
	_overlay_bg.visible = true
	_overlay_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_root.add_child(_overlay_bg)
	_overlay_bg.gui_input.connect(_on_overlay_bg_input)

	# Store reference on Window so widgets can find the overlay system
	_window.set_meta("gn_panel_overlay", self)

	add_child(_window)
	_window_created = true
	GNLogger.info("WindowOUT", "'%s' output window created: '%s'" % [id, _window.title])


## Creates the embedded-mode layout: fullscreen Control in the main viewport.
## Used on mobile/web where standalone Window nodes are not supported.
func _ensure_embedded() -> void:
	if _window_created:
		return

	_embedded_root = Control.new()
	_embedded_root.name = "GNEmbedded_%s" % id
	_embedded_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_embedded_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_embedded_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_embedded_root.visible = false  # Shown when "open" param is true

	# Background texture
	_display_rect = TextureRect.new()
	_display_rect.name = "Display"
	_display_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_display_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_embedded_root.add_child(_display_rect)
	_display_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# UI panel root
	_panel_ui_root = VBoxContainer.new()
	_panel_ui_root.name = "UIRoot"
	_panel_ui_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel_ui_root.visible = false
	_embedded_root.add_child(_panel_ui_root)
	_panel_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Store overlay reference for UI widgets
	_embedded_root.set_meta("gn_panel_overlay", self)

	# Parent into main scene tree root so it fills the viewport
	var tree := get_tree()
	if tree != null and tree.root != null:
		tree.root.add_child.call_deferred(_embedded_root)

	_window_created = true
	GNLogger.info("WindowOUT", "'%s' embedded display created (mobile/web mode)" % id)


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

	# Only reposition when layout-affecting params actually changed —
	# cosmetic changes (always_on_top, vsync, title) must not move the window.
	var layout_changed := (monitor_idx != _prev_monitor or pos != _prev_position
		or mode_idx != _prev_window_mode or res != _prev_resolution)
	_prev_monitor = monitor_idx
	_prev_position = pos
	_prev_window_mode = mode_idx
	_prev_resolution = res

	if layout_changed:
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
## Tracks per-window input state for KeyboardInCHOP / MouseInCHOP / MultiTouchInDAT.
## ESC reverts fullscreen/borderless to windowed.
func _on_window_input(event: InputEvent) -> void:
	# ── Keyboard ──────────────────────────────────────────────────────────
	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		_input_keys[ke.keycode] = ke.pressed
		# ESC: revert fullscreen/borderless to windowed
		if ke.pressed and ke.keycode == KEY_ESCAPE:
			var mode_idx: int = get_param_value("window_mode")
			if mode_idx != WindowMode.WINDOWED:
				set_param_value("window_mode", WindowMode.WINDOWED)
				_window_params_dirty = true
				GNLogger.info("WindowOUT", "'%s' ESC — switched to windowed mode" % id)

	# ── Mouse motion ──────────────────────────────────────────────────────
	elif event is InputEventMouseMotion:
		_input_mouse_pos = (event as InputEventMouseMotion).position

	# ── Mouse buttons / scroll ────────────────────────────────────────────
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_input_mouse_buttons[mb.button_index] = mb.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_input_scroll += 1.0
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_input_scroll -= 1.0

	# ── Touch ──────────────────────────────────────────────────────────────
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			_input_touches[st.index] = {
				"x": st.position.x, "y": st.position.y,
				"pressure": st.pressure if st.pressure > 0 else 1.0,
				"rel_x": 0.0, "rel_y": 0.0, "phase": "began"
			}
		else:
			if _input_touches.has(st.index):
				_input_touches[st.index]["phase"] = "ended"
			else:
				_input_touches[st.index] = {
					"x": st.position.x, "y": st.position.y,
					"pressure": 0.0,
					"rel_x": 0.0, "rel_y": 0.0, "phase": "ended"
				}
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		_input_touches[sd.index] = {
			"x": sd.position.x, "y": sd.position.y,
			"pressure": sd.pressure if sd.pressure > 0 else 1.0,
			"rel_x": sd.relative.x, "rel_y": sd.relative.y, "phase": "moved"
		}


## Called when the window gains OS focus.
func _on_window_focus_entered() -> void:
	_input_has_focus = true
	_last_focused_window = id


## Called when the window loses OS focus.
func _on_window_focus_exited() -> void:
	_input_has_focus = false


## Override: mark window params dirty when our own parameters change.
func _on_parameter_changed(p_name: String, _new_value: Variant) -> void:
	super._on_parameter_changed(p_name, _new_value)
	_window_params_dirty = true


## Decay per-frame impulse values (scroll).  Call once per cook.
func _decay_input_state() -> void:
	_input_scroll *= 0.9
	# Purge ended touches
	var ended: Array = []
	for idx in _input_touches:
		if _input_touches[idx].get("phase", "") == "ended":
			ended.append(idx)
	for idx in ended:
		_input_touches.erase(idx)


## Static lookup: returns the WindowOUT registered under [param node_id], or null.
static func get_window_by_id(node_id: String) -> WindowOUT:
	var ref = _input_registry.get(node_id, null)
	if ref != null and is_instance_valid(ref):
		return ref as WindowOUT
	return null


## Returns the IDs of all currently registered (open) WindowOUT nodes.
static func get_open_window_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for k in _input_registry:
		if is_instance_valid(_input_registry[k]):
			ids.append(k)
	return ids


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
# Interactive Panel Layer
# ═══════════════════════════════════════════════════════════════════════════════

## Adopts UI Control nodes from the panel input port into the Window's UIRoot.
## Uses stable scene population — controls that haven't changed stay in place
## so focus, hover, and text input state are preserved across cook frames.
func _update_panel_layer(inputs: Array[GNData]) -> void:
	if _panel_ui_root == null:
		return

	# Find UI data on port 1 — works for both GNUiBase nodes and
	# SubNetworkNode/GNCustomOperator that output GNUIData on their UI port.
	var ui_data: GNUIData = inputs[1] as GNUIData if inputs.size() > 1 else null

	if ui_data == null or ui_data.control_node == null:
		# No UI connected — hide panel layer and remove stale controls
		_panel_ui_root.visible = false
		_clear_managed_controls()
		return

	_panel_ui_root.visible = true
	_prev_managed = _managed_controls.duplicate()
	_managed_controls.clear()

	# Adopt the UI widget's Control node
	_adopt_control(ui_data.control_node)

	_remove_stale_controls()


## Adds a Control node to the panel UI root if not already there.
## Detects fan-out conflict: if the Control is already parented to another
## WindowOUT's panel root, sets a warning on this node.
func _adopt_control(ctrl: Control) -> void:
	if ctrl.get_parent() != _panel_ui_root:
		var prev_parent := ctrl.get_parent()
		# Detect if stolen from another WindowOUT's panel root
		if prev_parent != null:
			var other_window := prev_parent.get_parent()
			if other_window is Window and other_window != _window:
				# Walk up to find the WindowOUT that owns it
				var engine: GNCookEngine = get_parent() as GNCookEngine \
					if get_parent() is GNCookEngine else null
				if engine != null and engine.editor_mode and engine.network != null:
					for other_node in engine.network.nodes.values():
						if other_node is WindowOUT and other_node != self \
								and other_node._panel_ui_root == prev_parent:
							var msg := "UI shared with '%s' — Control can only have one parent" % other_node.id
							node_warning = msg
							other_node.node_warning = "UI shared with '%s' — Control can only have one parent" % id
							GNLogger.warn("WindowOUT", "'%s' and '%s' both connected to same UI node" % [id, other_node.id])
							break
			prev_parent.remove_child(ctrl)
		_panel_ui_root.add_child(ctrl)
	_managed_controls.append(ctrl)


## Removes controls that were NOT re-adopted this frame.
func _remove_stale_controls() -> void:
	for ctrl in _prev_managed:
		if ctrl != null and is_instance_valid(ctrl) and not _managed_controls.has(ctrl):
			if ctrl.get_parent() == _panel_ui_root:
				_panel_ui_root.remove_child(ctrl)
	_prev_managed.clear()


## Removes all managed controls from the panel viewport.
func _clear_managed_controls() -> void:
	for ctrl in _managed_controls:
		if ctrl != null and is_instance_valid(ctrl) and ctrl.get_parent() == _panel_ui_root:
			_panel_ui_root.remove_child(ctrl)
	_managed_controls.clear()
	_prev_managed.clear()


# ═══════════════════════════════════════════════════════════════════════════════
# Overlay System (for dropdowns, color pickers, menus)
# ═══════════════════════════════════════════════════════════════════════════════


## Shows an overlay control anchored below (or above) a widget's rect.
func show_overlay(owner: GNUiBase, content: Control, anchor_rect: Rect2) -> void:
	if _overlay_root == null:
		return
	hide_overlay()
	_overlay_owner = owner
	_overlay_root.add_child(content)
	content.position = Vector2(anchor_rect.position.x, anchor_rect.end.y)
	var vp_size := Vector2(_window.size)
	if content.position.y + content.size.y > vp_size.y:
		content.position.y = anchor_rect.position.y - content.size.y
	_overlay_root.visible = true
	_overlay_active = true


## Hides the overlay and notifies the owner widget.
func hide_overlay() -> void:
	if not _overlay_active or _overlay_root == null:
		return
	for child in _overlay_root.get_children():
		if child != _overlay_bg:
			_overlay_root.remove_child(child)
			child.queue_free()
	_overlay_root.visible = false
	_overlay_active = false
	if _overlay_owner != null and is_instance_valid(_overlay_owner):
		_overlay_owner._on_overlay_dismissed()
	_overlay_owner = null


## Called when the overlay background is clicked — dismiss the overlay.
func _on_overlay_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide_overlay()


## Returns whether the overlay is currently visible.
func is_overlay_active() -> bool:
	return _overlay_active


## Returns the widget that owns the current overlay.
func get_overlay_owner() -> GNUiBase:
	return _overlay_owner


## Returns the overlay content rect (for hit-testing).
func get_overlay_rect() -> Rect2:
	if _overlay_root != null and _overlay_root.visible:
		for child in _overlay_root.get_children():
			if child != _overlay_bg:
				return child.get_global_rect()
	return Rect2()
