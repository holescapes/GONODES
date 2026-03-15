class_name PyramidSDF
extends GNSdfBase
## SDF pyramid primitive — distance field of a 4-sided pyramid.


func _init() -> void:
	super._init()
	node_type = "pyramid_sdf"
	node_description = "SDF four-sided pyramid with configurable base size and height."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "SDF output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("base", 1.0, 0.01, 100.0, 0.01,
		"Base", "Half-width of the pyramid base."))
	add_parameter(GNParameter.create_float("height", 1.5, 0.01, 200.0, 0.01,
		"Height", "Height of the pyramid apex from base."))
	add_parameter(GNParameter.create_float("position_x", 0.0, -100.0, 100.0, 0.01,
		"Position X", "Center offset of the pyramid."))
	add_parameter(GNParameter.create_float("position_y", 0.0, -100.0, 100.0, 0.01,
		"Position Y", "Center offset of the pyramid."))
	add_parameter(GNParameter.create_float("position_z", 0.0, -100.0, 100.0, 0.01,
		"Position Z", "Center offset of the pyramid."))


func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_output()
	out.sdf_tree = _make_node("pyramid", {
		"base": get_param_value("base"),
		"height": get_param_value("height"),
		"position": Vector3(get_param_value("position_x"), get_param_value("position_y"), get_param_value("position_z")),
	})
	out.tree_hash = GNSDFData.compute_tree_hash(out.sdf_tree)
	return out
