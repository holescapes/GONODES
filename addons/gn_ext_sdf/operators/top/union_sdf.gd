class_name UnionSDF
extends GNSdfBase
## SDF boolean union — combines two shapes (min of distances).


func _init() -> void:
	super._init()
	node_type = "union_sdf"
	node_description = "Boolean union of two SDF shapes (additive combination)."


func _init_ports() -> void:
	add_input("sdf_a", GNFamily.Type.TOP, false, "First SDF shape")
	add_input("sdf_b", GNFamily.Type.TOP, false, "Second SDF shape")
	add_output("out", GNFamily.Type.TOP, "Combined SDF output")


func _init_parameters() -> void:
	pass


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
	out.sdf_tree = _make_node("union", {}, [a.sdf_tree, b.sdf_tree])
	out.tree_hash = GNSDFData.compute_tree_hash(out.sdf_tree)
	return out
