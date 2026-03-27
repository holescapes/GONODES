class_name PlaneSDF
extends GNSdfBase
## SDF infinite plane — distance field of a flat plane defined by a normal.


func _init() -> void:
	super._init()
	node_type = "plane_sdf"
	node_description = "SDF infinite plane with configurable normal and height offset."


func _init_ports() -> void:
	add_output("out", GNSdfBase.SDF_FAMILY, "SDF output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("normal_x", 0.0, -1.0, 1.0, 0.01,
		"Normal X", "Plane normal direction (auto-normalized in shader)."))
	add_parameter(GNParameter.create_float("normal_y", 1.0, -1.0, 1.0, 0.01,
		"Normal Y", "Plane normal direction (auto-normalized in shader)."))
	add_parameter(GNParameter.create_float("normal_z", 0.0, -1.0, 1.0, 0.01,
		"Normal Z", "Plane normal direction (auto-normalized in shader)."))
	add_parameter(GNParameter.create_float("offset", 0.0, -100.0, 100.0, 0.01,
		"Offset", "Signed distance of the plane from the origin along the normal."))


func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_output()
	out.sdf_tree = _make_node("plane", {
		"normal": Vector3(get_param_value("normal_x"), get_param_value("normal_y"), get_param_value("normal_z")),
		"offset": get_param_value("offset"),
	})
	out.tree_hash = GNSDFData.compute_tree_hash(out.sdf_tree)
	return out
