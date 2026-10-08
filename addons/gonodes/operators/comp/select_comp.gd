class_name SelectCOMP
extends GNCompBase
## References a remote COMP node by name — outputs that node's data
## without requiring a wire connection.
##
## Wireless reference — no input port.  Names a remote COMP by its node id
## and outputs that node's data.

var _network_cache: GNNetwork = null


func _init() -> void:
	node_type = "select"
	# Wireless refresh is engine-driven (demand map + consumer dirty/hash).


func _init_ports() -> void:
	add_output("out", GNFamily.Type.COMP, "Selected component")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_node_ref("comp", GNFamily.Type.COMP,
		"COMP", "Name (id) of a remote COMP to reference (empty = use wired input)"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var remote_id: String = get_param_value("comp")

	if remote_id.is_empty():
		node_warning = "No COMP referenced — set the 'comp' parameter"
		return null

	var data: GNData = _resolve_remote(remote_id, GNFamily.Type.COMP)
	if data != null:
		node_warning = ""
		return data
	node_warning = "Remote COMP '%s' not found or has no output" % remote_id
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
