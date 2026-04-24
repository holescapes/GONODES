class_name ParameterCHOP
extends GNChopBase
## Reads another node's parameter values and outputs them as single-value
## CHOP channels.  Specify the target operator by its node id and optionally
## limit which parameters to read.


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "parameter"
	time_dependent = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Parameter value channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_node_ref("node_path", -1,
		"Node ID", "The id of the operator whose parameters to read"))
	add_parameter(GNParameter.create_string("parameters", "Comma-separated parameter paths to export",
		"Parameters", "Space-separated parameter names to read (empty = all)"))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(_inputs: Array[GNData]) -> GNData:
	var node_id: String = get_param_value("node_path")
	var param_filter: String = get_param_value("parameters")

	var out: GNChannelData = _prepare_output(60.0)

	if node_id.is_empty():
		return out

	# Walk up the tree to find the owning GNNetwork.
	var network_node = get_parent()
	while network_node != null and not (network_node is GNNetwork):
		network_node = network_node.get_parent()

	if network_node == null:
		GNLogger.warn("ParameterCHOP", "'%s' — could not find parent GNNetwork" % id)
		return out

	var target: GNNode = network_node.get_node_by_id(node_id)
	if target == null:
		GNLogger.warn("ParameterCHOP", "'%s' — target node '%s' not found" % [id, node_id])
		return out

	# Determine which parameters to read.
	var param_names: PackedStringArray
	if param_filter.strip_edges().is_empty():
		# Read all parameters from the target node.
		param_names = PackedStringArray(target.parameters.keys())
	else:
		param_names = param_filter.strip_edges().split(" ", false)

	for p_name in param_names:
		if p_name.is_empty():
			continue
		var value = target.get_param_value(p_name)
		if value == null:
			continue
		# Only output numeric types as CHOP channels.
		if value is float or value is int:
			out.set_single_value(p_name, float(value))
		elif value is bool:
			out.set_single_value(p_name, 1.0 if value else 0.0)

	return out
