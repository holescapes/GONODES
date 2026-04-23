# @input sdf First SDF shape
# @input sdf Second SDF shape
# @output sdf Combined SDF scene
# @param float smoothness 0.5 Blending radius (0 = sharp, higher = rounder)

## Smooth-unions two SDF inputs.
## Demonstrates reading SDF inputs and producing SDF output.
## Connect to RaymarchSDF → WindowOUT to visualize.

func cook():
	var a = inputs[0] if inputs.size() > 0 else null
	var b = inputs[1] if inputs.size() > 1 else null

	if a == null and b == null:
		return
	if a is GNSDFData and (b == null or not (b is GNSDFData)):
		op.sdf_tree = a.sdf_tree.duplicate(true)
		op.tree_hash = a.tree_hash
		return
	if b is GNSDFData and (a == null or not (a is GNSDFData)):
		op.sdf_tree = b.sdf_tree.duplicate(true)
		op.tree_hash = b.tree_hash
		return

	op.sdf_tree = {
		"op": "smooth_union",
		"params": {"smoothness": par("smoothness")},
		"children": [a.sdf_tree, b.sdf_tree],
	}
	op.tree_hash = hash(var_to_str(op.sdf_tree))
