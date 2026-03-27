class_name CapsuleSDF
extends GNSdfBase
## SDF capsule primitive — distance field of a line segment with radius.


func _init() -> void:
	super._init()
	node_type = "capsule_sdf"
	node_description = "SDF capsule (line segment with rounded ends)."


func _init_ports() -> void:
	add_output("out", GNSdfBase.SDF_FAMILY, "SDF output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("radius", 0.3, 0.01, 100.0, 0.01,
		"Radius", "Capsule radius (thickness)."))
	add_parameter(GNParameter.create_float("height", 2.0, 0.01, 200.0, 0.01,
		"Height", "Total height of the capsule (tip to tip)."))
	add_parameter(GNParameter.create_float("position_x", 0.0, -100.0, 100.0, 0.01,
		"Position X", "Center offset of the capsule."))
	add_parameter(GNParameter.create_float("position_y", 0.0, -100.0, 100.0, 0.01,
		"Position Y", "Center offset of the capsule."))
	add_parameter(GNParameter.create_float("position_z", 0.0, -100.0, 100.0, 0.01,
		"Position Z", "Center offset of the capsule."))


func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_output()
	out.sdf_tree = _make_node("capsule", {
		"radius": get_param_value("radius"),
		"height": get_param_value("height"),
		"position": Vector3(get_param_value("position_x"), get_param_value("position_y"), get_param_value("position_z")),
	})
	out.tree_hash = GNSDFData.compute_tree_hash(out.sdf_tree)
	return out
