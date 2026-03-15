class_name ConeSDF
extends GNSdfBase
## SDF cone primitive — distance field of a cone with angle and height.


func _init() -> void:
	super._init()
	node_type = "cone_sdf"
	node_description = "SDF cone with configurable angle and height."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "SDF output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("angle", 30.0, 1.0, 89.0, 0.1,
		"Angle", "Half-angle of the cone in degrees."))
	add_parameter(GNParameter.create_float("height", 2.0, 0.01, 200.0, 0.01,
		"Height", "Height of the cone."))
	add_parameter(GNParameter.create_float("position_x", 0.0, -100.0, 100.0, 0.01,
		"Position X", "Center offset of the cone base."))
	add_parameter(GNParameter.create_float("position_y", 0.0, -100.0, 100.0, 0.01,
		"Position Y", "Center offset of the cone base."))
	add_parameter(GNParameter.create_float("position_z", 0.0, -100.0, 100.0, 0.01,
		"Position Z", "Center offset of the cone base."))


func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_output()
	out.sdf_tree = _make_node("cone", {
		"angle": get_param_value("angle"),
		"height": get_param_value("height"),
		"position": Vector3(get_param_value("position_x"), get_param_value("position_y"), get_param_value("position_z")),
	})
	out.tree_hash = GNSDFData.compute_tree_hash(out.sdf_tree)
	return out
