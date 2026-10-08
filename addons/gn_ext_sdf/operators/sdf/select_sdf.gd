class_name SelectSDF
extends GNSdfBase
## Wireless reference — outputs a named remote SDF node's tree.
##
## The 'sdf' parameter holds the node id of the source SDF.
## Rule: only Select nodes do wireless referencing — no wire input.

var _network_cache: GNNetwork = null


func _init() -> void:
	super._init()
	node_type = "select"


func _init_ports() -> void:
	add_output("out", SDF_FAMILY, "Selected SDF tree", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_node_ref("sdf", SDF_FAMILY,
		"SDF", "Node id of the remote SDF to reference"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var remote_id: String = get_param_value("sdf")
	if remote_id.is_empty():
		node_warning = "No node reference specified"
		return null
	var data: GNData = _resolve_remote(remote_id)
	if data is GNSDFData:
		node_warning = ""
		return data
	node_warning = "Remote SDF '%s' not found or has no output" % remote_id
	return null


func _resolve_remote(target_id: String) -> GNData:
	if _network_cache == null or not is_instance_valid(_network_cache):
		_network_cache = get_owning_network()
	if _network_cache == null:
		return null
	var target: GNNode = _network_cache.get_node_by_id(target_id)
	if target == null or target.family != SDF_FAMILY:
		return null
	return target.cached_output
