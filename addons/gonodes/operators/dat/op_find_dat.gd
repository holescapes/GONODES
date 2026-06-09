class_name OPFindDAT
extends GNDatBase
## Searches the current network for operators matching filter criteria.
## Outputs a table listing matching operators with their metadata.


## Maps dropdown indices to family IDs (index 0 = "All" = -1).
var _filter_family_ids: Array[int] = []


func _init() -> void:
	node_type = "op_find"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT, "Found operators table")


func _init_parameters() -> void:
	# Build family filter dynamically: "All" + every registered family
	var fam_data: Array = GNFamily.get_all_families()
	var fam_ids: Array[int] = fam_data[0]
	var fam_names: PackedStringArray = fam_data[1]
	# Prepend "All"
	_filter_family_ids = [-1]
	var options := PackedStringArray(["All"])
	for i in range(fam_ids.size()):
		_filter_family_ids.append(fam_ids[i])
		options.append(fam_names[i])
	add_parameter(GNParameter.create_enum("family_filter", options, 0,
		"Family Filter", "Filter by operator family (All = no filter)"))
	add_parameter(GNParameter.create_string("name_pattern", "*",
		"Name Pattern", "Glob pattern to match operator names"))
	add_parameter(GNParameter.create_bool("include_type", true,
		"Include Type", "Include the operator type column in output"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var out := _prepare_table()
	out.is_table = true
	out.has_header = true

	var family_idx: int = get_param_value("family_filter")
	var pattern: String = get_param_value("name_pattern")
	var include_type: bool = get_param_value("include_type")

	# Build headers
	var headers := PackedStringArray(["name", "id", "family"])
	if include_type:
		headers.append("type")
	headers.append("num_inputs")
	headers.append("num_outputs")
	out.set_headers(headers)

	# Map dropdown index to family ID via the stored lookup table
	var target_family: int = _filter_family_ids[family_idx] if family_idx >= 0 and family_idx < _filter_family_ids.size() else -1

	# Walk up the scene tree to find the network node holding a GNNetwork
	var network: GNNetwork = _find_network()
	if network == null:
		GNLogger.warn("OPFindDAT", "Cannot find parent GNNetwork.")
		return out

	# Iterate all nodes in the network
	for node_id in network.nodes:
		var node: GNNode = network.nodes[node_id] as GNNode
		if node == null:
			continue

		# Family filter
		if target_family >= 0 and node.family != target_family:
			continue

		# Name pattern filter
		if not pattern.is_empty() and pattern != "*":
			if not GNPattern.matches_any(node.id, pattern):
				continue

		# Build row
		var row := PackedStringArray()
		row.append(node.id)
		row.append(node.id)
		row.append(GNFamily.get_family_name(node.family))
		if include_type:
			row.append(node.node_type)
		row.append(str(node.input_ports.size()))
		row.append(str(node.output_ports.size()))
		out.append_row(row)

	return out


## Attempts to find the GNNetwork resource by walking up the scene tree.
## Looks for a parent node that has a "network" property of type GNNetwork.
func _find_network() -> GNNetwork:
	var current: Node = get_parent()
	while current != null:
		if current.get("network") is GNNetwork:
			return current.get("network") as GNNetwork
		current = current.get_parent()
	return null


# Pattern matching now delegated to GNPattern (see addons/gonodes/core/gn_pattern.gd)
