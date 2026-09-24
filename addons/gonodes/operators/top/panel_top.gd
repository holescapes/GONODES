class_name PanelTOP
extends GNTopBase
## Renders UI widgets (ButtonUI, SliderUI, etc.) into a texture (pixels only).
##
## PanelTOP is a pure render-to-texture node — it snapshots UI controls into
## a GNTextureData for use in TOP chains (blur, composite, recording, etc.).
## The output is NOT interactive. For interactive UI, wire widgets directly
## to WindowOUT's panel port via ContainerUI.
##
## Architecture:
##   SliderUI ─┐
##   ButtonUI ──┼──→ PanelTOP → CompositeTOP → WindowOUT [TOP port] (pixels, no interaction)
##   LabelUI ──┘
##
##   SliderUI ─┐
##   ButtonUI ──┼──→ ContainerUI → WindowOUT [panel port] (interactive, native input)
##   LabelUI ──┘
##
## Widget state data (CHOP) comes from each UI widget's own "state" output
## port (added by GNUiBase), NOT from PanelTOP.

## Track which control nodes are currently in the viewport.
var _managed_controls: Array[Control] = []

## Previous frame's managed controls for stable diff.
var _prev_managed: Array[Control] = []

## Root container inside the viewport that holds widget controls.
var _ui_root: BoxContainer = null




func _init() -> void:
	node_type = "panel"
	time_dependent = true


func _init_ports() -> void:
	_enable_dynamic_inputs(GNFamily.Type.UI, "ui", "UI Input")
	add_output("out", GNFamily.Type.TOP, "Panel texture (pixels only, non-interactive)")


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


func _cook(inputs: Array[GNData]) -> GNData:
	_setup_panel_viewport()

	var res: Vector2i = get_param_value("resolution")
	var bg_color: Color = get_param_value("bg_color")
	var transparent: bool = get_param_value("transparent_bg")
	var layout_idx: int = get_param_value("layout")
	var padding: int = get_param_value("padding")
	var spacing: int = get_param_value("spacing")

	# Update viewport settings
	_ensure_viewport_size(res)
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
	_populate_ui_from_inputs(inputs)

	# Remove controls that were not re-adopted this frame
	_remove_stale_controls()

	# Update output texture data
	_cached_tex_data.resolution = res

	return _cached_tex_data


## Lazily creates the interactive SubViewport with a UI root container.
func _setup_panel_viewport() -> void:
	if _viewport != null:
		return

	var res: Vector2i = get_param_value("resolution")

	_viewport = GNViewportPool.acquire("VP_Panel_%s" % id, res, false, true)
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

	# Output texture data
	_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _viewport.get_texture()
	_cached_tex_data.viewport = _viewport
	_cached_tex_data.resolution = _viewport.size


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
## Uses GNUIData (data-type check) instead of GNUiBase (node-type check)
## so SubNetworkNode/GNCustomOperator UI outputs work correctly.
func _populate_ui_from_inputs(inputs: Array[GNData]) -> void:
	if _viewport == null or _ui_root == null:
		return

	for data in inputs:
		if data is GNUIData:
			var ctrl: Control = (data as GNUIData).control_node
			if ctrl != null:
				_adopt_control(ctrl)


## Adds a Control node to the UI root if not already there.
func _adopt_control(ctrl: Control) -> void:
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


## Removes all managed controls from the viewport (cleanup).
func _clear_managed_controls() -> void:
	for ctrl in _managed_controls:
		if ctrl != null and is_instance_valid(ctrl) and ctrl.get_parent() == _ui_root:
			_ui_root.remove_child(ctrl)
	_managed_controls.clear()


## Resets viewport tracking state.
func reset_viewport() -> void:
	_clear_managed_controls()
	_prev_managed.clear()
