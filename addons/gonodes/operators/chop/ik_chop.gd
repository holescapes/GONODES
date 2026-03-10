class_name IKCHOP
extends GNChopBase
## FABRIK-based inverse kinematics solver operating on channel data.
##
## Takes a chain of bone lengths and a target position, then outputs
## joint positions (tx/ty/tz per joint) and rotation angles.
## Uses the Forward And Backward Reaching Inverse Kinematics algorithm.
##
## Input CHOP (optional): target position as channels (tx, ty, tz).
## If no input, uses the target_x/y/z parameters.

const MAX_ITERATIONS := 50
const TOLERANCE := 0.001

func _init() -> void:
	node_type = "ik"
	node_description = "FABRIK inverse kinematics chain solver."


func _init_ports() -> void:
	add_input("target", GNFamily.Type.CHOP, false, "Target position (tx, ty, tz channels)")
	add_output("out", GNFamily.Type.CHOP, "Joint positions and angles")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("num_joints", 3, 2, 32, "Joints", "Number of joints in the chain"))
	add_parameter(GNParameter.create_float("bone_length", 1.0, 0.01, 100.0, 0.01,
		"Bone Length", "Length of each bone segment (uniform)"))
	add_parameter(GNParameter.create_float("target_x", 2.0, -100.0, 100.0, 0.01, "Target X", ""))
	add_parameter(GNParameter.create_float("target_y", 1.0, -100.0, 100.0, 0.01, "Target Y", ""))
	add_parameter(GNParameter.create_float("target_z", 0.0, -100.0, 100.0, 0.01, "Target Z", ""))
	add_parameter(GNParameter.create_int("iterations", 10, 1, MAX_ITERATIONS, "Iterations", "FABRIK solver iterations"))
	add_parameter(GNParameter.create_bool("constrain_y", false, "Constrain Y", "Keep chain in XY plane"))


func _cook(inputs: Array[GNData]) -> GNData:
	var num_joints: int = get_param_value("num_joints")
	var bone_len: float = get_param_value("bone_length")
	var iters: int = get_param_value("iterations")
	var constrain: bool = get_param_value("constrain_y")

	# Target position — from input or parameters
	var target := Vector3(
		get_param_value("target_x"),
		get_param_value("target_y"),
		get_param_value("target_z"))

	var input_chop: GNChannelData = _get_input_chop(inputs, 0)
	if input_chop != null:
		if input_chop.channels.has("tx"):
			var s: PackedFloat32Array = input_chop.channels["tx"]
			if s.size() > 0:
				target.x = s[s.size() - 1]
		if input_chop.channels.has("ty"):
			var s: PackedFloat32Array = input_chop.channels["ty"]
			if s.size() > 0:
				target.y = s[s.size() - 1]
		if input_chop.channels.has("tz"):
			var s: PackedFloat32Array = input_chop.channels["tz"]
			if s.size() > 0:
				target.z = s[s.size() - 1]

	# Initialize chain along +X axis at origin
	var joints: Array[Vector3] = []
	for i in range(num_joints):
		joints.append(Vector3(i * bone_len, 0.0, 0.0))

	# Bone lengths array
	var lengths: PackedFloat64Array = PackedFloat64Array()
	for i in range(num_joints - 1):
		lengths.append(bone_len)

	# Total reach
	var total_reach: float = 0.0
	for l: float in lengths:
		total_reach += l
	var dist_to_target: float = joints[0].distance_to(target)

	# If target unreachable, stretch toward it
	if dist_to_target > total_reach:
		var direction: Vector3 = (target - joints[0]).normalized()
		for i in range(1, num_joints):
			joints[i] = joints[i - 1] + direction * lengths[i - 1]
	else:
		# FABRIK solver
		var root_pos: Vector3 = joints[0]
		for _iter in range(iters):
			# Forward pass — move end effector to target
			joints[num_joints - 1] = target
			for i in range(num_joints - 2, -1, -1):
				var dir: Vector3 = (joints[i] - joints[i + 1]).normalized()
				if dir.length_squared() < 1e-10:
					dir = Vector3.UP
				joints[i] = joints[i + 1] + dir * lengths[i]

			# Backward pass — fix root
			joints[0] = root_pos
			for i in range(1, num_joints):
				var dir: Vector3 = (joints[i] - joints[i - 1]).normalized()
				if dir.length_squared() < 1e-10:
					dir = Vector3.RIGHT
				joints[i] = joints[i - 1] + dir * lengths[i - 1]

			# Check convergence
			if joints[num_joints - 1].distance_to(target) < TOLERANCE:
				break

	# Apply Y constraint (flatten to XY plane)
	if constrain:
		for i in range(num_joints):
			joints[i].z = 0.0
		# Re-enforce bone lengths
		for i in range(1, num_joints):
			var dir: Vector3 = (joints[i] - joints[i - 1]).normalized()
			if dir.length_squared() < 1e-10:
				dir = Vector3.RIGHT
			joints[i] = joints[i - 1] + dir * lengths[i - 1]

	# Output channels: jN_tx, jN_ty, jN_tz, jN_rx, jN_ry
	var output: GNChannelData = _prepare_output(60.0)
	for i in range(num_joints):
		var prefix: String = "j%d_" % i
		output.channels[prefix + "tx"] = PackedFloat32Array([joints[i].x])
		output.channels[prefix + "ty"] = PackedFloat32Array([joints[i].y])
		output.channels[prefix + "tz"] = PackedFloat32Array([joints[i].z])

		# Compute rotation angles from bone direction
		if i < num_joints - 1:
			var bone_dir: Vector3 = (joints[i + 1] - joints[i]).normalized()
			var rx: float = atan2(bone_dir.y, bone_dir.z)
			var ry: float = atan2(bone_dir.x, bone_dir.z)
			output.channels[prefix + "rx"] = PackedFloat32Array([rad_to_deg(rx)])
			output.channels[prefix + "ry"] = PackedFloat32Array([rad_to_deg(ry)])

	output.length = 1
	return output
