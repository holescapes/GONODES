class_name RepeatSDF
extends GNSdfBase
## SDF infinite repetition — tiles the input shape along chosen axes.


func _init() -> void:
	super._init()
	node_type = "repeat_sdf"
	node_description = "Infinite tiling of an SDF shape along X, Y, Z axes."


func _init_ports() -> void:
	add_input("sdf_in", GNSdfBase.SDF_FAMILY, false, "SDF shape to repeat", "SDF")
	add_output("out", GNSdfBase.SDF_FAMILY, "Repeated SDF output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("spacing_x", 3.0, 0.0, 100.0, 0.01,
		"Spacing X", "Distance between repetitions on each axis. Set 0 to disable that axis."))
	add_parameter(GNParameter.create_float("spacing_y", 3.0, 0.0, 100.0, 0.01,
		"Spacing Y", "Distance between repetitions on each axis. Set 0 to disable that axis."))
	add_parameter(GNParameter.create_float("spacing_z", 3.0, 0.0, 100.0, 0.01,
		"Spacing Z", "Distance between repetitions on each axis. Set 0 to disable that axis."))
	add_parameter(GNParameter.create_float("limit_x", 0.0, 0.0, 100.0, 1.0,
		"Limit X", "Maximum repetition count per axis (0 = infinite)."))
	add_parameter(GNParameter.create_float("limit_y", 0.0, 0.0, 100.0, 1.0,
		"Limit Y", "Maximum repetition count per axis (0 = infinite)."))
	add_parameter(GNParameter.create_float("limit_z", 0.0, 0.0, 100.0, 1.0,
		"Limit Z", "Maximum repetition count per axis (0 = infinite)."))


func _cook(inputs: Array[GNData]) -> GNData:
	var sdf_in := _get_input_sdf(inputs, 0)
	if sdf_in == null:
		return null
	var out := _prepare_output()
	out.sdf_tree = _make_node("repeat", {
		"spacing": Vector3(get_param_value("spacing_x"), get_param_value("spacing_y"), get_param_value("spacing_z")),
		"limit": Vector3(get_param_value("limit_x"), get_param_value("limit_y"), get_param_value("limit_z")),
	}, [sdf_in.sdf_tree])
	out.tree_hash = GNSDFData.compute_tree_hash(out.sdf_tree)
	return out
