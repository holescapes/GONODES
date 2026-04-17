class_name GNUiBase
extends GNNode
## Base class for all UI family operators — 2D interface widgets.
##
## Manages a Control node for 2D UI composition. Two consumption paths:
##   • Interactive: wire to WindowOUT panel port (via ContainerUI for layout).
##     WindowOUT adopts controls directly into its Window's UIRoot container
##     — native Godot input routing (mouse, keyboard, focus) works automatically.
##   • Render-to-texture: wire to PanelTOP for pixel output into TOP chains.
##     The resulting texture is non-interactive (useful for FX, recording).
##
## Provides:
##   • family = GNFamily.Type.UI set automatically
##   • Default output port "out" (UI) + "state" (CHOP) on every widget
##   • _control_node management with automatic cleanup on PREDELETE
##   • Automatic CHOP output from widget_state after each cook
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

## Widget state values exposed as CHOP channels on the "state" output port.
## Keys are channel names (e.g., "value", "press", "state"), values are floats.
## Subclasses update this in _cook() after reading their Control's state.
## The base class automatically converts widget_state to GNChannelData after cook.
var widget_state: Dictionary = {}

## Cached CHOP output built from widget_state after each cook.
var _cached_state_chop: GNChannelData = null

## Cached UI data wrapping _control_node, built automatically after each cook.
var _cached_ui_data: GNUIData = null

## Optional ordering hint for layout inside PanelTOP's container.
## Lower values sort earlier. Set via parameter or left at default (0).
var sort_order: int = 0

## Registered signal connections for automatic cleanup.
## Each entry is {"signal": Signal, "callback": Callable}.
## Populated via _register_signal(), cleaned up automatically in destroy_control_node().
var _registered_signals: Array = []


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	family = GNFamily.Type.UI


## Ensures family is set even when subclass _init() doesn't call super().
## Appends a CHOP "state" output port AFTER subclass ports so every UI widget
## exposes its widget_state as CHOP channels.
func initialize(p_id: String) -> void:
	family = GNFamily.Type.UI
	super.initialize(p_id)
	# Append state CHOP port after whatever ports the subclass defined.
	# This makes it always the last output port on every UI widget.
	add_output("state", GNFamily.Type.CHOP, "Widget state channels")


## UI family data check for Switch/Null routing.
func _is_family_data(data: GNData) -> bool:
	return data is GNUIData


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

## Widget interaction is serialized state — notify the save system.
func mark_dirty() -> void:
	super.mark_dirty()
	var eng: GNCookEngine = get_parent() as GNCookEngine if get_parent() is GNCookEngine else null
	if eng != null and eng.network != null:
		eng.network.notify_state_changed(false)  # not undoable


## Returns the managed Control node.  Subclasses typically provide a typed
## accessor (get_button, get_slider, etc.) that casts this.
func get_control_node() -> Control:
	return _control_node


## Routes output data by port.  The last port is always the CHOP state output.
## Port 0 returns GNUIData wrapping this widget's control node.
func get_output_data(port_index: int) -> GNData:
	if port_index == output_ports.size() - 1:
		return _cached_state_chop
	return _cached_ui_data


## Wraps _cook(): after the subclass cook runs, builds GNUIData from the
## control node and converts widget_state → CHOP.
func execute_cook(inputs: Array[GNData], frame: int) -> GNData:
	var result := super.execute_cook(inputs, frame)
	_build_ui_data()
	_build_state_chop()
	return _cached_ui_data


## Wraps _control_node into a GNUIData for typed output on the UI port.
func _build_ui_data() -> void:
	if _cached_ui_data == null:
		_cached_ui_data = GNUIData.new()
	_cached_ui_data.control_node = _control_node
	_cached_ui_data.control_label = _control_node.get_class() if _control_node != null else ""
	_cached_ui_data.valid = _control_node != null
	_cached_ui_data.timestamp = Engine.get_process_frames()
	_cached_ui_data.widget_state = widget_state.duplicate() if widget_state != null else {}
	_cached_ui_data.source_id = id


## Converts this widget's widget_state dictionary into GNChannelData.
## Each key becomes a plain channel name with a single float sample.
## This matches standard CHOP naming: chop("slider1", "value") — no prefix.
## ContainerUI overrides this to add child-ID prefixes for disambiguation.
func _build_state_chop() -> void:
	if _cached_state_chop == null:
		_cached_state_chop = GNChannelData.new()
	_cached_state_chop.channels.clear()
	_cached_state_chop.length = 1
	_cached_state_chop.sample_rate = 60.0
	for key in widget_state:
		_cached_state_chop.set_single_value(key, float(widget_state[key]))


## Destroys the control node and resets this widget to pre-first-cook state.
## Automatically disconnects all signals registered via _register_signal().
func destroy_control_node() -> void:
	_cleanup_registered_signals()
	if _control_node != null:
		if _control_node.get_parent() != null:
			_control_node.get_parent().remove_child(_control_node)
		_control_node.queue_free()
		_control_node = null
	widget_state.clear()


# ═══════════════════════════════════════════════════════════════════════════════
# Serialization
# ═══════════════════════════════════════════════════════════════════════════════

func to_dict() -> Dictionary:
	var d := super.to_dict()
	if not widget_state.is_empty():
		d["widget_state"] = widget_state.duplicate()
	return d


func from_dict(d: Dictionary) -> void:
	super.from_dict(d)
	if d.has("widget_state"):
		widget_state = d["widget_state"].duplicate()


# ═══════════════════════════════════════════════════════════════════════════════
# Signal Management
# ═══════════════════════════════════════════════════════════════════════════════


## Connects a signal and records it for automatic cleanup on destroy.
## Use this instead of manual .connect() in _ensure_*() methods.
func _register_signal(sig: Signal, callback: Callable) -> void:
	sig.connect(callback)
	_registered_signals.append({"signal": sig, "callback": callback})


## Disconnects all signals registered via _register_signal().
## Called automatically by destroy_control_node().
func _cleanup_registered_signals() -> void:
	for entry in _registered_signals:
		var sig: Signal = entry["signal"]
		var cb: Callable = entry["callback"]
		if sig.is_connected(cb):
			sig.disconnect(cb)
	_registered_signals.clear()


# ═══════════════════════════════════════════════════════════════════════════════
# Preview
# ═══════════════════════════════════════════════════════════════════════════════

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


func render_for_preview(host) -> void:
	if _control_node != null:
		var state_str := ""
		for key in widget_state:
			state_str += "%s: %s\n" % [key, str(widget_state[key])]
		host.set_text("%s\n%s" % [_control_node.get_class(), state_str.strip_edges()])
	else:
		host.set_text("no widget")


## Called by WindowOUT to deliver input events to overlay content.
## event position is in SubViewport coordinates.
## Return true if the event was handled.
func _handle_overlay_input(event: InputEvent) -> bool:
	return false


# ═══════════════════════════════════════════════════════════════════════════════
# Overlay System
# ═══════════════════════════════════════════════════════════════════════════════
#
# Overlay-based popups for dropdowns, color pickers, and menus.
# The overlay host (WindowOUT) sets "gn_panel_overlay" meta on its Window.
# Widgets call _request_panel_overlay to show popup controls above other widgets.


## Requests the panel host to show an overlay control anchored to this widget.
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
