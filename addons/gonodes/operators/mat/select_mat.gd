class_name SelectMAT
extends GNMatBase
## Wireless reference — outputs a named remote MAT node's material.
##
## The 'mat' parameter holds the node id of the source MAT.
## Rule: only Select nodes do wireless referencing — no wire input.

var _network_cache: GNNetwork = null


func _init() -> void:
	node_type = "select"
	# Wireless refresh is engine-driven (demand map + consumer dirty/hash).


func _init_ports() -> void:
	add_output("out", GNFamily.Type.MAT, "Selected material", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_node_ref("mat", GNFamily.Type.MAT,
		"MAT", "Node id of the remote MAT to reference"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var remote_id: String = get_param_value("mat")
	if remote_id.is_empty():
		node_warning = "No node reference specified"
		return null
	var data: GNData = _resolve_remote(remote_id, GNFamily.Type.MAT)
	if data is GNMaterialData:
		node_warning = ""
		return data
	node_warning = "Remote MAT '%s' not found or has no output" % remote_id
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
