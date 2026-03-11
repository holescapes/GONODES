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
var _control_node: Control = null

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
