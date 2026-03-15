class_name CylinderSDF
extends GNSdfBase
## SDF cylinder primitive — distance field of a vertical cylinder.


func _init() -> void:
	super._init()
	node_type = "cylinder_sdf"
	node_description = "SDF cylinder with configurable radius and height."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "SDF output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("radius", 0.5, 0.01, 100.0, 0.01,
		"Radius", "Cylinder radius."))
	add_parameter(GNParameter.create_float("height", 2.0, 0.01, 200.0, 0.01,
		"Height", "Total height of the cylinder."))
	add_parameter(GNParameter.create_float("position_x", 0.0, -100.0, 100.0, 0.01,
		"Position X", "Center offset of the cylinder."))
	add_parameter(GNParameter.create_float("position_y", 0.0, -100.0, 100.0, 0.01,
		"Position Y", "Center offset of the cylinder."))
	add_parameter(GNParameter.create_float("position_z", 0.0, -100.0, 100.0, 0.01,
		"Position Z", "Center offset of the cylinder."))


func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_output()
	out.sdf_tree = _make_node("cylinder", {
		"radius": get_param_value("radius"),
		"height": get_param_value("height"),
		"position": Vector3(get_param_value("position_x"), get_param_value("position_y"), get_param_value("position_z")),
	})
	out.tree_hash = GNSDFData.compute_tree_hash(out.sdf_tree)
	return out
