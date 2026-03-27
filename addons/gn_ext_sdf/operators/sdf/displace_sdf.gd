class_name DisplaceSDF
extends GNSdfBase
## SDF displacement — warps the surface using sine-based noise.


func _init() -> void:
	super._init()
	node_type = "displace_sdf"
	node_description = "Displace an SDF surface with sine-based noise warping."


func _init_ports() -> void:
	add_input("sdf_in", GNSdfBase.SDF_FAMILY, false, "SDF shape to displace")
	add_output("out", GNSdfBase.SDF_FAMILY, "Displaced SDF output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("amount", 0.2, 0.0, 10.0, 0.001,
		"Amount", "Displacement strength."))
	add_parameter(GNParameter.create_float("frequency", 5.0, 0.01, 100.0, 0.01,
		"Frequency", "Noise frequency — higher values create finer detail."))
	add_parameter(GNParameter.create_float("time_offset", 0.0, -1000.0, 1000.0, 0.01,
		"Time Offset", "Animate displacement over time (add elapsed_time for auto-animation)."))


func _cook(inputs: Array[GNData]) -> GNData:
	var sdf_in := _get_input_sdf(inputs, 0)
	if sdf_in == null:
		return null
	var out := _prepare_output()
	out.sdf_tree = _make_node("displace", {
		"amount": get_param_value("amount"),
		"frequency": get_param_value("frequency"),
		"time_offset": get_param_value("time_offset"),
	}, [sdf_in.sdf_tree])
	out.tree_hash = GNSDFData.compute_tree_hash(out.sdf_tree)
	return out
