class_name GNSDFData
extends GNData
## SDF scene-graph data carried between SDF operators.
## Contains an AST (tree of primitives, booleans, modifiers) that
## RaymarchSDF compiles into a single GLSL fragment shader.

## The SDF scene-graph node (Dictionary tree).
## Structure: { "op": String, "params": Dictionary, "children": Array,
##              "material": Dictionary (optional) }
var sdf_tree: Dictionary = {}

## Cached hash of the tree for change detection.
var tree_hash: int = 0


func get_family() -> int:
	return GNFamily.string_to_type("SDF")


func get_preview_text() -> String:
	if sdf_tree.is_empty():
		return "empty"
	var count := _count_nodes(sdf_tree)
	return "%s\n%d node%s" % [
		sdf_tree.get("op", "?"), count,
		"" if count == 1 else "s"]


func get_data_summary() -> String:
	if sdf_tree.is_empty():
		return ""
	return "%s (%d)" % [sdf_tree.get("op", "?"), _count_nodes(sdf_tree)]


static func _count_nodes(tree: Dictionary) -> int:
	if tree.is_empty():
		return 0
	var n := 1
	for child in tree.get("children", []):
		if child is Dictionary:
			n += _count_nodes(child)
	return n


func invalidate() -> void:
	super.invalidate()
	sdf_tree = {}
	tree_hash = 0


func duplicate_data() -> GNData:
	var copy := GNSDFData.new()
	copy.valid = valid
	copy.timestamp = timestamp
	copy.sdf_tree = sdf_tree.duplicate(true)
	copy.tree_hash = tree_hash
	return copy


## Computes a hash of the entire SDF tree for change detection.
static func compute_tree_hash(tree: Dictionary) -> int:
	if tree.is_empty():
		return 0
	return hash(var_to_str(tree))
