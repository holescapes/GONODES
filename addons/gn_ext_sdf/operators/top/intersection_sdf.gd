class_name IntersectionSDF
extends GNSdfBase
## SDF boolean intersection — keeps only the overlapping region (max of distances).


func _init() -> void:
	super._init()
	node_type = "intersection_sdf"
	node_description = "Boolean intersection of two SDF shapes (keeps overlap only)."


func _init_ports() -> void:
	add_input("sdf_a", GNFamily.Type.TOP, false, "First SDF shape")
	add_input("sdf_b", GNFamily.Type.TOP, false, "Second SDF shape")
	add_output("out", GNFamily.Type.TOP, "Intersected SDF output")


func _init_parameters() -> void:
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	var a := _get_input_sdf(inputs, 0)
	var b := _get_input_sdf(inputs, 1)
	if a == null or b == null:
		return null
	var out := _prepare_output()
	out.sdf_tree = _make_node("intersection", {}, [a.sdf_tree, b.sdf_tree])
	out.tree_hash = GNSDFData.compute_tree_hash(out.sdf_tree)
	return out
