class_name SelectCHOP
extends GNChopBase
## Wireless reference — returns a named remote CHOP node's output directly.
##
## Set the 'chop' parameter to the node id of the source CHOP.
## Use ChannelFilterCHOP after this node to filter or rename channels.
##
## Rule: only Select nodes do wireless referencing — no wire input.

var _network_cache: GNNetwork = null


func _init() -> void:
	node_type = "select"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Referenced CHOP output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_node_ref("chop", GNFamily.Type.CHOP,
		"CHOP", "Node id of the remote CHOP to reference"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var remote_id: String = get_param_value("chop")
	if remote_id.is_empty():
		node_warning = "No node reference specified"
		return null
	var data: GNChannelData = _resolve_remote_chop(remote_id)
	if data == null:
		node_warning = "Remote CHOP '%s' not found or has no output" % remote_id
		return null
	node_warning = ""
	return data


func _resolve_remote_chop(target_id: String) -> GNChannelData:
	if _network_cache == null or not is_instance_valid(_network_cache):
		var p = get_parent()
		while p != null and not (p is GNNetwork):
			p = p.get_parent()
		_network_cache = p as GNNetwork
	if _network_cache == null:
		return null
	var target: GNNode = _network_cache.get_node_by_id(target_id)
	if target == null:
		return null
	return target.cached_output as GNChannelData if target.cached_output is GNChannelData else null
