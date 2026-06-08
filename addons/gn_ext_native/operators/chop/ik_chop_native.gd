class_name IkCHOPNative
extends GNChopBase
## Native-accelerated FABRIK IK solver — delegates to GNNativeIkChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "ik_native"
	node_description = "FABRIK inverse kinematics solver — native C++ accelerated."
	if ClassDB.class_exists("GNNativeIkChop"):
		_processor = ClassDB.instantiate("GNNativeIkChop")


func _init_ports() -> void:
	add_input("target", GNFamily.Type.CHOP, false, "Target position (optional)", "Target")
	add_output("out", GNFamily.Type.CHOP, "Joint transforms", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("num_joints", 3, 2, 32,
		"Joints", "Number of joints in the chain"))
	add_parameter(GNParameter.create_float("bone_length", 1.0, 0.01, 100.0, 0.01,
		"Bone Length", "Length of each bone segment"))
	add_parameter(GNParameter.create_float("target_x", 2.0, -100.0, 100.0, 0.01,
		"Target X", "Target X position"))
	add_parameter(GNParameter.create_float("target_y", 1.0, -100.0, 100.0, 0.01,
		"Target Y", "Target Y position"))
	add_parameter(GNParameter.create_float("target_z", 0.0, -100.0, 100.0, 0.01,
		"Target Z", "Target Z position"))
	add_parameter(GNParameter.create_int("iterations", 10, 1, 50,
		"Iterations", "FABRIK solver iterations"))
	add_parameter(GNParameter.create_bool("constrain_y", false, "Constrain Y",
		"Clamp Y rotation to zero"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tx: float = get_param_value("target_x")
	var ty: float = get_param_value("target_y")
	var tz: float = get_param_value("target_z")

	# Override target from input CHOP if connected
	if inputs.size() > 0 and inputs[0] is GNChannelData:
		var in_chop: GNChannelData = inputs[0] as GNChannelData
		if in_chop.has_channel("tx"):
			tx = in_chop.get_single_value("tx")
		if in_chop.has_channel("ty"):
			ty = in_chop.get_single_value("ty")
		if in_chop.has_channel("tz"):
			tz = in_chop.get_single_value("tz")

	if not _processor:
		return null

	var result: Dictionary = _processor.process(
		get_param_value("num_joints"), get_param_value("bone_length"),
		tx, ty, tz, get_param_value("iterations"),
		get_param_value("constrain_y"))

	var out: GNChannelData = _prepare_output(60.0)
	for ch_name in result:
		if result[ch_name] is PackedFloat32Array:
			out.channels[ch_name] = result[ch_name]
	out.length = get_param_value("num_joints") + 1
	return out
