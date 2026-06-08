class_name SmoothUnionSDF
extends GNSdfBase
## SDF smooth boolean union — blends two shapes with a smooth transition.


func _init() -> void:
	super._init()
	node_type = "smooth_union_sdf"
	node_description = "Smooth boolean union of two SDF shapes with blending radius."


func _init_ports() -> void:
	add_input("sdf_a", GNSdfBase.SDF_FAMILY, false, "First SDF shape", "SDF A")
	add_input("sdf_b", GNSdfBase.SDF_FAMILY, false, "Second SDF shape", "SDF B")
	add_output("out", GNSdfBase.SDF_FAMILY, "Smoothly combined SDF output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("smoothness", 0.5, 0.0, 10.0, 0.01,
		"Smoothness", "Blending radius — higher values produce rounder transitions."))


func _cook(inputs: Array[GNData]) -> GNData:
	var a := _get_input_sdf(inputs, 0)
	var b := _get_input_sdf(inputs, 1)
	if a == null and b == null:
		return null
	if a == null:
		return b
	if b == null:
		return a
	var out := _prepare_output()
	out.sdf_tree = _make_node("smooth_union", {
		"smoothness": get_param_value("smoothness"),
	}, [a.sdf_tree, b.sdf_tree])
	out.tree_hash = GNSDFData.compute_tree_hash(out.sdf_tree)
	return out
