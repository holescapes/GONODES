class_name SelectDAT
extends GNDatBase
## Wireless reference — returns a named remote DAT node's output directly.
##
## Set the 'dat' parameter to the node id of the source DAT.
## Use SubsetDAT after this node to filter rows/columns.
##
## Rule: only Select nodes do wireless referencing — no wire input.

var _network_cache: GNNetwork = null


func _init() -> void:
	node_type = "select"
	# Wireless refresh is engine-driven (demand map + consumer dirty/hash).


func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT, "Referenced DAT output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_node_ref("dat", GNFamily.Type.DAT,
		"DAT", "Node id of the remote DAT to reference"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var remote_id: String = get_param_value("dat")
	if remote_id.is_empty():
		node_warning = "No node reference specified"
		return null
	var data: GNTableData = _resolve_remote_dat(remote_id)
	if data == null or not data.is_table:
		node_warning = "Remote DAT '%s' not found or has no table output" % remote_id
		return null
	node_warning = ""
	return data


func _resolve_remote_dat(target_id: String) -> GNTableData:
	if _network_cache == null or not is_instance_valid(_network_cache):
		_network_cache = get_owning_network()
	if _network_cache == null:
		return null
	var target: GNNode = _network_cache.get_node_by_id(target_id)
	if target == null:
		return null
	var _ret0 := target.cached_output as GNTableData if target.cached_output is GNTableData else null
	return _ret0
