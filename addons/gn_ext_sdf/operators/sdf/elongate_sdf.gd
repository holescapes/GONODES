class_name ElongateSDF
extends GNSdfBase
## SDF elongation — stretches the shape by extruding a flat region.


func _init() -> void:
	super._init()
	node_type = "elongate_sdf"
	node_description = "Elongate an SDF shape by inserting a flat region along axes."


func _init_ports() -> void:
	add_input("sdf_in", GNSdfBase.SDF_FAMILY, false, "SDF shape to elongate")
	add_output("out", GNSdfBase.SDF_FAMILY, "Elongated SDF output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("amount_x", 0.0, 0.0, 50.0, 0.01,
		"Amount X", "Elongation distance per axis."))
	add_parameter(GNParameter.create_float("amount_y", 0.5, 0.0, 50.0, 0.01,
		"Amount Y", "Elongation distance per axis."))
	add_parameter(GNParameter.create_float("amount_z", 0.0, 0.0, 50.0, 0.01,
		"Amount Z", "Elongation distance per axis."))


func _cook(inputs: Array[GNData]) -> GNData:
	var sdf_in := _get_input_sdf(inputs, 0)
	if sdf_in == null:
		return null
	var out := _prepare_output()
	out.sdf_tree = _make_node("elongate", {
		"amount": Vector3(get_param_value("amount_x"), get_param_value("amount_y"), get_param_value("amount_z")),
	}, [sdf_in.sdf_tree])
	out.tree_hash = GNSDFData.compute_tree_hash(out.sdf_tree)
	return out
