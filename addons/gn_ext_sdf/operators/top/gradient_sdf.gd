class_name GradientSDF
extends GNSdfBase
## Distance-based gradient coloring on an SDF shape.
## Colors the surface based on the SDF distance value using a two-color gradient.


func _init() -> void:
	super._init()
	node_type = "gradient_sdf"
	node_description = "Apply distance-based gradient coloring to an SDF shape."


func _init_ports() -> void:
	add_input("sdf_in", GNFamily.Type.TOP, false, "SDF shape to color")
	add_output("out", GNFamily.Type.TOP, "SDF with gradient coloring")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_color("color_near", Color(1.0, 0.3, 0.1, 1.0),
		"Color Near", "Color at zero distance (surface)."))
	add_parameter(GNParameter.create_color("color_far", Color(0.1, 0.3, 1.0, 1.0),
		"Color Far", "Color at maximum distance."))
	add_parameter(GNParameter.create_float("range", 2.0, 0.01, 100.0, 0.01,
		"Range", "Distance over which the gradient transitions."))
	add_parameter(GNParameter.create_float("roughness", 0.5, 0.0, 1.0, 0.01,
		"Roughness", "Surface roughness."))


func _cook(inputs: Array[GNData]) -> GNData:
	var sdf_in := _get_input_sdf(inputs, 0)
	if sdf_in == null:
		return null
	var out := _prepare_output()
	var c_near: Color = get_param_value("color_near")
	var c_far: Color = get_param_value("color_far")
	out.sdf_tree = sdf_in.sdf_tree.duplicate(true)
	out.sdf_tree["material"] = {
		"type": "gradient",
		"color_near": [c_near.r, c_near.g, c_near.b],
		"color_far": [c_far.r, c_far.g, c_far.b],
		"range": get_param_value("range"),
		"roughness": get_param_value("roughness"),
	}
	out.tree_hash = GNSDFData.compute_tree_hash(out.sdf_tree)
	return out
