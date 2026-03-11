class_name PanelTOP
extends GNTopBase
## Renders UI widgets (ButtonUI, SliderUI, etc.) into an interactive SubViewport.
##
## Parallel to RenderTOP for 3D COMPs — PanelTOP accepts UI-family inputs,
## reparents their Control nodes into a 2D SubViewport container, and outputs:
##   • Port 0 (TOP): GNTextureData with a PanelSource entry for input forwarding
##   • Port 1 (CHOP): Aggregated widget state channels from all connected UIs
##
## The SubViewport is configured with gui_disable_input = false so that
## forwarded mouse/keyboard events from WindowOUT are processed by the
## Godot UI system (focus, hover, click) as normal.
##
## Architecture:
##   SliderUI ─┐
##   ButtonUI ──┼──→ PanelTOP → CompositeTOP → WindowOUT
##   LabelUI ──┘         ↓
##                  (CHOP: widget states)

## Track which control nodes are currently in the viewport.
var _managed_controls: Array[Control] = []

## Previous frame's managed controls for stable diff.
var _prev_managed: Array[Control] = []

## Root container inside the viewport that holds widget controls.
var _ui_root: BoxContainer = null

## Cached CHOP output (port 1) for aggregated widget states.
var _cached_chop_data: GNChannelData = null

## ── Overlay System ──────────────────────────────────────────────────────────
## CanvasLayer-based overlay for dropdowns, color pickers, and menus.
## Widgets request overlays via GNUiBase._request_panel_overlay().
var _overlay_layer: CanvasLayer = null
var _overlay_root: Control = null
var _overlay_bg: ColorRect = null
var _overlay_active: bool = false
var _overlay_owner: GNUiBase = null


func _init() -> void:
	node_type = "panel"
	time_dependent = true
	node_description = "Render UI widgets to an interactive texture. Connect ButtonUI, SliderUI, etc."


