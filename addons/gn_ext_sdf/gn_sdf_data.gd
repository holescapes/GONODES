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


func get_family() -> GNFamily.Type:
	return GNFamily.Type.TOP


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
