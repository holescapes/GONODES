class_name GNUIData
extends GNData
## Output data type for UI operators.
## Wraps a Control node reference — the primary product of UI widget operators.
## Thin layer over GNData: exists for type safety and consistency with other families.
## RefCounted (inherits from GNData) — transient compute result.

## Reference to the Control node this UI widget manages (Button, HSlider, etc.).
## May be null before the first cook.
var control_node: Control = null

## Human-readable label for UI preview (e.g., "Button", "HSlider").
var control_label: String = ""

## Snapshot of the source widget's state dict.  Carried on the data so
## downstream operators (ContainerUI, NullUI) can aggregate CHOP state
## without casting to GNUiBase (which fails for SubNetworkNode outputs).
var widget_state: Dictionary = {}

## ID of the source node that produced this data — used by ContainerUI
## to prefix CHOP channel names for disambiguation.
var source_id: String = ""


func get_family() -> int:
	return GNFamily.Type.UI


func get_preview_text() -> String:
	if control_node != null:
		return control_label if not control_label.is_empty() else control_node.get_class()
	return "no widget"


func get_data_summary() -> String:
	if control_node != null:
		return control_label if not control_label.is_empty() else control_node.get_class()
	return ""


func invalidate() -> void:
	super.invalidate()
	control_node = null
	control_label = ""
	widget_state = {}
	source_id = ""


func duplicate_data() -> GNData:
	var copy := GNUIData.new()
	copy.valid = valid
	copy.timestamp = timestamp
	copy.control_label = control_label
	# Control nodes are not duplicated — they're shared references managed by the operator.
	copy.control_node = control_node
	copy.widget_state = widget_state.duplicate()
	copy.source_id = source_id
	return copy
