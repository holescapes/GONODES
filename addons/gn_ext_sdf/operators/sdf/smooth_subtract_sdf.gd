class_name SmoothSubtractSDF
extends GNSdfBase
## SDF smooth boolean subtraction — carves with a smooth transition.


func _init() -> void:
	super._init()
	node_type = "smooth_subtract_sdf"
	node_description = "Smooth boolean subtraction with blending radius."


func _init_ports() -> void:
	add_input("sdf_a", GNSdfBase.SDF_FAMILY, false, "Base shape (kept)", "SDF A")
	add_input("sdf_b", GNSdfBase.SDF_FAMILY, false, "Cutting shape (removed)", "SDF B")
	add_output("out", GNSdfBase.SDF_FAMILY, "Smooth subtracted SDF output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("smoothness", 0.5, 0.0, 10.0, 0.01,
		"Smoothness", "Blending radius for smooth transition."))


func _cook(inputs: Array[GNData]) -> GNData:
	var a := _get_input_sdf(inputs, 0)
	var b := _get_input_sdf(inputs, 1)
	if a == null:
		return null
	if b == null:
		return a
	var out := _prepare_output()
	out.sdf_tree = _make_node("smooth_subtract", {
		"smoothness": get_param_value("smoothness"),
	}, [a.sdf_tree, b.sdf_tree])
	out.tree_hash = GNSDFData.compute_tree_hash(out.sdf_tree)
	return out
