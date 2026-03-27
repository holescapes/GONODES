class_name OctahedronSDF
extends GNSdfBase
## SDF octahedron primitive — distance field of a regular octahedron.


func _init() -> void:
	super._init()
	node_type = "octahedron_sdf"
	node_description = "SDF regular octahedron with configurable size."


func _init_ports() -> void:
	add_output("out", GNSdfBase.SDF_FAMILY, "SDF output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("size", 1.0, 0.01, 100.0, 0.01,
		"Size", "Size of the octahedron (distance from center to vertex)."))
	add_parameter(GNParameter.create_float("position_x", 0.0, -100.0, 100.0, 0.01,
		"Position X", "Center offset of the octahedron."))
	add_parameter(GNParameter.create_float("position_y", 0.0, -100.0, 100.0, 0.01,
		"Position Y", "Center offset of the octahedron."))
	add_parameter(GNParameter.create_float("position_z", 0.0, -100.0, 100.0, 0.01,
		"Position Z", "Center offset of the octahedron."))


func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_output()
	out.sdf_tree = _make_node("octahedron", {
		"size": get_param_value("size"),
		"position": Vector3(get_param_value("position_x"), get_param_value("position_y"), get_param_value("position_z")),
	})
	out.tree_hash = GNSDFData.compute_tree_hash(out.sdf_tree)
	return out
