class_name SubtractSDF
extends GNSdfBase
## SDF boolean subtraction — carves shape B out of shape A.


func _init() -> void:
	super._init()
	node_type = "subtract_sdf"
	node_description = "Boolean subtraction — carves second SDF from first."


func _init_ports() -> void:
	add_input("sdf_a", GNFamily.Type.TOP, false, "Base shape (kept)")
	add_input("sdf_b", GNFamily.Type.TOP, false, "Cutting shape (removed)")
	add_output("out", GNFamily.Type.TOP, "Subtracted SDF output")


func _init_parameters() -> void:
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	var a := _get_input_sdf(inputs, 0)
	var b := _get_input_sdf(inputs, 1)
	if a == null:
		return null
	if b == null:
		return a
	var out := _prepare_output()
	out.sdf_tree = _make_node("subtract", {}, [a.sdf_tree, b.sdf_tree])
	out.tree_hash = GNSDFData.compute_tree_hash(out.sdf_tree)
	return out
