class_name BendSDF
extends GNSdfBase
## SDF bend — bends the domain along an axis.


func _init() -> void:
	super._init()
	node_type = "bend_sdf"
	node_description = "Bend an SDF shape along an axis."


func _init_ports() -> void:
	add_input("sdf_in", GNSdfBase.SDF_FAMILY, false, "SDF shape to bend")
	add_output("out", GNSdfBase.SDF_FAMILY, "Bent SDF output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("amount", 0.5, -20.0, 20.0, 0.01,
		"Amount", "Bend strength (radians per unit)."))
	add_parameter(GNParameter.create_enum("axis",
		PackedStringArray(["Y", "X", "Z"]), 0,
		"Axis", "Axis along which to apply the bend."))


func _cook(inputs: Array[GNData]) -> GNData:
	var sdf_in := _get_input_sdf(inputs, 0)
	if sdf_in == null:
		return null
	var out := _prepare_output()
	out.sdf_tree = _make_node("bend", {
		"amount": get_param_value("amount"),
		"axis": get_param_value("axis"),
	}, [sdf_in.sdf_tree])
	out.tree_hash = GNSDFData.compute_tree_hash(out.sdf_tree)
	return out
