class_name OPFindDAT
extends GNDatBase
## Searches the current network for operators matching filter criteria.
## Outputs a table listing matching operators with their metadata.


func _init() -> void:
	node_type = "opfind"
	node_description = "Search the network for operators by family and name."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT, "Found operators table")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("family_filter",
		PackedStringArray(["All", "CHOP", "TOP", "DAT", "SOP", "COMP", "MAT"]), 0,
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

	# Map enum index to GNFamily.Type (-1 for All)
	var target_family: int = -1
	match family_idx:
		1: target_family = GNFamily.Type.CHOP
		2: target_family = GNFamily.Type.TOP
		3: target_family = GNFamily.Type.DAT
		4: target_family = GNFamily.Type.SOP
		5: target_family = GNFamily.Type.COMP
		6: target_family = GNFamily.Type.MAT

	# Walk up the scene tree to find the network node holding a GNNetwork
	var network: GNNetwork = _find_network()
	if network == null:
		push_warning("OPFindDAT: Cannot find parent GNNetwork.")
		return out

	# Iterate all nodes in the network
	for node_id in network.nodes:
		var node: GNNode = network.nodes[node_id] as GNNode
		if node == null:
			continue

		# Family filter
		if target_family >= 0 and node.family != target_family:
			continue

		# Name pattern filter (glob)
		if not pattern.is_empty() and pattern != "*":
			if not _glob_match(node.id, pattern):
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


## Simple glob pattern matching supporting * and ? wildcards.
func _glob_match(text: String, pattern_str: String) -> bool:
	# Convert glob to regex
	var regex_str := "^"
	for ch in pattern_str:
		match ch:
			"*":
				regex_str += ".*"
			"?":
				regex_str += "."
			".":
				regex_str += "\\."
			_:
				regex_str += ch
	regex_str += "$"
	var regex := RegEx.new()
	regex.compile("(?i)" + regex_str)
	return regex.search(text) != null
