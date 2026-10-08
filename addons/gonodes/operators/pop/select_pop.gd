class_name SelectPOP
extends GNPopBase
## Wireless reference — outputs a named remote POP node's particle data.
##
## The 'pop' parameter holds the node id of the source POP.
## Rule: only Select nodes do wireless referencing — no wire input.

var _network_cache: GNNetwork = null


func _init() -> void:
	super._init()
	node_type = "select"
	# Wireless refresh is engine-driven (demand map + consumer dirty/hash).


func _init_ports() -> void:
	add_output("out", GNFamily.Type.POP, "Selected particles", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_node_ref("pop", GNFamily.Type.POP,
		"POP", "Node id of the remote POP to reference"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var remote_id: String = get_param_value("pop")
	if remote_id.is_empty():
		node_warning = "No node reference specified"
		return null
	var data: GNData = _resolve_remote(remote_id, GNFamily.Type.POP)
	if data is GNParticleData:
		node_warning = ""
		return data
	node_warning = "Remote POP '%s' not found or has no output" % remote_id
	return null


func _resolve_remote(target_id: String, expected_family: int) -> GNData:
	if _network_cache == null or not is_instance_valid(_network_cache):
		_network_cache = get_owning_network()
	if _network_cache == null:
		return null
	var target: GNNode = _network_cache.get_node_by_id(target_id)
	if target == null or target.family != expected_family:
		return null
	return target.cached_output
