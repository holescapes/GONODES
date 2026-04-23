# @output sdf SDF scene
# @param float twist_amount 2.0 Twist amount around Y axis
# @param float sphere_radius 0.8 Sphere radius
# @param float box_size 0.6 Box half-size
# @param float smoothness 0.3 Smooth union blending

## Builds a procedural SDF scene entirely in GDScript:
## smooth union of a twisted sphere and a box, with materials.
## Connect to RaymarchSDF → WindowOUT to visualize.

func cook():
	# Create a sphere and twist it
	var sphere := {
		"op": "sphere",
		"params": {"radius": par("sphere_radius"), "position": Vector3.ZERO},
		"children": [],
		"material": {"albedo": Color(0.9, 0.2, 0.1), "roughness": 0.3,
					  "metallic": 0.0, "emission": 0.0},
	}
	var twisted := {
		"op": "twist",
		"params": {"amount": par("twist_amount")},
		"children": [sphere],
	}

	# Create a box
	var box := {
		"op": "box",
		"params": {"size": Vector3.ONE * par("box_size"),
				   "position": Vector3(1.5, 0.0, 0.0)},
		"children": [],
		"material": {"albedo": Color(0.1, 0.3, 0.9), "roughness": 0.6,
					  "metallic": 0.8, "emission": 0.0},
	}

	# Smooth-union them
	op.sdf_tree = {
		"op": "smooth_union",
		"params": {"smoothness": par("smoothness")},
		"children": [twisted, box],
	}
	op.tree_hash = hash(var_to_str(op.sdf_tree))
