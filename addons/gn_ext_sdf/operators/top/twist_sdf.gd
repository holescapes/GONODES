class_name TwistSDF
extends GNSdfBase
## SDF twist — rotates the domain around an axis proportional to position.


func _init() -> void:
	super._init()
	node_type = "twist_sdf"
	node_description = "Twist an SDF shape around an axis based on position."


func _init_ports() -> void:
	add_input("sdf_in", GNFamily.Type.TOP, false, "SDF shape to twist")
	add_output("out", GNFamily.Type.TOP, "Twisted SDF output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("amount", 1.0, -20.0, 20.0, 0.01,
		"Amount", "Twist strength (radians per unit along the axis)."))
	add_parameter(GNParameter.create_enum("axis",
		PackedStringArray(["Y", "X", "Z"]), 0,
		"Axis", "Axis to twist around."))


func _cook(inputs: Array[GNData]) -> GNData:
	var sdf_in := _get_input_sdf(inputs, 0)
	if sdf_in == null:
		return null
	var out := _prepare_output()
	out.sdf_tree = _make_node("twist", {
		"amount": get_param_value("amount"),
		"axis": get_param_value("axis"),
	}, [sdf_in.sdf_tree])
	out.tree_hash = GNSDFData.compute_tree_hash(out.sdf_tree)
	return out
