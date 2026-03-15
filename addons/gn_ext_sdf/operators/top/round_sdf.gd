class_name RoundSDF
extends GNSdfBase
## SDF rounding — adds a uniform radius to round all edges.


func _init() -> void:
	super._init()
	node_type = "round_sdf"
	node_description = "Round the edges of an SDF shape by subtracting a uniform radius."


func _init_ports() -> void:
	add_input("sdf_in", GNFamily.Type.TOP, false, "SDF shape to round")
	add_output("out", GNFamily.Type.TOP, "Rounded SDF output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("radius", 0.1, 0.0, 10.0, 0.001,
		"Radius", "Rounding radius — larger values produce softer edges."))


func _cook(inputs: Array[GNData]) -> GNData:
	var sdf_in := _get_input_sdf(inputs, 0)
	if sdf_in == null:
		return null
	var out := _prepare_output()
	out.sdf_tree = _make_node("round", {
		"radius": get_param_value("radius"),
	}, [sdf_in.sdf_tree])
	out.tree_hash = GNSDFData.compute_tree_hash(out.sdf_tree)
	return out
