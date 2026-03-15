class_name SphereSDF
extends GNSdfBase
## SDF sphere primitive — distance field of a sphere at the origin.


func _init() -> void:
	super._init()
	node_type = "sphere_sdf"
	node_description = "SDF sphere primitive with configurable radius and position offset."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "SDF output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("radius", 1.0, 0.01, 100.0, 0.01,
		"Radius", "Sphere radius."))
	add_parameter(GNParameter.create_float("position_x", 0.0, -100.0, 100.0, 0.01,
		"Position X", "Center offset of the sphere."))
	add_parameter(GNParameter.create_float("position_y", 0.0, -100.0, 100.0, 0.01,
		"Position Y", "Center offset of the sphere."))
	add_parameter(GNParameter.create_float("position_z", 0.0, -100.0, 100.0, 0.01,
		"Position Z", "Center offset of the sphere."))


func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_output()
	out.sdf_tree = _make_node("sphere", {
		"radius": get_param_value("radius"),
		"position": Vector3(get_param_value("position_x"), get_param_value("position_y"), get_param_value("position_z")),
	})
	out.tree_hash = GNSDFData.compute_tree_hash(out.sdf_tree)
	return out
