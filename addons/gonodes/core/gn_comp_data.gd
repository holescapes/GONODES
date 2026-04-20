class_name GNCompData
extends GNData
## Output data type for COMP operators.
## Wraps a 3D scene node reference — the primary product of component operators.
## Thin layer over GNData: exists for type safety and consistency with other families.
## RefCounted (inherits from GNData) — transient compute result.

## Reference to the scene node this COMP manages (MeshInstance3D, Camera3D, etc.).
## May be null for COMPs that only compose children without owning a node.
var scene_node: Node3D = null

## Optional Environment resource (set by EnvironmentCOMP).
## When non-null, RenderTOP uses this instead of its built-in fallback.
var environment: Environment = null

## Human-readable label for UI preview (e.g., "MeshInstance3D", "Camera3D").
var scene_label: String = ""


func get_family() -> int:
	return GNFamily.Type.COMP


func get_preview_text() -> String:
	if scene_node != null:
		var vis: String = "visible" if scene_node.visible else "hidden"
		return "%s\n%s" % [scene_label if not scene_label.is_empty() else scene_node.get_class(), vis]
	return "no node"


func get_data_summary() -> String:
	if scene_node != null:
		return scene_label if not scene_label.is_empty() else scene_node.get_class()
	return ""


func invalidate() -> void:
	super.invalidate()
	scene_node = null
	environment = null
	scene_label = ""


func duplicate_data() -> GNData:
	var copy := GNCompData.new()
	copy.valid = valid
	copy.timestamp = timestamp
	copy.scene_label = scene_label
	copy.environment = environment
	# Scene nodes are not duplicated — they're shared references managed by the operator.
	copy.scene_node = scene_node
	return copy
