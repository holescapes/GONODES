class_name GyroidSDF
extends GNSdfBase
## SDF gyroid — infinite triply-periodic minimal surface. Great for organic/bio patterns.


func _init() -> void:
	super._init()
	node_type = "gyroid_sdf"
	node_description = "SDF gyroid — triply-periodic minimal surface for organic patterns."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "SDF output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("scale", 1.0, 0.01, 100.0, 0.01,
		"Scale", "Frequency/scale of the gyroid pattern."))
	add_parameter(GNParameter.create_float("thickness", 0.1, 0.001, 10.0, 0.001,
		"Thickness", "Wall thickness of the gyroid surface."))
	add_parameter(GNParameter.create_float("position_x", 0.0, -100.0, 100.0, 0.01,
		"Position X", "Center offset."))
	add_parameter(GNParameter.create_float("position_y", 0.0, -100.0, 100.0, 0.01,
		"Position Y", "Center offset."))
	add_parameter(GNParameter.create_float("position_z", 0.0, -100.0, 100.0, 0.01,
		"Position Z", "Center offset."))


func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_output()
	out.sdf_tree = _make_node("gyroid", {
		"scale": get_param_value("scale"),
		"thickness": get_param_value("thickness"),
		"position": Vector3(get_param_value("position_x"), get_param_value("position_y"), get_param_value("position_z")),
	})
	out.tree_hash = GNSDFData.compute_tree_hash(out.sdf_tree)
	return out
