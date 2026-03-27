class_name TorusSDF
extends GNSdfBase
## SDF torus primitive — distance field of a torus (ring shape).


func _init() -> void:
	super._init()
	node_type = "torus_sdf"
	node_description = "SDF torus with configurable major and minor radii."


func _init_ports() -> void:
	add_output("out", GNSdfBase.SDF_FAMILY, "SDF output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("major_radius", 1.0, 0.01, 100.0, 0.01,
		"Major Radius", "Distance from center of torus to center of tube."))
	add_parameter(GNParameter.create_float("minor_radius", 0.3, 0.01, 50.0, 0.01,
		"Minor Radius", "Radius of the tube cross-section."))
	add_parameter(GNParameter.create_float("position_x", 0.0, -100.0, 100.0, 0.01,
		"Position X", "Center offset of the torus."))
	add_parameter(GNParameter.create_float("position_y", 0.0, -100.0, 100.0, 0.01,
		"Position Y", "Center offset of the torus."))
	add_parameter(GNParameter.create_float("position_z", 0.0, -100.0, 100.0, 0.01,
		"Position Z", "Center offset of the torus."))


func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_output()
	out.sdf_tree = _make_node("torus", {
		"major_radius": get_param_value("major_radius"),
		"minor_radius": get_param_value("minor_radius"),
		"position": Vector3(get_param_value("position_x"), get_param_value("position_y"), get_param_value("position_z")),
	})
	out.tree_hash = GNSDFData.compute_tree_hash(out.sdf_tree)
	return out
