class_name GNUiBase
extends GNNode
## Base class for all UI family operators — 2D interface widgets.
##
## Parallel to GNCompBase (which manages Node3D for 3D scenes), GNUiBase
## manages a Control node for 2D UI composition. PanelTOP reparents these
## Controls into its interactive SubViewport, just as RenderTOP reparents
## COMP scene nodes into its 3D SubViewport.
##
## Provides:
##   • family = GNFamily.Type.UI set automatically
##   • Default output port "out" of type UI
##   • _control_node management with automatic cleanup on PREDELETE
##   • Widget state dictionary for CHOP output via PanelTOP
##   • Inline label preview

# ─── Shared UI Infrastructure ──────────────────────────────────────────────────

## The Control node managed by this UI widget (Button, HSlider, Label, etc.).
## Subclasses create and assign their concrete Control type to this variable.
## Automatically freed on node removal via _notification(PREDELETE).
## The setter tags the control with a back-reference so WindowOUT can find
## the owning GNUiBase from any hovered Control.
var _control_node: Control = null:
	set(value):
		_control_node = value
		if value != null:
			value.set_meta("gn_ui_owner", self)

## Widget state values exposed as CHOP channels by PanelTOP.
## Keys are channel names (e.g., "value", "press", "state"), values are floats.
## Subclasses update this in _cook() after reading their Control's state.
var widget_state: Dictionary = {}

## Optional ordering hint for layout inside PanelTOP's container.
## Lower values sort earlier. Set via parameter or left at default (0).
var sort_order: int = 0


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	family = GNFamily.Type.UI


## Ensures family is set even when subclass _init() doesn't call super().
func initialize(p_id: String) -> void:
	family = GNFamily.Type.UI
	super.initialize(p_id)


## Default output port.  Override in subclass to add inputs or extra outputs.
func _init_ports() -> void:
	add_output("out", GNFamily.Type.UI, "Widget output")


## Automatic cleanup: if this node's control was reparented into a PanelTOP's
## SubViewport, we must remove and free it manually because it's not a direct
## child of this GNNode.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _control_node != null and _control_node.get_parent() != null:
			_control_node.get_parent().remove_child(_control_node)
			_control_node.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# Control Node Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Returns the managed Control node.  Subclasses typically provide a typed
## accessor (get_button, get_slider, etc.) that casts this.
func get_control_node() -> Control:
	return _control_node


## Destroys the control node and resets this widget to pre-first-cook state.
func destroy_control_node() -> void:
	if _control_node != null:
		if _control_node.get_parent() != null:
			_control_node.get_parent().remove_child(_control_node)
		_control_node.queue_free()
		_control_node = null
	widget_state.clear()


# ═══════════════════════════════════════════════════════════════════════════════
# Preview
# ═══════════════════════════════════════════════════════════════════════════════

## Creates a Label preview showing widget type and state.
func create_preview_control() -> Control:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.text = ""
	return label


## Updates the widget preview with control type and key state values.
func update_preview_control(control: Control) -> void:
	if control is Label:
		var label: Label = control as Label
		if _control_node != null:
			var state_str := ""
			for key in widget_state:
				state_str += "%s: %s\n" % [key, str(widget_state[key])]
			label.text = "%s\n%s" % [_control_node.get_class(), state_str.strip_edges()]
		else:
			label.text = "no widget"


# ═══════════════════════════════════════════════════════════════════════════════
# Panel Input Dispatch
# ═══════════════════════════════════════════════════════════════════════════════
#
# Standalone SubViewports (no SubViewportContainer parent) don't deliver
# mouse-button or drag events to Controls via push_input(). WindowOUT
# works around this by finding the GNUiBase that owns the hovered Control
# and calling handle_panel_input(). Each widget type handles its own input.

## Called by WindowOUT to deliver mouse events that push_input() cannot.
## Receives events in SubViewport coordinates, remaps to control-local,
## and calls _dispatch_panel_input().
func handle_panel_input(event: InputEvent) -> void:
	if _control_node == null:
		return
	var local_event := event
	if event is InputEventMouse:
		var ctrl_pos := _control_node.get_global_rect().position
		local_event = event.xformed_by(Transform2D(0.0, -ctrl_pos))
	_dispatch_panel_input(local_event)


## Override in subclasses for widget-specific input handling.
## Default: handles BaseButton pressed/toggled on release;
## emits gui_input signal for all other controls (KnobUI, XYPadUI, etc.).
func _dispatch_panel_input(event: InputEvent) -> void:
	if _control_node is BaseButton:
		_handle_base_button_input(event)
	else:
		_control_node.emit_signal("gui_input", event)


## Handles BaseButton press/toggle on mouse-left release.
func _handle_base_button_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or mb.pressed:
		return
	var btn := _control_node as BaseButton
	if btn.toggle_mode:
		btn.set_pressed_no_signal(not btn.button_pressed)
	btn.emit_signal("pressed")
	if btn.toggle_mode:
		btn.emit_signal("toggled", btn.button_pressed)


# ═══════════════════════════════════════════════════════════════════════════════
# Overlay System
# ═══════════════════════════════════════════════════════════════════════════════


## Requests the panel to show an overlay control anchored to this widget.
## content: The Control to display (e.g., ItemList, color swatch grid).
## anchor_rect: Viewport-space rect to anchor to. Defaults to _control_node rect.
func _request_panel_overlay(content: Control, anchor_rect: Rect2 = Rect2()) -> bool:
	if _control_node == null:
		return false
	var vp := _control_node.get_viewport()
	if vp == null or not vp.has_meta("gn_panel_overlay"):
		return false
	var panel = vp.get_meta("gn_panel_overlay")
	if anchor_rect == Rect2():
		anchor_rect = _control_node.get_global_rect()
	panel.show_overlay(self, content, anchor_rect)
	return true


## Dismisses the overlay if this widget owns it.
func _dismiss_panel_overlay() -> void:
	if _control_node == null:
		return
	var vp := _control_node.get_viewport()
	if vp == null or not vp.has_meta("gn_panel_overlay"):
		return
	var panel = vp.get_meta("gn_panel_overlay")
	if panel.get_overlay_owner() == self:
		panel.hide_overlay()


## Called when the overlay is dismissed (click-outside or explicit).
## Override in subclasses to clean up overlay references.
func _on_overlay_dismissed() -> void:
	pass


## Called by WindowOUT to deliver input events to overlay content.
## event position is in SubViewport coordinates.
## Return true if the event was handled.
func _handle_overlay_input(event: InputEvent) -> bool:
	return false
