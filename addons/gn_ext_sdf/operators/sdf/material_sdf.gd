class_name MaterialSDF
extends GNSdfBase
## Assigns PBR material properties to an SDF subtree.
## The RaymarchSDF renderer uses these to shade the surface.


func _init() -> void:
	super._init()
	node_type = "material_sdf"
	node_description = "Assign albedo, roughness, and metallic properties to an SDF shape."


func _init_ports() -> void:
	add_input("sdf_in", GNSdfBase.SDF_FAMILY, false, "SDF shape to assign material to", "SDF")
	add_output("out", GNSdfBase.SDF_FAMILY, "SDF with material applied", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_color("albedo", Color(0.8, 0.2, 0.2, 1.0),
		"Albedo", "Surface color."))
	add_parameter(GNParameter.create_float("roughness", 0.5, 0.0, 1.0, 0.01,
		"Roughness", "Surface roughness (0 = mirror, 1 = matte)."))
	add_parameter(GNParameter.create_float("metallic", 0.0, 0.0, 1.0, 0.01,
		"Metallic", "Metallic factor (0 = dielectric, 1 = metal)."))
	add_parameter(GNParameter.create_float("emission", 0.0, 0.0, 10.0, 0.01,
		"Emission", "Emission intensity (0 = no glow)."))


func _cook(inputs: Array[GNData]) -> GNData:
	var sdf_in := _get_input_sdf(inputs, 0)
	if sdf_in == null:
		return null
	var out := _prepare_output()
	var albedo: Color = get_param_value("albedo")
	out.sdf_tree = sdf_in.sdf_tree.duplicate(true)
	out.sdf_tree["material"] = {
		"albedo": [albedo.r, albedo.g, albedo.b],
		"roughness": get_param_value("roughness"),
		"metallic": get_param_value("metallic"),
		"emission": get_param_value("emission"),
	}
	out.tree_hash = GNSDFData.compute_tree_hash(out.sdf_tree)
	return out
