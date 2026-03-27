class_name OnionSDF
extends GNSdfBase
## SDF onion/shell — hollows the shape, leaving a shell of given thickness.


func _init() -> void:
	super._init()
	node_type = "onion_sdf"
	node_description = "Create a hollow shell from an SDF shape."


func _init_ports() -> void:
	add_input("sdf_in", GNSdfBase.SDF_FAMILY, false, "SDF shape to hollow")
	add_output("out", GNSdfBase.SDF_FAMILY, "Hollowed SDF output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("thickness", 0.1, 0.001, 10.0, 0.001,
		"Thickness", "Shell wall thickness."))
	add_parameter(GNParameter.create_int("layers", 1, 1, 8,
		"Layers", "Number of nested shells (onion layers)."))


func _cook(inputs: Array[GNData]) -> GNData:
	var sdf_in := _get_input_sdf(inputs, 0)
	if sdf_in == null:
		return null
	var out := _prepare_output()
	out.sdf_tree = _make_node("onion", {
		"thickness": get_param_value("thickness"),
		"layers": get_param_value("layers"),
	}, [sdf_in.sdf_tree])
	out.tree_hash = GNSDFData.compute_tree_hash(out.sdf_tree)
	return out
