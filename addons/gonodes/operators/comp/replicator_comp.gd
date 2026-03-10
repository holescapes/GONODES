class_name ReplicatorCOMP
extends GNCompBase
## Simple Replicator — creates N copies of a template operator in the network.
##
## This is TD's "Replicator COMP" simplified for GONODES:
##   • Reads a DAT table input (optional) — each row becomes one replica
##   • Without DAT input: creates N replicas from the "count" parameter
##   • Each replica is a clone of the template node type
##   • Per-replica parameter overrides are driven by DAT table columns
##     matching parameter names
##
## Roadmap: A more advanced version could support sub-network templates
## (replicate entire SubNetworkNode graphs with InTunnel/OutTunnel).

## Track which replica node IDs we have created so we can clean up.
var _replica_ids: PackedStringArray = PackedStringArray()
## Last known configuration hash to avoid unnecessary rebuild.
var _last_config_hash: int = 0


func _init() -> void:
	node_type = "replicator"
	node_description = "Create N copies of a template operator with per-instance parameter overrides."


func _init_ports() -> void:
	add_input("template", GNFamily.Type.COMP, false, "Template COMP to replicate")
	add_input("table", GNFamily.Type.DAT, false, "DAT table for per-replica parameter overrides (optional)")
	add_output("out", GNFamily.Type.COMP, "Replicator output (pass-through)")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("count", 3, 0, 100,
		"Count", "Number of replicas (ignored if DAT table is connected)"))
	add_parameter(GNParameter.create_string("template_type", "GeometryCOMP",
		"Template Type", "Operator type name to replicate (e.g. GeometryCOMP, LightCOMP)"))
	add_parameter(GNParameter.create_string("prefix", "replica",
		"Prefix", "Node ID prefix for replicas (e.g. replica_0, replica_1)"))
	add_parameter(GNParameter.create_bool("active", true,
		"Active", "Enable/disable replication"))


func _cook(inputs: Array[GNData]) -> GNData:
	var active: bool = get_param_value("active")
	if not active:
		return inputs[0] if inputs.size() > 0 and inputs[0] != null else null

	var count: int = get_param_value("count")
	var template_type: String = get_param_value("template_type")
	var prefix: String = get_param_value("prefix")

	# Read DAT table if connected — rows drive replica count + overrides
	var table_in: GNTableData = inputs[1] as GNTableData if inputs.size() > 1 and inputs[1] is GNTableData else null
	var override_rows: Array = []
	if table_in != null and table_in.table.size() > 1:
		# First row is headers, remaining rows are data
		var headers: PackedStringArray = table_in.table[0]
		for row_idx in range(1, table_in.table.size()):
			var row_data: Dictionary = {}
			var row: PackedStringArray = table_in.table[row_idx]
			for col in range(mini(headers.size(), row.size())):
				row_data[headers[col]] = row[col]
			override_rows.append(row_data)
		count = override_rows.size()

	# Hash config to detect changes
	var config_hash: int = hash(str(count) + template_type + prefix)
	for row: Dictionary in override_rows:
		config_hash = hash(str(config_hash) + str(row))

	if config_hash == _last_config_hash:
		# No change — just pass through
		return inputs[0] if inputs.size() > 0 and inputs[0] != null else null

	_last_config_hash = config_hash

	# Get the cook engine's network for node manipulation
	var eng: GNCookEngine = get_parent() as GNCookEngine if get_parent() is GNCookEngine else null
	if eng == null or eng.network == null:
		return null
	var net: GNNetwork = eng.network

	# Remove old replicas
	for rid: String in _replica_ids:
		if net.nodes.has(rid):
			net.remove_node(rid)
	_replica_ids.clear()

	# Create new replicas
	var registry: GNExtensionRegistry = GNExtensionRegistry.instance()
	for i in range(count):
		var replica_id: String = "%s_%d" % [prefix, i]

		var new_node: GNNode = registry.create_operator(template_type)
		if new_node == null:
			GNLogger.warn("ReplicatorCOMP", "'%s' — unknown template type: %s" % [id, template_type])
			continue

		new_node.initialize(replica_id)
		# Position replicas in a column below the replicator
		new_node.graph_position = graph_position + Vector2(0, 120 + i * 80)
		net.add_node(new_node)
		_replica_ids.append(replica_id)

		# Apply per-replica parameter overrides from DAT table
		if i < override_rows.size():
			var overrides: Dictionary = override_rows[i]
			for param_name: String in overrides:
				var val_str: String = overrides[param_name]
				# Try numeric first, fall back to string
				if val_str.is_valid_float():
					new_node.set_param_value(param_name, val_str.to_float())
				elif val_str.is_valid_int():
					new_node.set_param_value(param_name, val_str.to_int())
				else:
					new_node.set_param_value(param_name, val_str)

	GNLogger.info("ReplicatorCOMP", "'%s' — created %d replicas of %s" % [id, _replica_ids.size(), template_type])
	return inputs[0] if inputs.size() > 0 and inputs[0] != null else null


func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_PREDELETE:
		# Clean up replicas on removal
		var eng: GNCookEngine = get_parent() as GNCookEngine if get_parent() is GNCookEngine else null
		if eng != null and eng.network != null:
			for rid: String in _replica_ids:
				if eng.network.nodes.has(rid):
					eng.network.remove_node(rid)
		_replica_ids.clear()
