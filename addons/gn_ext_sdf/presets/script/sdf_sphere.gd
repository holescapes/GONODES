# @output sdf SDF scene
# @param float radius 1.0 Sphere radius
# @param float px 0.0 Sphere position X
# @param float py 0.0 Sphere position Y
# @param float pz 0.0 Sphere position Z

## Generates a simple SDF sphere primitive.
## Connect to RaymarchSDF → WindowOUT to see the result.

func cook():
	op.sdf_tree = {
		"op": "sphere",
		"params": {
			"radius": par("radius"),
			"position": Vector3(par("px"), par("py"), par("pz")),
		},
		"children": [],
	}
	op.tree_hash = hash(var_to_str(op.sdf_tree))