func _init_ports() -> void:
	_enable_dynamic_inputs(GNFamily.Type.UI, "ui", "UI Input")
	add_output("out", GNFamily.Type.TOP, "Panel texture with interactive forwarding")
	add_output("state", GNFamily.Type.CHOP, "Widget state channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "Resolution", "Panel render resolution"))
	add_parameter(GNParameter.create_color("bg_color", Color(0.15, 0.15, 0.18, 1.0), "Background", "Panel background color"))
	add_parameter(GNParameter.create_bool("transparent_bg", false, "Transparent", "Use transparent background"))
	add_parameter(GNParameter.create_enum("layout",
		PackedStringArray(["Vertical", "Horizontal", "Free"]), 0,
		"Layout", "Widget layout mode"))
	add_parameter(GNParameter.create_int("padding", 8, 0, 64, "Padding", "Container padding in pixels"))
	add_parameter(GNParameter.create_int("spacing", 4, 0, 32, "Spacing", "Spacing between widgets"))


## Override execute_cook: PanelTOP keeps UPDATE_ALWAYS so interactive widgets
## can repaint (hover states, animations) between cook frames.
func execute_cook(inputs: Array[GNData], frame: int) -> GNData:
	var result := super.execute_cook(inputs, frame)
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return result


## Override cached_output with multi-port output support.
## Port 0 = TOP (texture), Port 1 = CHOP (widget states).
func get_output_for_port(port: int) -> GNData:
	if port == 1:
		return _cached_chop_data
	return cached_output


func _cook(inputs: Array[GNData]) -> GNData:
	_setup_panel_viewport()

	var res: Vector2i = get_param_value("resolution")
	var bg_color: Color = get_param_value("bg_color")
	var transparent: bool = get_param_value("transparent_bg")
	var layout_idx: int = get_param_value("layout")
	var padding: int = get_param_value("padding")
	var spacing: int = get_param_value("spacing")

	# Update viewport settings
	if _viewport.size != res:
		_viewport.size = res
	_viewport.transparent_bg = transparent

	# Update container layout
	_update_layout(layout_idx, padding, spacing)

	# Apply background color via a ColorRect behind the UI root
	_update_bg_color(bg_color)

	# Stable scene population — controls that haven't changed stay in the
	# viewport so interactive state (focus, hover) is preserved between frames.
	_prev_managed = _managed_controls.duplicate()
	_managed_controls.clear()

	# Scan UI inputs and adopt their Control nodes
	_populate_ui_from_network()

	# Remove controls that were not re-adopted this frame
	_remove_stale_controls()

	# Aggregate widget states into CHOP output
	_build_chop_output()

	# Update output texture data
	_cached_tex_data.resolution = res

	# Create PanelSource at identity — downstream spatial TOPs will accumulate
	# their inverse transforms onto this.
	_cached_tex_data.panel_sources.clear()
	var source := GNPanelSource.new()
	source.viewport = _viewport
	source.transform = Transform2D.IDENTITY
	source.resolution = res
	source.source_id = id
	_cached_tex_data.panel_sources.append(source)

	return _cached_tex_data


## Lazily creates the interactive SubViewport with a UI root container.
func _setup_panel_viewport() -> void:
	if _viewport != null:
		return

	var res: Vector2i = get_param_value("resolution")

	_viewport = SubViewport.new()
	_viewport.name = "VP_Panel_%s" % id
	_viewport.size = res
	_viewport.transparent_bg = false
	_viewport.disable_3d = true
	# Interactive: allow mouse/keyboard events to reach UI Controls
	_viewport.gui_disable_input = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	# Background ColorRect
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.15, 0.15, 0.18, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(bg)

	# Root container for layout
	_ui_root = VBoxContainer.new()
	_ui_root.name = "UIRoot"
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(_ui_root)

	# Overlay layer for dropdowns, color pickers, etc. (above all widgets)
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "OverlayLayer"
	_overlay_layer.layer = 100
	_viewport.add_child(_overlay_layer)

	_overlay_root = Control.new()
	_overlay_root.name = "OverlayRoot"
	_overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_root.visible = false
	_overlay_layer.add_child(_overlay_root)

	_overlay_bg = ColorRect.new()
	_overlay_bg.name = "OverlayBG"
	_overlay_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_bg.color = Color(0.0, 0.0, 0.0, 0.4)
	_overlay_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_root.add_child(_overlay_bg)

	# Store reference on viewport so widgets can find the overlay system
	_viewport.set_meta("gn_panel_overlay", self)

	# Output texture data
	_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _viewport.get_texture()
	_cached_tex_data.viewport = _viewport
	_cached_tex_data.resolution = _viewport.size

	# CHOP data for widget states
	_cached_chop_data = GNChannelData.new()


## Updates the layout container type based on the layout parameter.
func _update_layout(layout_idx: int, padding: int, spacing: int) -> void:
	if _ui_root == null:
		return

	# Check if we need to swap container type
	var needs_vbox: bool = (layout_idx == 0)
	var needs_hbox: bool = (layout_idx == 1)
	var is_vbox: bool = _ui_root is VBoxContainer
	var is_hbox: bool = _ui_root is HBoxContainer

	if (needs_vbox and not is_vbox) or (needs_hbox and not is_hbox) or (layout_idx == 2 and (is_vbox or is_hbox)):
		# Reparent children to a new container
		var children: Array[Control] = []
		for child in _ui_root.get_children():
			children.append(child as Control)
			_ui_root.remove_child(child)

		_ui_root.queue_free()

		match layout_idx:
			0:  # Vertical
				_ui_root = VBoxContainer.new()
			1:  # Horizontal
				_ui_root = HBoxContainer.new()
			2:  # Free (no auto-layout)
				_ui_root = Control.new()

		_ui_root.name = "UIRoot"
		_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_viewport.add_child(_ui_root)

		for child in children:
			_ui_root.add_child(child)

	# Apply padding and spacing to BoxContainers
	if _ui_root is BoxContainer:
		var box: BoxContainer = _ui_root as BoxContainer
		box.add_theme_constant_override("separation", spacing)

	# Padding via margins
	_ui_root.offset_left = padding
	_ui_root.offset_top = padding
	_ui_root.offset_right = -padding
	_ui_root.offset_bottom = -padding


## Updates the background color.
func _update_bg_color(color: Color) -> void:
	if _viewport == null:
		return
	var bg: ColorRect = _viewport.get_node_or_null("Background") as ColorRect
	if bg != null:
		bg.color = color


## Populates the viewport with Control nodes from connected UI widgets.
func _populate_ui_from_network() -> void:
	if _viewport == null or _ui_root == null:
		return

	var engine: GNCookEngine = get_parent() as GNCookEngine if get_parent() is GNCookEngine else null
	if engine == null or engine.network == null:
		return

	var network: GNNetwork = engine.network

	# Sort connections by input port for deterministic widget ordering
	var conns: Array = network.get_input_connections(id).duplicate()
	conns.sort_custom(func(a: GNConnection, b: GNConnection) -> bool:
		return a.to_port < b.to_port)

	for conn in conns:
		var upstream_node: GNNode = network.nodes.get(conn.from_node, null)
		if upstream_node == null:
			continue

		if upstream_node is GNUiBase:
			var ui_node: GNUiBase = upstream_node as GNUiBase
			var ctrl: Control = ui_node.get_control_node()
			if ctrl != null:
				_adopt_control(ctrl, ui_node.sort_order)


## Adds a Control node to the UI root if not already there.
func _adopt_control(ctrl: Control, _sort_order: int = 0) -> void:
	if ctrl.get_parent() != _ui_root:
		if ctrl.get_parent() != null:
			ctrl.get_parent().remove_child(ctrl)
		_ui_root.add_child(ctrl)
	_managed_controls.append(ctrl)


## Removes controls that were NOT re-adopted this frame.
func _remove_stale_controls() -> void:
	for ctrl in _prev_managed:
		if ctrl != null and is_instance_valid(ctrl) and not _managed_controls.has(ctrl):
			if ctrl.get_parent() == _ui_root:
				_ui_root.remove_child(ctrl)
	_prev_managed.clear()


## Aggregates widget_state dictionaries from all connected UI nodes into CHOP channels.
func _build_chop_output() -> void:
	if _cached_chop_data == null:
		_cached_chop_data = GNChannelData.new()
	_cached_chop_data.channels.clear()
	_cached_chop_data.length = 1
	_cached_chop_data.sample_rate = 60.0

	var engine: GNCookEngine = get_parent() as GNCookEngine if get_parent() is GNCookEngine else null
	if engine == null or engine.network == null:
		return

	var network: GNNetwork = engine.network
	for conn in network.get_input_connections(id):
		var upstream: GNNode = network.nodes.get(conn.from_node, null)
		if upstream is GNUiBase:
			var ui: GNUiBase = upstream as GNUiBase
			for key in ui.widget_state:
				# Prefix channel name with widget id for uniqueness
				var ch_name: String = "%s:%s" % [ui.id, key]
				_cached_chop_data.set_single_value(ch_name, float(ui.widget_state[key]))


## Removes all managed controls from the viewport (cleanup).
func _clear_managed_controls() -> void:
	for ctrl in _managed_controls:
		if ctrl != null and is_instance_valid(ctrl) and ctrl.get_parent() == _ui_root:
			_ui_root.remove_child(ctrl)
	_managed_controls.clear()


## Resets viewport tracking state.
func reset_viewport() -> void:
	hide_overlay()
	_clear_managed_controls()
	_prev_managed.clear()


# ═══════════════════════════════════════════════════════════════════════════════
# Overlay System
# ═══════════════════════════════════════════════════════════════════════════════


## Shows an overlay control anchored below (or above) a widget's rect.
func show_overlay(owner: GNUiBase, content: Control, anchor_rect: Rect2) -> void:
	hide_overlay()
	_overlay_owner = owner
	_overlay_root.add_child(content)
	# Position below the anchor
	content.position = Vector2(anchor_rect.position.x, anchor_rect.end.y)
	# Clamp to viewport bounds
	var vp_size := Vector2(_viewport.size)
	if content.position.y + content.size.y > vp_size.y:
		content.position.y = anchor_rect.position.y - content.size.y
	if content.position.x + content.size.x > vp_size.x:
		content.position.x = vp_size.x - content.size.x
	content.position.x = maxf(content.position.x, 0.0)
	content.position.y = maxf(content.position.y, 0.0)
	_overlay_root.visible = true
	_overlay_active = true


## Hides the current overlay and notifies the owner.
func hide_overlay() -> void:
	if not _overlay_active:
		return
	for i in range(_overlay_root.get_child_count() - 1, 0, -1):
		var child := _overlay_root.get_child(i)
		_overlay_root.remove_child(child)
		child.queue_free()
	_overlay_root.visible = false
	var prev_owner := _overlay_owner
	_overlay_owner = null
	_overlay_active = false
	if prev_owner != null and is_instance_valid(prev_owner):
		prev_owner._on_overlay_dismissed()


## Returns true when an overlay is visible.
func is_overlay_active() -> bool:
	return _overlay_active


## Returns the widget that owns the active overlay.
func get_overlay_owner() -> GNUiBase:
	return _overlay_owner


## Returns the viewport-space rect of the overlay content (for hit testing).
func get_overlay_rect() -> Rect2:
	if not _overlay_active or _overlay_root.get_child_count() <= 1:
		return Rect2()
	return _overlay_root.get_child(1).get_global_rect()
