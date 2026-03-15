class_name BoxSDF
extends GNSdfBase
## SDF box primitive — distance field of an axis-aligned box.


func _init() -> void:
	super._init()
	node_type = "box_sdf"
	node_description = "SDF axis-aligned box with configurable half-extents."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "SDF output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("size_x", 1.0, 0.01, 100.0, 0.01,
		"Size X", "Half-extents of the box (x, y, z)."))
	add_parameter(GNParameter.create_float("size_y", 1.0, 0.01, 100.0, 0.01,
		"Size Y", "Half-extents of the box (x, y, z)."))
	add_parameter(GNParameter.create_float("size_z", 1.0, 0.01, 100.0, 0.01,
		"Size Z", "Half-extents of the box (x, y, z)."))
	add_parameter(GNParameter.create_float("position_x", 0.0, -100.0, 100.0, 0.01,
		"Position X", "Center offset of the box."))
	add_parameter(GNParameter.create_float("position_y", 0.0, -100.0, 100.0, 0.01,
		"Position Y", "Center offset of the box."))
	add_parameter(GNParameter.create_float("position_z", 0.0, -100.0, 100.0, 0.01,
		"Position Z", "Center offset of the box."))


func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_output()
	out.sdf_tree = _make_node("box", {
		"size": Vector3(get_param_value("size_x"), get_param_value("size_y"), get_param_value("size_z")),
		"position": Vector3(get_param_value("position_x"), get_param_value("position_y"), get_param_value("position_z")),
	})
	out.tree_hash = GNSDFData.compute_tree_hash(out.sdf_tree)
	return out
