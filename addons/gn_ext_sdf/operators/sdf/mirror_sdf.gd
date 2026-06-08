class_name MirrorSDF
extends GNSdfBase
## SDF mirror — reflects the shape across chosen axes.


func _init() -> void:
	super._init()
	node_type = "mirror_sdf"
	node_description = "Mirror/reflect an SDF shape across X, Y, and/or Z axes."


func _init_ports() -> void:
	add_input("sdf_in", GNSdfBase.SDF_FAMILY, false, "SDF shape to mirror", "SDF")
	add_output("out", GNSdfBase.SDF_FAMILY, "Mirrored SDF output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("mirror_x", true, "Mirror X", "Mirror across the YZ plane."))
	add_parameter(GNParameter.create_bool("mirror_y", false, "Mirror Y", "Mirror across the XZ plane."))
	add_parameter(GNParameter.create_bool("mirror_z", false, "Mirror Z", "Mirror across the XY plane."))


func _cook(inputs: Array[GNData]) -> GNData:
	var sdf_in := _get_input_sdf(inputs, 0)
	if sdf_in == null:
		return null
	var out := _prepare_output()
	out.sdf_tree = _make_node("mirror", {
		"mirror_x": get_param_value("mirror_x"),
		"mirror_y": get_param_value("mirror_y"),
		"mirror_z": get_param_value("mirror_z"),
	}, [sdf_in.sdf_tree])
	out.tree_hash = GNSDFData.compute_tree_hash(out.sdf_tree)
	return out
